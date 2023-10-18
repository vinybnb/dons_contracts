// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StakingNFTRarity} from "../../contracts/StakingNFTRarity.sol";
import "../../contracts/MockERC20.sol";

contract PrivateSaleTest is Test {
  IERC20Detailed public token;
  IERC20Detailed public paymentToken;
  PrivateSale public privateSale;

  address public constant USER = address(1);
  address public constant REF_BY_USER = address(2);

  function setUp() public {
    token = IERC20Detailed(address(new MockERC20(18)));
    paymentToken = IERC20Detailed(address(new MockERC20(6)));
    privateSale = new PrivateSale(token, paymentToken);
    paymentToken.mint(USER, 100_000_000 * 10 ** 6);
    token.mint(address(privateSale), 100_000_000 * 10 ** 18);
  }

  function test_SetUp() public {
    assertEq(address(token), address(privateSale.token()));
    assertEq(address(paymentToken), address(privateSale.paymentToken()));
    assertEq(125 * 10 ** 2, privateSale.privatesalePrice());
    assertEq(150_000_000 * 10 ** 18, privateSale.maxRaiseToken());
    assertEq(10_00, privateSale.refPercent());
    assertEq(false, privateSale.enabled());
    assertEq(false, privateSale.claimEnabled());
  }

  function test_BuyAndClaim() public {
    privateSale.setEnabled(true);
    privateSale.setClaimEnabled(true);

    vm.startPrank(USER);
    paymentToken.approve(address(privateSale), 100_000_000 * 10 ** 6);
    privateSale.buy(100 * 10 ** 6, address(0));
    ///Buy 100 usdt token => shoud receive 8000 token
    assertEq(8000 * 10 ** 18, privateSale.boughtAmount(USER));
    ///Claim -> should receive 4000 token
    assertEq(4000 * 10 ** 18, privateSale.getClaimableAmount(USER));
    privateSale.claim();
    assertEq(4000 * 10 ** 18, token.balanceOf(USER));
    vm.stopPrank();
  }

   function test_BuyAndClaimWithRef() public {
    privateSale.setEnabled(true);
    privateSale.setClaimEnabled(true);

    vm.startPrank(USER);
    paymentToken.approve(address(privateSale), 100_000_000 * 10 ** 6);
    paymentToken.transfer(REF_BY_USER, 200 * 10 ** 6);
    privateSale.buy(100 * 10 ** 6, address(0));
    ///Buy 100 usdt token => shoud receive 8000 token
    assertEq(8000 * 10 ** 18, privateSale.boughtAmount(USER));
    ///Claim -> should receive 4000 token
    assertEq(4000 * 10 ** 18, privateSale.getClaimableAmount(USER));
    privateSale.claim();
    assertEq(4000 * 10 ** 18, token.balanceOf(USER));
    vm.stopPrank();

    vm.startPrank(REF_BY_USER);
    paymentToken.approve(address(privateSale), 100_000_000 * 10 ** 6);
    uint256 refAmount = 200 * 10 ** 6 * 10_00 / 100_00;
    uint256 userPaymentAmountBefore = paymentToken.balanceOf(USER);
    privateSale.buy(200 * 10 ** 6, address(USER));
    ///Buy 200 usdt token => shoud receive 16000 token, and 10% of 200usdt token will be sent to ref
    assertEq(16000 * 10 ** 18, privateSale.boughtAmount(REF_BY_USER));
    uint256 userPaymentAmountAfter = paymentToken.balanceOf(USER);
    assertEq(userPaymentAmountBefore + refAmount, userPaymentAmountAfter);
    vm.stopPrank();
  }

  function test_BuyAndClaimByRelease() public {
    privateSale.setEnabled(true);
    privateSale.setClaimEnabled(true);

    vm.startPrank(USER);
    paymentToken.approve(address(privateSale), 100_000_000 * 10 ** 6);
    privateSale.buy(100 * 10 ** 6, address(0));
    ///Buy 100 usdt token => shoud receive 8000 token
    assertEq(8000 * 10 ** 18, privateSale.boughtAmount(USER));
    ///Claim -> should receive 4000 token
    assertEq(4000 * 10 ** 18, privateSale.getClaimableAmount(USER));
    privateSale.claim();
    assertEq(4000 * 10 ** 18, token.balanceOf(USER));
    vm.stopPrank();

    privateSale.setReleasePercent(60_00);
    vm.startPrank(USER);
    ///Claim -> should receive 800 token more
    privateSale.claim();
    assertEq(4800 * 10 ** 18, token.balanceOf(USER));
    vm.stopPrank();

    privateSale.setReleasePercent(100_00);
    vm.startPrank(USER);
    ///Claim -> should receive full token
    privateSale.claim();
    assertEq(8000 * 10 ** 18, token.balanceOf(USER));
    vm.stopPrank();
  }
}