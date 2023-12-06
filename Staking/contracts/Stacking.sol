// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StakingContract {
    address public owner;
    uint public lockUpPeriod; // Lock-up period in seconds
    uint public interestRate; // Annual interest rate

    struct Staker {
        uint stakedAmount;
        uint startTime;
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed staker, uint amount);
    event Withdrawn(address indexed staker, uint amount);


    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(uint _lockUpPeriod, uint _interestRate) {
        owner = msg.sender;
        lockUpPeriod = _lockUpPeriod;
        interestRate = _interestRate;
    }

    function stake() external payable {
        require(msg.value > 0, "Must stake a positive amount");

        // If the user is already a staker, update their staked amount
        if (stakers[msg.sender].stakedAmount > 0) {
            updateReward(msg.sender);
        } else {
            // If it's a new staker, initialize their staking details
            stakers[msg.sender] = Staker(msg.value, block.timestamp);
        }

        emit Staked(msg.sender, msg.value);
    }

    function setLockUpPeriod(uint _newLockUpPeriod) external onlyOwner {
        // Only the owner can change the lock-up period
        lockUpPeriod = _newLockUpPeriod;
    }

    function withdraw() external {
        require(stakers[msg.sender].stakedAmount > 0, "Not a staker");
        require(block.timestamp >= stakers[msg.sender].startTime + lockUpPeriod, "Lock-up period not over");

        // Calculate the interest accrued
        uint interest = calculateInterest(msg.sender);

        // Withdraw the staked amount plus interest
        payable(msg.sender).transfer(stakers[msg.sender].stakedAmount + interest);

        // Reset staking details for the user
        stakers[msg.sender] = Staker(0, 0);

        emit Withdrawn(msg.sender, stakers[msg.sender].stakedAmount);
    }

    function updateReward(address staker) internal {
        uint interest = calculateInterest(staker);
        stakers[staker].stakedAmount += interest;
        stakers[staker].startTime = block.timestamp;
    }

    function calculateInterest(address staker) public view returns (uint) {
        uint elapsedTime = block.timestamp - stakers[staker].startTime;
        return (stakers[staker].stakedAmount * interestRate * elapsedTime) / (365 days * 100);
    }
}