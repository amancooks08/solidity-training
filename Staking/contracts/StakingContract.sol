// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract StakingContract {
    address payable public owner;
    uint256 public lockUpPeriod; // Lock-up period in seconds
    uint24 public interestRate; // Annual interest rate
    uint24 constant public percentageBaseUnit = 1e6; // Base unit multiplier
    uint256 constant private coefficientBaseUnit = 1e18; // Base unit multiplier
    uint256 private totalStakedAmount; // Total staked amount

    uint256 private rewardCoefficient; // Reward coefficient
    // The fixed amount of tokens.
    uint256 public totalSupply = 10000000;

    struct Staker {
        uint256 stakedAmount;
        uint256 startTime;
        uint128 reward;
        uint256 userCoefficient;
    }

    mapping(address => Staker) public stakers;

    event Staked(address indexed staker, uint256 amount);
    event Withdrawn(address indexed staker, uint256 amount);
    event RedeemReward(address indexed staker, uint256 amount);
    event RewardAdded(uint256 reward);

    // The token that will be used to give rewards
    IERC20 public rewardToken;

    modifier onlyOwner() {
        require(msg.sender == owner, "Invalid Owner: caller is not the owner");
        _;
    }

    constructor(uint256 _lockUpPeriod, uint24 _interestRate, address _tokenAddress) payable {
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
            updateReward(msg.sender);
            stakers[msg.sender].stakedAmount += msg.value;
        } else {
            // If it's a new staker, initialize their staking details
            stakers[msg.sender] = Staker(msg.value, block.timestamp, 0, rewardCoefficient);
        }
        totalStakedAmount += msg.value;
        emit Staked(msg.sender, msg.value);
    }

    function setLockUpPeriod(uint256 _newLockUpPeriod) external onlyOwner {
        require(_newLockUpPeriod > 0, "Invalid lockupPeriod: Lock-up period must be greater than 0");
        // Only the owner can change the lock-up period
        lockUpPeriod = _newLockUpPeriod;
    }

    function changeInterestRate(uint24 _newInterestRate) external onlyOwner {
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
        
        // Subtract the staked amount from the total staked amount
        totalStakedAmount -= stakers[msg.sender].stakedAmount;

        // Reset staking details for the user
        stakers[msg.sender] = Staker(0, 0, 0, 0);
    }

    function redeemReward(address staker) internal {
        require(stakers[staker].stakedAmount > 0, "Not a staker");
        
        // Update the reward
        updateReward(msg.sender);

        // Check if the user has any reward to redeem
        require(stakers[staker].reward > 0, "No reward to redeem");

        // Check if the contract has enough reward to redeem
        require(totalSupply >= stakers[staker].reward, "Reward Can't be redeemed right now: insufficient tokens");

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
        
        // Update the additional reward
        updateAdditionalReward(staker);

        // Calculate the interest
        uint128 interest = calculateInterest(staker);
        stakers[staker].reward += interest;
        stakers[staker].startTime = block.timestamp;
    }

    function calculateInterest(address staker) public view returns (uint128) {
        uint256 elapsedTime = block.timestamp - stakers[staker].startTime;
        return uint128((stakers[staker].stakedAmount * interestRate * elapsedTime) / (365 days * uint256(percentageBaseUnit) * 100));
    }

    // Add Reward function adds an additional reward to the contract balance which is divided
    // proportionally among the stakers.
    function addReward(uint256 rewardAmount) external onlyOwner {
        require(rewardAmount > 0, "Invalid amount: Must add a positive amount");

        // Transfer ERC20 tokens to the contract
        require(rewardToken.transferFrom(msg.sender, address(this), rewardAmount), "Failed to transfer ERC20 tokens");

        // Update the global reward coefficient
        rewardCoefficient += (rewardAmount * coefficientBaseUnit) /totalStakedAmount;
       
        // Emit event
        emit RewardAdded(rewardAmount);
    }

    function updateAdditionalReward(address staker) internal {
        uint128 additionalRewardAmount;
        if(stakers[staker].userCoefficient != rewardCoefficient) {
            additionalRewardAmount = uint128(((stakers[staker].stakedAmount * rewardCoefficient) - (stakers[staker].stakedAmount * stakers[staker].userCoefficient))/coefficientBaseUnit);
            stakers[staker].userCoefficient = rewardCoefficient;
        } else {
            additionalRewardAmount = uint128((rewardCoefficient * stakers[staker].stakedAmount)/coefficientBaseUnit);
        }
        stakers[staker].reward += additionalRewardAmount;
    }
}