const { ethers, upgrades } = require("hardhat");
const tiers = require("./tiers.json");
const _ = require("lodash");

async function main() {
  const stakingNFTRarity = await ethers.deployContract('StakingNFTRarity');
  await stakingNFTRarity.waitForDeployment();
  console.log("Staking NFT deployed to:", stakingNFTRarity.target);

  //Chunk tiers to 500 to avoid gas limit
  const chunkedTiers = _.chunk(tiers, 500);
  for (let i = 0; i < chunkedTiers.length; i++) {
    await stakingNFTRarity.addTiers(chunkedTiers[i]);
    console.log(`Tiers set for chunk ${i + 1} of ${chunkedTiers.length}`);
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
