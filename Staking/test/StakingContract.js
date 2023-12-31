const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Staking", function () {
  let owner;
  let staker;
  let StakingContract;
  let stakingContract;
  let rewardToken;

  const lockUpPeriod = 60; // 60 seconds for testing
  const interestRate = 10000; 
  const rewardTokenInitialSupply = 1000000;

  beforeEach(async function () {
    [owner, staker] = await ethers.getSigners();

    // Deploy ERC-20 token contract
    const RewardTokenFactory = await ethers.getContractFactory('RewardToken');
    rewardToken = await RewardTokenFactory.deploy();

    // Deploy Staking contract
    StakingContract = await ethers.getContractFactory('StakingContract');
    stakingContract = await StakingContract.deploy(lockUpPeriod, interestRate, await rewardToken.getAddress());

    // Mint initial supply to Staking contract
    await rewardToken.transfer(await stakingContract.getAddress(), rewardTokenInitialSupply);
  });


  describe("Deployment", function () {
    describe("LockUpPeriod", function () {
      it("Should set the right lockupPeriod", async function () {
        expect(await stakingContract.lockUpPeriod()).to.equal(60);
      });
  
      it("Should revert for invalid lockupPeriod", async function () {
        await expect(StakingContract.deploy(0, interestRate, await rewardToken.getAddress())).to.be.revertedWith("Invalid lockupPeriod: Lock-up period must be greater than 0");
      });
    });

    describe("RewardRate", function () {
      it("Should set the right rewardRate", async function () {
        expect(await stakingContract.interestRate()).to.equal(interestRate);
      });
  
      it("Should revert for invalid rewardRate", async function () {
        await expect(StakingContract.deploy(lockUpPeriod, 0, await rewardToken.getAddress())).to.be.revertedWith("Invalid rewardRate: Reward rate must be greater than 0");
      });
    });

    describe("RewardToken", function () {
      it("Should set the right rewardToken", async function () {
        expect(await rewardToken.balanceOf(await stakingContract.getAddress())).to.equal(rewardTokenInitialSupply);
      });
    });
  });

  describe("SetLockUpPeriod", function () {
    it("Should revert for non-owner", async function () {
      await expect(stakingContract.connect(staker).setLockUpPeriod(10)).to.be.revertedWith("Invalid Owner: caller is not the owner");
    });

    it("Should revert for invalid lockupPeriod", async function () {
      await expect(stakingContract.setLockUpPeriod(0)).to.be.revertedWith("Invalid lockupPeriod: Lock-up period must be greater than 0");
    });

    it("Should set the right lockupPeriod", async function () {
      await stakingContract.setLockUpPeriod(10);
      expect(await stakingContract.lockUpPeriod()).to.equal(10);
    });
  });

  describe("changeInterestRate", function () {
    it("Should revert for non-owner", async function () {
      await expect(stakingContract.connect(staker).changeInterestRate(10)).to.be.revertedWith("Invalid Owner: caller is not the owner");
    });

    it("Should revert for invalid rewardRate", async function () {
      await expect(stakingContract.changeInterestRate(0)).to.be.revertedWith("Invalid rewardRate: Reward rate must be greater than 0");
    });

    it("Should set the right rewardRate", async function () {
      await stakingContract.changeInterestRate(10);
      expect(await stakingContract.interestRate()).to.equal(10);
    });
  });

  describe("Stake", function () {
    it("Should revert for invalid amount", async function () {
      await expect(stakingContract.connect(staker).stake({ value: 0 })).to.be.revertedWith("Invalid amount: Must stake a positive amount");
    });

    it("Should stake successfully", async function () {
      const initialStakeAmount = ethers.parseEther("1");
      const stakersBalance = await ethers.provider.getBalance(staker.address);
      const contractBalance = await ethers.provider.getBalance(await stakingContract.getAddress());
      
      // User stakes ETH
      const transaction = await stakingContract.connect(staker).stake({ value: initialStakeAmount });
      
      // Check staker details
      const user = await stakingContract.stakers(staker.address);
      expect(user.stakedAmount).to.equal(initialStakeAmount);
      expect(user.startTime).to.not.equal(0);
      expect(user.reward).to.equal(0);
      
      // Expect change in user's state
      expect(await ethers.provider.getBalance(staker.address)).to.lt(stakersBalance);
      
      // Expect change in contract's state
      expect(await ethers.provider.getBalance(await stakingContract.getAddress())).to.gt(contractBalance);

      // Check emitted event 
      await expect(transaction).
      to.emit(stakingContract, "Staked").
      withArgs(staker.address, initialStakeAmount);
    });

    it("Should stake successfully if staker already staked", async function () {
      const initialStakeAmount = ethers.parseEther("1");
      const stakersBalance = await ethers.provider.getBalance(staker.address);
      const contractBalance = await ethers.provider.getBalance(await stakingContract.getAddress());
      
      // User stakes ETH
      await stakingContract.connect(staker).stake({ value: initialStakeAmount });

      // We will be not be checking the state here as it will be same as above test case
      // and result in duplicacy of test cases.

      // User stakes again
      const additionalStakeAmount = ethers.parseEther("0.5");
      await stakingContract.connect(staker).stake({ value: additionalStakeAmount });
      
      const user = await stakingContract.stakers(staker.address);
      expect(user.stakedAmount).to.equal(initialStakeAmount + additionalStakeAmount);

      // Check emitted event
      await expect(stakingContract.connect(staker).stake({ value: additionalStakeAmount })).
      to.emit(stakingContract, "Staked").
      withArgs(staker.address, additionalStakeAmount);

    });
  });

  describe("Withdraw", function () {
    it("Should revert for not a staker if not staked any amount", async function () {
      await expect(stakingContract.connect(staker).withdraw()).to.be.revertedWith("Not a staker: You have not staked any amount");
    });

    it("Should revert if lockup period is not over", async function () {
      const initialStakeAmount = ethers.parseEther("1");
      await stakingContract.connect(staker).stake({ value: initialStakeAmount });
      await expect(stakingContract.connect(staker).withdraw()).to.be.revertedWith("Lock-up period not over: You cannot withdraw before lock-up period is over");
    });

    it("Should withdraw successfully", async function () {
      const initialStakeAmount = ethers.parseEther("0.0001");
      const stakersBalance = await ethers.provider.getBalance(staker.address);
      
      // User stakes ETH
      await stakingContract.connect(staker).stake({ value: initialStakeAmount });

      // Keep track of contract's balance before withdrawing
      const contractBalance = await ethers.provider.getBalance(await stakingContract.getAddress());

      // Increase time by lockupPeriod
      await time.increase(lockUpPeriod);

      // Keep track of staker's balance before withdrawing
      const stakersBalanceB = await ethers.provider.getBalance(staker.address);

      // User withdraws ETH
      const transaction = await stakingContract.connect(staker).withdraw();
      
      // Check staker details
      const user = await stakingContract.stakers(staker.address);
      expect(user.stakedAmount).to.equal(0);
      expect(user.startTime).to.equal(0);
      expect(user.reward).to.equal(0);
      
      // Expect change in user's state
      expect(await ethers.provider.getBalance(staker.address)).to.gt(stakersBalanceB);
      
      // Expect change in contract's state
      expect(await ethers.provider.getBalance(await stakingContract.getAddress())).to.lt(contractBalance);

      // Check emitted event 
      await expect(transaction).
      to.emit(stakingContract, "Withdrawn").
      withArgs(staker.address, initialStakeAmount);
    });
  });
});