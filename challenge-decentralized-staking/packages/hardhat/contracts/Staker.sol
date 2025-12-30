// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./ExampleExternalContract.sol";

contract Staker {
    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) public balances;
    uint256 public constant threshold = 1 ether;

    uint256 public immutable deadline;
    bool public openForWithdraw;

    event Stake(address indexed staker, uint256 amount);

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
        deadline = block.timestamp + 72 hours;
    }

    modifier notCompleted() {
        require(!exampleExternalContract.completed(), "Executed");
        _;
    }

    function stake() public payable notCompleted {
        require(msg.value > 0, "Must send ETH");
        balances[msg.sender] += msg.value;
        emit Stake(msg.sender, msg.value);
    }

    function execute() public notCompleted {
        require(block.timestamp >= deadline, "Deadline not reached");

        if (address(this).balance >= threshold) {
            exampleExternalContract.complete{value: address(this).balance}();
        } else {
            openForWithdraw = true;
        }
    }

    function withdraw() notCompleted public {
      require(openForWithdraw, "Contract not openForWithdraw");
      uint balance = balances[msg.sender];
      delete balances[msg.sender];
      (bool success,) = payable(msg.sender).call{value: balance}("");
      require(success, "Withdraw failed");
  }

    function timeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return deadline - block.timestamp;
    }

    receive() external payable {
        stake();
    }
}
