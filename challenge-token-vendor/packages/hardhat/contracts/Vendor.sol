// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YourToken.sol";

contract Vendor is Ownable {
    YourToken public yourToken;

    uint256 public constant tokensPerEth = 100;

    event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);
    event SellTokens(address seller, uint256 amountOfTokens, uint256 amountOfETH);

    constructor(address tokenAddress) Ownable(msg.sender) {
        yourToken = YourToken(tokenAddress);
    }

    // ============ BUY TOKENS ============
    function buyTokens() public payable {
        require(msg.value > 0, "Send ETH");

        uint256 amountOfTokens = msg.value * tokensPerEth;

        require(
            yourToken.balanceOf(address(this)) >= amountOfTokens,
            "Vendor out of tokens"
        );

        yourToken.transfer(msg.sender, amountOfTokens);

        emit BuyTokens(msg.sender, msg.value, amountOfTokens);
    }

    // ============ SELL TOKENS ============
    function sellTokens(uint256 amount) public {
        require(amount > 0, "Amount must be > 0");

        uint256 ethAmount = amount / tokensPerEth;

        require(address(this).balance >= ethAmount, "Vendor out of ETH");

        yourToken.transferFrom(msg.sender, address(this), amount);
        payable(msg.sender).transfer(ethAmount);

        emit SellTokens(msg.sender, amount, ethAmount);
    }

    // ============ WITHDRAW ============
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
