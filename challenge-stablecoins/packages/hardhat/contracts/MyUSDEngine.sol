// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MyUSD.sol";
import "./Oracle.sol";
import "./MyUSDStaking.sol";

error Engine__InvalidAmount();
error Engine__UnsafePositionRatio();
error Engine__NotLiquidatable();
error Engine__InvalidBorrowRate();
error Engine__NotRateController();
error Engine__InsufficientCollateral();
error Engine__TransferFailed();

contract MyUSDEngine is Ownable {
    uint256 private constant COLLATERAL_RATIO = 150; // 150% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators
    uint256 private constant SECONDS_PER_YEAR = 365 days;
    uint256 private constant PRECISION = 1e18;

    MyUSD private i_myUSD;
    Oracle private i_oracle;
    MyUSDStaking private i_staking;
    address private i_rateController;

    uint256 public borrowRate; // Annual interest rate for borrowers in basis points (1% = 100)

    // Total debt shares in the pool
    uint256 public totalDebtShares;

    // Exchange rate between debt shares and MyUSD (1e18 precision)
    uint256 public debtExchangeRate;
    uint256 public lastUpdateTime;

    mapping(address => uint256) public s_userCollateral;
    mapping(address => uint256) public s_userDebtShares;

    event CollateralAdded(address indexed user, uint256 indexed amount, uint256 price);
    event CollateralWithdrawn(address indexed withdrawer, uint256 indexed amount, uint256 price);
    event BorrowRateUpdated(uint256 newRate);
    event DebtSharesMinted(address indexed user, uint256 amount, uint256 shares);
    event DebtSharesBurned(address indexed user, uint256 amount, uint256 shares);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    modifier onlyRateController() {
        if (msg.sender != i_rateController) revert Engine__NotRateController();
        _;
    }

    constructor(
        address _oracle,
        address _myUSDAddress,
        address _stakingAddress,
        address _rateController
    ) Ownable(msg.sender) {
        i_oracle = Oracle(_oracle);
        i_myUSD = MyUSD(_myUSDAddress);
        i_staking = MyUSDStaking(_stakingAddress);
        i_rateController = _rateController;
        lastUpdateTime = block.timestamp;
        debtExchangeRate = PRECISION; // 1:1 initially
    }

    // Checkpoint 2: Depositing Collateral & Understanding Value
    function addCollateral() public payable {
        if (msg.value == 0) revert Engine__InvalidAmount();

        s_userCollateral[msg.sender] += msg.value;

        emit CollateralAdded(msg.sender, msg.value, i_oracle.getETHUSDPrice());
    }

    function calculateCollateralValue(address user) public view returns (uint256) {
        uint256 ethPrice = i_oracle.getETHUSDPrice(); // USD per ETH (1e18)
        return (s_userCollateral[user] * ethPrice) / PRECISION;
    }

    // Checkpoint 3: Interest Calculation System
    function _getCurrentExchangeRate() internal view returns (uint256) {
        if (totalDebtShares == 0) return debtExchangeRate;

        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        if (timeElapsed == 0) return debtExchangeRate;

        uint256 interest = (borrowRate * timeElapsed * debtExchangeRate)
            / (SECONDS_PER_YEAR * 10000);

        return debtExchangeRate + interest;
    }

    function _accrueInterest() internal {
        debtExchangeRate = _getCurrentExchangeRate();
        lastUpdateTime = block.timestamp;
    }

    function _getMyUSDToShares(uint256 amount) internal view returns (uint256) {
        return (amount * PRECISION) / _getCurrentExchangeRate();
    }


    // Checkpoint 4: Minting MyUSD & Position Health
    function getCurrentDebtValue(address user) public view returns (uint256) {
    if (s_userDebtShares[user] == 0) return 0;
    return (s_userDebtShares[user] * _getCurrentExchangeRate()) / PRECISION;
    }

    function calculatePositionRatio(address user) public view returns (uint256) {
        uint256 debt = getCurrentDebtValue(user);
        if (debt == 0) return type(uint256).max;

        uint256 collateralValue = calculateCollateralValue(user);
        return (collateralValue * 100) / debt;
    }

    function _validatePosition(address user) internal view {
        if (calculatePositionRatio(user) < COLLATERAL_RATIO) {
            revert Engine__UnsafePositionRatio();
        }
    }
    function mintMyUSD(uint256 mintAmount) public {
    if (mintAmount == 0) revert Engine__InvalidAmount();

    _accrueInterest();

    uint256 shares = _getMyUSDToShares(mintAmount);

    s_userDebtShares[msg.sender] += shares;
    totalDebtShares += shares;

    _validatePosition(msg.sender);

    bool success = i_myUSD.mintTo(msg.sender, mintAmount);
    if (!success) revert Engine__TransferFailed();

    emit DebtSharesMinted(msg.sender, mintAmount, shares);
}
    // Checkpoint 5: Accruing Interest & Managing Borrow Rates
    function setBorrowRate(uint256 newRate) external onlyRateController {
    _accrueInterest();
    borrowRate = newRate;
    emit BorrowRateUpdated(newRate);
}


    // Checkpoint 6: Repaying Debt & Withdrawing Collateral
    function repayUpTo(uint256 amount) public {
    if (amount == 0) revert Engine__InvalidAmount();

    _accrueInterest();

    uint256 debt = getCurrentDebtValue(msg.sender);
    uint256 repayAmount = amount > debt ? debt : amount;

    uint256 sharesToBurn = _getMyUSDToShares(repayAmount);

    s_userDebtShares[msg.sender] -= sharesToBurn;
    totalDebtShares -= sharesToBurn;

    i_myUSD.burnFrom(msg.sender, repayAmount);

    emit DebtSharesBurned(msg.sender, repayAmount, sharesToBurn);
}

function withdrawCollateral(uint256 amount) external {
    if (amount == 0) revert Engine__InvalidAmount();
    if (s_userCollateral[msg.sender] < amount) revert Engine__InsufficientCollateral();

    _accrueInterest();

    s_userCollateral[msg.sender] -= amount;
    _validatePosition(msg.sender);

    (bool sent,) = payable(msg.sender).call{value: amount}("");
    if (!sent) revert Engine__TransferFailed();

    emit CollateralWithdrawn(msg.sender, amount, i_oracle.getETHUSDPrice());
}

    // Checkpoint 7: Liquidation - Enforcing System Stability
    function isLiquidatable(address user) public view returns (bool) {
    return calculatePositionRatio(user) < COLLATERAL_RATIO;
}

function liquidate(address user) external {
    if (!isLiquidatable(user)) revert Engine__NotLiquidatable();

    _accrueInterest();

    uint256 debt = getCurrentDebtValue(user);
    uint256 reward = (s_userCollateral[user] * LIQUIDATOR_REWARD) / 100;

    s_userCollateral[user] = 0;
    s_userDebtShares[user] = 0;
    totalDebtShares -= _getMyUSDToShares(debt);

    i_myUSD.burnFrom(msg.sender, debt);

    (bool sent,) = payable(msg.sender).call{value: reward}("");
    if (!sent) revert Engine__TransferFailed();

    emit Liquidation(user, msg.sender, reward, debt, i_oracle.getETHUSDPrice());
}
}
