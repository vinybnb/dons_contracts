const { ethers, upgrades } = require("hardhat");
const tiers = require("./tiers.json");
const _ = require("lodash");

async function main() {
  const mockERC721 = await ethers.deployContract('MockERC721');
  await mockERC721.waitForDeployment();
  console.log("NFT deployed to:", mockERC721.target);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
