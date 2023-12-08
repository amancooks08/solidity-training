const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
// import console.log

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

    // Give staker some ETH
    // await owner.send(staker.address, 100000000000000);
  });


  describe("Deployment", function () {
    it("Should set the right lockupPeriod", async function () {
      expect(await stakingContract.lockUpPeriod()).to.equal(60);
    });

    it("Should revert for invalid lockupPeriod", async function () {
      await expect(StakingContract.deploy(0, interestRate, await rewardToken.getAddress())).to.be.revertedWith("Invalid lockupPeriod: Lock-up period must be greater than 0");
    });

    it("Should set the right rewardRate", async function () {
      expect(await stakingContract.interestRate()).to.equal(interestRate);
    });

    it("Should revert for invalid rewardRate", async function () {
      await expect(StakingContract.deploy(lockUpPeriod, 0, await rewardToken.getAddress())).to.be.revertedWith("Invalid rewardRate: Reward rate must be greater than 0");
    });

    it("Should set the right rewardToken", async function () {
      expect(await rewardToken.balanceOf(await stakingContract.getAddress())).to.equal(rewardTokenInitialSupply);
    });
  });
});