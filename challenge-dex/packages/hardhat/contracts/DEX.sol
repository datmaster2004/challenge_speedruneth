// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    IERC20 public token;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    event EthToTokenSwap(address swapper, uint256 tokenOutput, uint256 ethInput);
    event TokenToEthSwap(address swapper, uint256 tokensInput, uint256 ethOutput);
    event LiquidityProvided(address liquidityProvider, uint256 liquidityMinted, uint256 ethInput, uint256 tokensInput);
    event LiquidityRemoved(address liquidityRemover, uint256 liquidityWithdrawn, uint256 tokensOutput, uint256 ethOutput);

    /* ========== CONSTRUCTOR ========== */

    constructor(address tokenAddr) {
        token = IERC20(tokenAddr);
    }

    /* ========== CORE LOGIC ========== */

    /// INIT LIQUIDITY (chỉ chạy 1 lần)
    function init(uint256 tokens) public payable returns (uint256) {
        require(totalLiquidity == 0, "DEX already initialized");
        require(msg.value > 0 && tokens > 0, "Invalid init amounts");

        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;

        require(token.transferFrom(msg.sender, address(this), tokens), "Token transfer failed");

        return totalLiquidity;
    }

    /// x * y = k (có fee 0.3%)
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        require(xReserves > 0 && yReserves > 0, "Invalid reserves");

        uint256 xInputWithFee = xInput * 997;
        uint256 numerator = xInputWithFee * yReserves;
        uint256 denominator = (xReserves * 1000) + xInputWithFee;

        yOutput = numerator / denominator;
    }

    function getLiquidity(address lp) public view returns (uint256) {
        return liquidity[lp];
    }

    /* ========== SWAPS ========== */

    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "No ETH sent");

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));

        tokenOutput = price(msg.value, ethReserve, tokenReserve);

        require(token.transfer(msg.sender, tokenOutput), "Token transfer failed");

        emit EthToTokenSwap(msg.sender, tokenOutput, msg.value);
    }

    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "No tokens sent");

        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethReserve = address(this).balance;

        ethOutput = price(tokenInput, tokenReserve, ethReserve);

        require(token.transferFrom(msg.sender, address(this), tokenInput), "Token transfer failed");
        payable(msg.sender).transfer(ethOutput);

        emit TokenToEthSwap(msg.sender, tokenInput, ethOutput);
    }

    /* ========== LIQUIDITY ========== */

    function deposit() public payable returns (uint256 tokensDeposited) {
        require(msg.value > 0, "No ETH sent");

        uint256 ethReserve = address(this).balance - msg.value;
        uint256 tokenReserve = token.balanceOf(address(this));

        tokensDeposited = (msg.value * tokenReserve) / ethReserve +1 ;

        uint256 liquidityMinted = (msg.value * totalLiquidity) / ethReserve;

        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        require(token.transferFrom(msg.sender, address(this), tokensDeposited), "Token transfer failed");

        emit LiquidityProvided(msg.sender, liquidityMinted, msg.value, tokensDeposited);
    }

    function withdraw(uint256 amount) public returns (uint256 ethAmount, uint256 tokenAmount) {
        require(amount > 0, "Invalid amount");
        require(liquidity[msg.sender] >= amount, "Not enough liquidity");

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = token.balanceOf(address(this));

        ethAmount = (amount * ethReserve) / totalLiquidity;
        tokenAmount = (amount * tokenReserve) / totalLiquidity;

        liquidity[msg.sender] -= amount;
        totalLiquidity -= amount;

        payable(msg.sender).transfer(ethAmount);
        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");

        emit LiquidityRemoved(msg.sender, amount, tokenAmount, ethAmount);
    }
}
