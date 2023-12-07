// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingContract {
    address public owner;
    uint public lockUpPeriod; // Lock-up period in seconds
    uint public interestRate; // Annual interest rate

    struct Staker {
        uint stakedAmount;
        uint startTime;
        uint reward;
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed staker, uint amount);
    event Withdrawn(address indexed staker, uint amount);
    event RedeemReward(address indexed staker, uint amount);

    // The token that will be used to give rewards
    IERC20 public rewardToken;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(uint _lockUpPeriod, uint _interestRate, address _tokenAddress) {
        owner = msg.sender;
        lockUpPeriod = _lockUpPeriod;
        interestRate = _interestRate;  
        token = IERC20(_tokenAddress);
    }

    function stake() external payable {
        require(msg.value > 0, "Must stake a positive amount");

        // If the user is already a staker, update their staked amount
        if (stakers[msg.sender].stakedAmount > 0) {
            updateReward(msg.sender);
        } else {
            // If it's a new staker, initialize their staking details
            stakers[msg.sender] = Staker(msg.value, block.timestamp, 0);
        }

        emit Staked(msg.sender, msg.value);
    }

    function setLockUpPeriod(uint _newLockUpPeriod) external onlyOwner {
        // Only the owner can change the lock-up period
        lockUpPeriod = _newLockUpPeriod;
    }

    function changeInterestRate(uint _newInterestRate) external onlyOwner {
        // Only the owner can change the interest rate
        interestRate = _newInterestRate;
    }

    function withdraw() external {
        require(stakers[msg.sender].stakedAmount > 0, "Not a staker");
        require(block.timestamp >= stakers[msg.sender].startTime + lockUpPeriod, "Lock-up period not over");

        // Withdraw the staked amount
        bool success = payable(msg.sender).send(stakers[msg.sender].stakedAmount);
        require(success, "Failed to withdraw staked amount");

        // Reset staking details for the user
        stakers[msg.sender] = Staker(0, 0, 0);

        emit Withdrawn(msg.sender, stakers[msg.sender].stakedAmount);
    }

    function redeemReward() external {
        require(stakers[msg.sender].stakedAmount > 0, "Not a staker");

        // Update the reward
        updateReward(msg.sender);

        // Transfer the reward to the user
        rewardToken.transfer(msg.sender, stakers[msg.sender].reward);

        // Reset the reward
        stakers[msg.sender].reward = 0;

        emit RedeemReward(msg.sender, stakers[msg.sender].reward);
    }

    function updateReward(address staker) internal {
        uint interest = calculateInterest(staker);
        stakers[staker].reward += interest;
        stakers[staker].startTime = block.timestamp;
    }

    function calculateInterest(address staker) public view returns (uint) {
        uint elapsedTime = block.timestamp - stakers[staker].startTime;
        return (stakers[staker].stakedAmount * interestRate * elapsedTime) / (365 days * 100);
    }
}