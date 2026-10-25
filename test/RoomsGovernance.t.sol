// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { GovernanceTest } from "./helpers/GovernanceTest.sol";
import { RoomsConfig, TestToken, Errors } from "./helpers/RoomsTest.sol";

contract RoomsGovernanceTest is GovernanceTest {
    function testRemovalPreservesKnownAssetAndOldConfiguration() public {
        gov.setAssetApproved(address(token), false);
        (bool known, bool approved) = inspect.flags(address(token));
        assertTrue(known);
        assertFalse(approved);
        (RoomsConfig memory c, bool enabled) = inspect.config(1);
        assertTrue(enabled);
        assertEq(c.paymentToken, address(token));
        vm.expectRevert(abi.encodeWithSelector(Errors.AssetNotApproved.selector, address(token)));
        gov.createRoomsConfig(c);
        gov.setAssetApproved(address(token), true);
        gov.createRoomsConfig(c);
    }

    function testAdmissionRequiresCanonicalContractAndAuthority() public {
        vm.expectRevert(Errors.InvalidAddress.selector);
        gov.setAssetApproved(address(0), true);
        vm.expectRevert(Errors.InvalidAddress.selector);
        gov.setAssetApproved(diamond, true);
        vm.expectRevert(abi.encodeWithSelector(Errors.NoCode.selector, alice));
        gov.setAssetApproved(alice, true);
        TestToken other = new TestToken();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAuthority.selector, alice));
        gov.setAssetApproved(address(other), true);
        gov.setAssetApproved(address(other), false);
        (bool known,) = inspect.flags(address(other));
        assertFalse(known);
        gov.setAssetApproved(address(other), true);
        (known,) = inspect.flags(address(other));
        assertTrue(known);
        gov.setAssetApproved(address(other), false);
        (known,) = inspect.flags(address(other));
        assertTrue(known);
    }
}
