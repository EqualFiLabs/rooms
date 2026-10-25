// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RevenueTest } from "./helpers/RevenueTest.sol";
import { IntegrationConfig, MockRegistry, MockRouter, Errors } from "./helpers/RoomsTest.sol";

contract RoomsOperatorRevenueTest is RevenueTest {
    function testPartialDeliveryUsesHistoricalRouterAndClearsAllowance() public {
        fundedPrize();
        MockRouter next = new MockRouter();
        gov.setIntegrationConfig(IntegrationConfig(address(new MockRegistry()), address(next)));
        gov.setPaused(true);
        gov.setAssetApproved(address(token), false);
        assertEq(revenue.flushOperatorRevenue(1, address(token), 7 ether), 7 ether);
        assertEq(inspect.bucket(1, address(token)), 13 ether);
        assertEq(router.totalAdded(), 7 ether);
        assertEq(router.lastAllowance(), 7 ether);
        assertEq(next.totalAdded(), 0);
        assertEq(token.allowance(diamond, address(router)), 0);
        assertBacked(address(token));
        revenue.flushOperatorRevenue(1, address(token), 13 ether);
        assertEq(inspect.bucket(1, address(token)), 0);
        assertBacked(address(token));
    }

    function testReadinessAndTokenFailurePreserveRetryAndAllowance() public {
        fundedPrize();
        router.setReady(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.OperatorRouterUnavailable.selector, address(router), address(token)
            )
        );
        revenue.flushOperatorRevenue(1, address(token), 20 ether);
        assertEq(inspect.bucket(1, address(token)), 20 ether);
        router.setReady(true);
        token.setFail(true);
        vm.expectRevert("transfer disabled");
        revenue.flushOperatorRevenue(1, address(token), 20 ether);
        assertEq(inspect.bucket(1, address(token)), 20 ether);
        assertEq(token.allowance(diamond, address(router)), 0);
        token.setFail(false);
        revenue.flushOperatorRevenue(1, address(token), 20 ether);
        assertBacked(address(token));
    }

    function testBoundsAndCrossFacetReentry() public {
        fundedPrize();
        vm.expectRevert(Errors.ZeroAmount.selector);
        revenue.flushOperatorRevenue(1, address(token), 0);
        vm.expectRevert(abi.encodeWithSelector(Errors.IntegrationNotFound.selector, uint64(2)));
        revenue.flushOperatorRevenue(2, address(token), 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InsufficientOperatorRevenue.selector,
                uint64(1),
                uint256(21 ether),
                uint256(20 ether)
            )
        );
        revenue.flushOperatorRevenue(1, address(token), 21 ether);
        token.setCallback(
            diamond,
            abi.encodeCall(revenue.flushOperatorRevenue, (uint64(1), address(token), uint256(1)))
        );
        revenue.flushOperatorRevenue(1, address(token), 20 ether);
        assertFalse(token.callbackSucceeded());
        assertEq(bytes4(token.callbackResult()), Errors.Reentrancy.selector);
        assertEq(token.allowance(diamond, address(router)), 0);
        assertBacked(address(token));
    }
}
