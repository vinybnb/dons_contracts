// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StakingNFTRarity} from "../../contracts/StakingNFTRarity.sol";
import "../../contracts/MockERC20.sol";
import "../../contracts/MockERC721.sol";

contract StakingNFTRarityTest is Test {
    uint256 ONE_DAY_IN_SECONDS = 24 * 60 * 60;

    MockERC20 public token;
    MockERC721 public nft;
    StakingNFTRarity public stakingNFTRarity;

    address public constant USER = address(1);

    function setUp() public {
        token = new MockERC20(18);
        nft = new MockERC721();
        stakingNFTRarity = new StakingNFTRarity(
            2222,
            address(token),
            address(nft)
        );
        token.mint(address(stakingNFTRarity), 100_000 * 10 ** 18);
        uint8[] memory tiers = new uint8[](4);
        tiers[0] = 1;
        tiers[1] = 2;
        tiers[2] = 3;
        tiers[3] = 2;
        stakingNFTRarity.addTiers(tiers);
        nft.mint(USER, 1);
        nft.mint(USER, 2);
        nft.mint(USER, 3);
        nft.mint(USER, 4);
    }

    function test_SetUp() public {
        assertFalse(
            address(token) != address(stakingNFTRarity.tokenContract())
        );
        assertFalse(address(nft) != address(stakingNFTRarity.nftContract()));
        // assertEq(stakingNFTRarity.getDailyAPRById(1), 172 * 1e18);
        // assertEq(stakingNFTRarity.getDailyAPRById(2), 103 * 1e18);
        // assertEq(stakingNFTRarity.getDailyAPRById(3), 69 * 1e18);
        // assertEq(stakingNFTRarity.getDailyAPRById(4), 103 * 1e18);
    }

    function test_Stake() public {
        stakingNFTRarity.setEnabled(true);
        vm.startPrank(USER);
        nft.approve(address(stakingNFTRarity), 1);
        stakingNFTRarity.stake(1);
        assertEq(stakingNFTRarity.getStakeDetail(0).stakedNFTId, 1);
        assertEq(stakingNFTRarity.stakeHolderCount(), 1);
        vm.stopPrank();
    }

    function test_Claim() public {
        test_Stake();
        vm.startPrank(USER);
        assertEq(stakingNFTRarity.getStakeDetail(0).claimedAmount, 0);
        skip(ONE_DAY_IN_SECONDS);
        stakingNFTRarity.claim(0);
        assertApproxEqAbs(
            stakingNFTRarity.getStakeDetail(0).claimedAmount,
            172 * 1e18,
            1e18
        );
        assertApproxEqAbs(token.balanceOf(USER), 172 * 1e18, 1e18);
        vm.stopPrank();
    }

    function test_ClaimAll() public {
        test_Stake();
        vm.startPrank(USER);
        nft.approve(address(stakingNFTRarity), 2);
        stakingNFTRarity.stake(2);
        vm.stopPrank();
        vm.startPrank(USER);
        assertEq(stakingNFTRarity.getStakeDetail(0).claimedAmount, 0);
        assertEq(stakingNFTRarity.getStakeDetail(1).claimedAmount, 0);
        skip(ONE_DAY_IN_SECONDS);
        stakingNFTRarity.claimAll();
        assertApproxEqAbs(
            stakingNFTRarity.getStakeDetail(0).claimedAmount,
            172 * 1e18,
            1e18
        );
        assertApproxEqAbs(
            stakingNFTRarity.getStakeDetail(1).claimedAmount,
            103 * 1e18,
            1e18
        );
        assertApproxEqAbs(token.balanceOf(USER), 172 * 1e18 + 103 * 1e18, 1e18);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        stakingNFTRarity.setEnabled(true);
        vm.startPrank(USER);
        nft.approve(address(stakingNFTRarity), 2);
        stakingNFTRarity.stake(2);
        assertEq(stakingNFTRarity.getStakeDetail(0).stakedNFTId, 2);
        skip(2 * ONE_DAY_IN_SECONDS);
        stakingNFTRarity.claim(0);
        assertApproxEqAbs(
            stakingNFTRarity.getStakeDetail(0).claimedAmount,
            2 * 103 * 1e18,
            1e18
        );
        assertApproxEqAbs(token.balanceOf(USER), 2 * 103 * 1e18, 1e18);
        stakingNFTRarity.withdraw(0);
        assertEq(nft.ownerOf(2), USER);
        assertEq(stakingNFTRarity.stakeHolderCount(), 0);
        vm.stopPrank();
    }
}
