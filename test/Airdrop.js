const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { StandardMerkleTree } = require("@openzeppelin/merkle-tree");
const fs = require("fs");

describe("Airdrop", function () {

  it("Should Claim", async function () {
    const [owner, otherAccount] = await ethers.getSigners();
    const tree = StandardMerkleTree.load(JSON.parse(fs.readFileSync("out/tree_out.json")));
    const treeRoot = tree.root;
    console.log("Merkle Root: " + treeRoot)
    const mockERC20 = await ethers.deployContract("MockERC20");
    console.log("ERC20: " + mockERC20.target)
    const airdrop = await ethers.deployContract(
      "Airdrop",
      [
        tree.root,/// merkele root
        mockERC20.target/// token
      ]
    );
    console.log("Airdrop: " + airdrop.target)
    await airdrop.updateAirdropStatus(true);
    await mockERC20.mint(airdrop.target, ethers.parseUnits("100000000000000000", "ether"));
    const airdropBalance = await mockERC20.balanceOf(airdrop.target);
    console.log("Airdrop Balance: " + ethers.formatEther(airdropBalance))
    /// Impersonate Account 1
    const [user, amount] = tree.values[0].value;
    /// impersonate account
    console.log("Claim as " + user);
    // Transfer ETH to user
    await owner.sendTransaction({
      to: user,
      value: ethers.parseEther("1.0")
    });
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [user],
    });
    // Set Signer
    const signer = await ethers.provider.getSigner(user);
    // Set Contract
    const airdropContract = new ethers.Contract(airdrop.target, airdrop.interface, signer);
    /// Get Proof
    let claimAmount;
    let claimProof;
    for (const [i, v] of tree.entries()) {
      if (v[0] === user) {
        const proof = tree.getProof(i);
        console.log('Value:', v);
        [address, claimAmount] = v;
        console.log('Claim full amount', ethers.formatEther(claimAmount));
        console.log('Proof:', proof);
        claimProof = proof;
      }
    }
    // Balance before
    const balanceBefore = await mockERC20.balanceOf(user);
    console.log("Balance Before: " + ethers.formatEther(balanceBefore));
    await airdropContract.claim(
      claimProof,
      claimAmount
    );
    // Balance after
    const balanceAfter = await mockERC20.balanceOf(user);
    console.log("Balance After: " + ethers.formatEther(balanceAfter));

    await airdrop.setReleasePercent(60_00);
    await airdropContract.claim(
      claimProof,
      claimAmount
    );
    // Balance after
    const balanceAfter2 = await mockERC20.balanceOf(user);
    console.log("Balance After set percent to 60% and claim: " + ethers.formatEther(balanceAfter2));
  });

});
