// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RevenueTest } from "./helpers/RevenueTest.sol";
import { TestToken, Errors } from "./helpers/RoomsTest.sol";

contract BalanceTrap {
    function balanceOf(address) external pure returns (uint256) {
        revert("must not call");
    }
}

contract ConfiscatableToken is TestToken {
    function confiscate(address from, uint256 amount) external {
        _burn(from, amount);
    }
}

contract RoomsTreasuryTest is RevenueTest {
    function testTreasuryUsesCurrentReceiverAndFailureIsRetryable() public {
        fundedPrize();
        gov.setTreasuryRecipient(bob);
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        revenue.flushTreasury(address(token), 10 ether);
        assertEq(inspect.accounting(address(token)).treasuryAvailable, 28.5 ether);
        token.setFail(false);
        gov.setPaused(true);
        gov.setAssetApproved(address(token), false);
        uint256 before = token.balanceOf(bob);
        assertEq(revenue.flushTreasury(address(token), 10 ether), 10 ether);
        assertEq(token.balanceOf(bob), before + 10 ether);
        assertBacked(address(token));
        vm.expectRevert(Errors.ZeroAmount.selector);
        revenue.flushTreasury(address(token), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InsufficientTreasuryBalance.selector, uint256(19 ether), uint256(18.5 ether)
            )
        );
        revenue.flushTreasury(address(token), 19 ether);
    }

    function testDonationsOnlyBecomeTreasuryAndDoNotChangeGross() public {
        uint256 id = open(1, 0, 1);
        token.mint(diamond, 7 ether);
        assertEq(revenue.availableTokenSurplus(address(token)), 7 ether);
        assertEq(inspect.roundState(id).receipts, 1 ether);
        gov.setAssetApproved(address(token), false);
        gov.setPaused(true);
        assertEq(revenue.absorbTokenSurplus(address(token)), 7 ether);
        assertEq(revenue.availableTokenSurplus(address(token)), 0);
        assertEq(inspect.accounting(address(token)).treasuryAvailable, 7 ether);
        assertEq(inspect.roundState(id).receipts, 1 ether);
        assertBacked(address(token));
        vm.expectRevert(Errors.NoTokenSurplus.selector);
        revenue.absorbTokenSurplus(address(token));
        revenue.flushTreasury(address(token), 7 ether);
        assertBacked(address(token));
    }

    function testUnknownAssetRejectedBeforeBalanceCallAndLazyExpiryProtected() public {
        address trap = address(new BalanceTrap());
        vm.expectRevert(abi.encodeWithSelector(Errors.UnknownAsset.selector, trap));
        revenue.availableTokenSurplus(trap);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnknownAsset.selector, trap));
        revenue.absorbTokenSurplus(trap);
        uint256 id = fundedPrize();
        vm.warp(inspect.roundState(id).claimDeadline);
        assertEq(revenue.availableTokenSurplus(address(token)), 0);
        vm.expectRevert(Errors.NoTokenSurplus.selector);
        revenue.absorbTokenSurplus(address(token));
        claims.expirePrize(id);
        assertEq(revenue.availableTokenSurplus(address(token)), 0);
        assertBacked(address(token));
    }

    function testShortfallIsNeverSurplus() public {
        ConfiscatableToken other = new ConfiscatableToken();
        gov.setAssetApproved(address(other), true);
        other.mint(diamond, 10 ether);
        revenue.absorbTokenSurplus(address(other));
        other.confiscate(diamond, 1 ether);
        assertEq(revenue.availableTokenSurplus(address(other)), 0);
        vm.expectRevert(Errors.NoTokenSurplus.selector);
        revenue.absorbTokenSurplus(address(other));
        assertEq(inspect.accounting(address(other)).treasuryAvailable, 10 ether);
    }

    function testTreasuryTransferCannotReenterOtherValuePaths() public {
        fundedPrize();
        token.setCallback(diamond, abi.encodeCall(revenue.absorbTokenSurplus, (address(token))));
        revenue.flushTreasury(address(token), 1 ether);
        assertFalse(token.callbackSucceeded());
        assertEq(bytes4(token.callbackResult()), Errors.Reentrancy.selector);
        assertBacked(address(token));
    }
}
