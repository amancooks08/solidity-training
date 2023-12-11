// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract StakingContract {
    address payable public owner;
    uint public lockUpPeriod; // Lock-up period in seconds
    uint public interestRate; // Annual interest rate
    uint constant public baseUnit = 1e6; // Base unit multiplier

    // The fixed amount of tokens.
    uint256 public totalSupply = 10000000;

    struct Staker {
        uint stakedAmount;
        uint startTime;
        uint reward;
    }

    mapping(address => Staker) public stakers;

    // Array to store the addresses of all the stakers
    address[] public addressStakers;

    event Staked(address indexed staker, uint amount);
    event Withdrawn(address indexed staker, uint amount);
    event RedeemReward(address indexed staker, uint amount);
    event RewardAdded(uint256 reward);

    // The token that will be used to give rewards
    IERC20 public rewardToken;

    modifier onlyOwner() {
        require(msg.sender == owner, "Invalid Owner: caller is not the owner");
        _;
    }

    constructor(uint _lockUpPeriod, uint _interestRate, address _tokenAddress) payable {
        require(_lockUpPeriod > 0, "Invalid lockupPeriod: Lock-up period must be greater than 0");
        require(_interestRate > 0, "Invalid rewardRate: Reward rate must be greater than 0");
        owner = payable(msg.sender); 
        lockUpPeriod = _lockUpPeriod;
        interestRate = _interestRate;  
        rewardToken = IERC20(_tokenAddress);
    }

    function stake() external payable {
        require(msg.value > 0, "Invalid amount: Must stake a positive amount");

        // If the user is already a staker, update their staked amount
        if (stakers[msg.sender].stakedAmount > 0) {
            stakers[msg.sender].stakedAmount += msg.value;
            updateReward(msg.sender);
        } else {
            // If it's a new staker, initialize their staking details
            stakers[msg.sender] = Staker(msg.value, block.timestamp, 0);
            addressStakers.push(msg.sender);
        }

        emit Staked(msg.sender, msg.value);
    }

    function setLockUpPeriod(uint _newLockUpPeriod) external onlyOwner {
        require(_newLockUpPeriod > 0, "Invalid lockupPeriod: Lock-up period must be greater than 0");
        // Only the owner can change the lock-up period
        lockUpPeriod = _newLockUpPeriod;
    }

    function changeInterestRate(uint _newInterestRate) external onlyOwner {
        require(_newInterestRate > 0, "Invalid rewardRate: Reward rate must be greater than 0");
        // Only the owner can change the interest rate
        interestRate = _newInterestRate;
    }

    function withdraw() external {
        // Check if the user is a staker or not
        require(stakers[msg.sender].stakedAmount > 0, "Not a staker: You have not staked any amount");

        // Check if the lock-up period is over or not
        require(block.timestamp >= stakers[msg.sender].startTime + lockUpPeriod, "Lock-up period not over: You cannot withdraw before lock-up period is over");

        // Redeem the reward
        redeemReward(msg.sender);

        // Withdraw the staked amount
        (bool success, ) = payable(msg.sender).call{value: stakers[msg.sender].stakedAmount}("");
        require(success, "Failed to withdraw staked amount");

        // Emit the event
        emit Withdrawn(msg.sender, stakers[msg.sender].stakedAmount);
        
        // Reset staking details for the user
        stakers[msg.sender] = Staker(0, 0, 0);
    }

    function redeemReward(address staker) internal {
        require(stakers[staker].stakedAmount > 0, "Not a staker");
        require(totalSupply >= stakers[staker].reward, "Reward Can't be redeemed right now: insufficient tokens");
        
        // Update the reward
        updateReward(msg.sender);

        // Check if the user has any reward to redeem
        require(stakers[staker].reward > 0, "No reward to redeem");

        // Transfer the reward to the user
        rewardToken.transfer(staker, stakers[msg.sender].reward);

        // Subtract the tokens from the total supply
        totalSupply -= stakers[staker].reward;

        // Reset the reward
        stakers[staker].reward = 0;

        emit RedeemReward(msg.sender, stakers[msg.sender].reward);
    }

    function updateReward(address staker) internal {

        // Check if the user is a staker
        require(stakers[staker].stakedAmount > 0, "Incorrect Address: Not a staker");
        
        // Calculate the interest
        uint interest = calculateInterest(staker);
        stakers[staker].reward += interest;
        stakers[staker].startTime = block.timestamp;
    }

    function calculateInterest(address staker) public view returns (uint) {
        uint elapsedTime = block.timestamp - stakers[staker].startTime;
        return (stakers[staker].stakedAmount * interestRate * elapsedTime) / (365 days * baseUnit * 100);
    }

    // Add Reward function adds an additional reward to the contract balance which is divided
    // proportionally among the stakers.
    function addReward(uint256 rewardAmount) external onlyOwner {
        require(rewardAmount > 0, "Invalid amount: Must add a positive amount");

        // Transfer ERC20 tokens to the contract
        require(rewardToken.transferFrom(msg.sender, address(this), rewardAmount), "Failed to transfer ERC20 tokens");

        // Calculate total staked amount
        uint totalStakedAmount = 0;
        for (uint i = 0; i < addressStakers.length; i++) {
            if (stakers[addressStakers[i]].stakedAmount > 0) {
                totalStakedAmount += stakers[addressStakers[i]].stakedAmount;
            }
        }
        // Distribute reward proportionally
        for (uint i = 0; i < addressStakers.length; i++) {
            uint stakerShare = (stakers[addressStakers[i]].stakedAmount * rewardAmount) / totalStakedAmount;
            stakers[addressStakers[i]].reward += stakerShare;
            totalSupply += stakerShare; // Update totalSupply
        }

        // Emit event
        emit RewardAdded(rewardAmount);
    }
}