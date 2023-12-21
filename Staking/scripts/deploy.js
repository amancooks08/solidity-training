// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const lockUpPeriod = 60; // 60 seconds
  // Since our baseUnit is 1e6 we set the interest rate accordingly
  const interestRate = 9000000; // 9% per year 
  const rewardToken = await hre.ethers.deployContract("RewardToken");
  await rewardToken.waitForDeployment();
  const rewardTokenAddress = await rewardToken.getAddress();  
  console.log(`RewardToken deployed to ${rewardTokenAddress}`);

  const staking  = await hre.ethers.getContractFactory("StakingContract");
  const stakingContract = await hre.upgrades.deployProxy(staking, [lockUpPeriod, interestRate, rewardTokenAddress], {initializer: 'constructor1' })

  await stakingContract.waitForDeployment();
  const stakingContractAddress = await stakingContract.getAddress();
  console.log("StakingContract deployed to:", stakingContractAddress);
  console.log(await upgrades.erc1967.getImplementationAddress(stakingContractAddress), " is the implementation address of StakingContract")
  console.log(await upgrades.erc1967.getAdminAddress(stakingContractAddress), " is the admin address of StakingContract")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
