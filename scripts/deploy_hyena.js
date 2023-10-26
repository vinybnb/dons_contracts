const { ethers, upgrades } = require("hardhat");
const tiers = require("./hyena_tiers.json");
const _ = require("lodash");

async function main() {
  const tokenContract = "0xC8c60ff8e5a8B29f9f779C1E83F71fFCc7CC7e81";
  const nftContract = "0xc340BbB7BbB4f4a7d4A74E84EB99d40d91DF060E";

  const stakingNFTRarity = await ethers.deployContract('StakingNFTRarity', [
    3333,
    tokenContract,
    nftContract,
  ]);
  await stakingNFTRarity.waitForDeployment();
  console.log("Staking Hyena NFT deployed to:", stakingNFTRarity.target);

  //Chunk tiers to 2000 to avoid gas limit
  console.log(`Setting tiers for ${tiers.length} NFTS`);
  const chunkedTiers = _.chunk(tiers, 2000);
  for (let i = 0; i < chunkedTiers.length; i++) {
    const tx = await stakingNFTRarity.addTiers(chunkedTiers[i]);
    await tx.wait();
    console.log(`Tiers set for chunk ${i + 1} of ${chunkedTiers.length}`);
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
