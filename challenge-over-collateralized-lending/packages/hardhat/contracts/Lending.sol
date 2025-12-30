// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Corn.sol";
import "./CornDEX.sol";

error Lending__InvalidAmount();
error Lending__TransferFailed();
error Lending__UnsafePositionRatio();
error Lending__BorrowingFailed();
error Lending__RepayingFailed();
error Lending__PositionSafe();
error Lending__NotLiquidatable();
error Lending__InsufficientLiquidatorCorn();

contract Lending is Ownable {
    uint256 private constant COLLATERAL_RATIO = 120; // 120%
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10%

    Corn private i_corn;
    CornDEX private i_cornDEX;

    mapping(address => uint256) public s_userCollateral; // ETH
    mapping(address => uint256) public s_userBorrowed;   // CORN

    event CollateralAdded(address indexed user, uint256 amount, uint256 price);
    event CollateralWithdrawn(address indexed user, uint256 amount, uint256 price);
    event AssetBorrowed(address indexed user, uint256 amount, uint256 price);
    event AssetRepaid(address indexed user, uint256 amount, uint256 price);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    constructor(address _cornDEX, address _corn) Ownable(msg.sender) {
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        i_corn.approve(address(this), type(uint256).max);
    }

    /* ===================== COLLATERAL ===================== */

    function addCollateral() public payable {
        if (msg.value == 0) revert Lending__InvalidAmount();
        s_userCollateral[msg.sender] += msg.value;
        emit CollateralAdded(msg.sender, msg.value, i_cornDEX.currentPrice());
    }

    function withdrawCollateral(uint256 amount) public {
        if (amount == 0 || amount > s_userCollateral[msg.sender]) {
            revert Lending__InvalidAmount();
        }

        s_userCollateral[msg.sender] -= amount;

        // if user has debt, must remain safe
        if (s_userBorrowed[msg.sender] > 0) {
            _validatePosition(msg.sender);
        }

        (bool sent, ) = payable(msg.sender).call{ value: amount }("");
        if (!sent) revert Lending__TransferFailed();

        emit CollateralWithdrawn(msg.sender, amount, i_cornDEX.currentPrice());
    }

    /* ===================== VIEW HELPERS ===================== */

    function calculateCollateralValue(address user) public view returns (uint256) {
        // ETH * price = CORN value
        return (s_userCollateral[user] * i_cornDEX.currentPrice()) / 1 ether;
    }

    function _calculatePositionRatio(address user) internal view returns (uint256) {
        if (s_userBorrowed[user] == 0) return type(uint256).max;

        return (calculateCollateralValue(user) * 100) / s_userBorrowed[user];
    }

    function isLiquidatable(address user) public view returns (bool) {
        if (s_userBorrowed[user] == 0) return false;
        return _calculatePositionRatio(user) < COLLATERAL_RATIO;
    }

    function _validatePosition(address user) internal view {
        if (_calculatePositionRatio(user) < COLLATERAL_RATIO) {
            revert Lending__UnsafePositionRatio();
        }
    }

    /* ===================== BORROW / REPAY ===================== */

    function borrowCorn(uint256 borrowAmount) public {
        if (borrowAmount == 0) revert Lending__InvalidAmount();

        s_userBorrowed[msg.sender] += borrowAmount;
        _validatePosition(msg.sender);

        bool success = i_corn.transfer(msg.sender, borrowAmount);
        if (!success) revert Lending__BorrowingFailed();

        emit AssetBorrowed(msg.sender, borrowAmount, i_cornDEX.currentPrice());
    }

    function repayCorn(uint256 repayAmount) public {
        if (repayAmount == 0 || repayAmount > s_userBorrowed[msg.sender]) {
            revert Lending__InvalidAmount();
        }

        bool success = i_corn.transferFrom(msg.sender, address(this), repayAmount);
        if (!success) revert Lending__RepayingFailed();

        s_userBorrowed[msg.sender] -= repayAmount;

        emit AssetRepaid(msg.sender, repayAmount, i_cornDEX.currentPrice());
    }

    /* ===================== LIQUIDATION ===================== */

    function liquidate(address user) public {
        if (!isLiquidatable(user)) revert Lending__NotLiquidatable();

        uint256 debt = s_userBorrowed[user];

        if (i_corn.balanceOf(msg.sender) < debt) {
            revert Lending__InsufficientLiquidatorCorn();
        }

        // liquidator pays the debt
        bool success = i_corn.transferFrom(msg.sender, address(this), debt);
        if (!success) revert Lending__TransferFailed();

        uint256 collateralValue = calculateCollateralValue(user);
        uint256 reward = (collateralValue * LIQUIDATOR_REWARD) / 100;

        uint256 totalCollateral = s_userCollateral[user];
        uint256 payout = totalCollateral + reward > totalCollateral
            ? totalCollateral
            : totalCollateral + reward;

        s_userCollateral[user] = 0;
        s_userBorrowed[user] = 0;

        (bool sent, ) = payable(msg.sender).call{ value: payout }("");
        if (!sent) revert Lending__TransferFailed();

        emit Liquidation(user, msg.sender, payout, debt, i_cornDEX.currentPrice());
    }

    receive() external payable {}
}
