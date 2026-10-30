// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { GovernanceTest } from "./helpers/GovernanceTest.sol";
import {
    RoomsConfig,
    TestToken,
    Errors,
    IntegrationConfig,
    MockRegistry,
    MockRouter,
    IDiamondCut,
    FacetCut
} from "./helpers/RoomsTest.sol";

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

    function testVersionedIntegrationsCapacityAndRecipients() public {
        (IntegrationConfig memory previous, uint64 v) = gov.integrationConfig();
        assertEq(v, 1);
        IntegrationConfig memory next =
            IntegrationConfig(address(new MockRegistry()), address(new MockRouter()));
        gov.setIntegrationConfig(next);
        (IntegrationConfig memory current, uint64 latest) = gov.integrationConfig();
        assertEq(latest, 2);
        assertEq(current.drandRegistry, next.drandRegistry);
        assertEq(previous.drandRegistry, address(registry));
        gov.setMaxActiveRounds(0);
        (,, uint16 cap,,) = inspect.state();
        assertEq(cap, 0);
        vm.expectRevert(Errors.InvalidAddress.selector);
        gov.setTreasuryRecipient(diamond);
        vm.expectRevert(Errors.InvalidAddress.selector);
        gov.setTreasuryRecipient(address(0));
        gov.setTreasuryRecipient(bob);
        assertEq(gov.treasuryRecipient(), bob);
        gov.setGuardian(alice);
        assertEq(gov.guardian(), alice);
    }

    function testPauseOnlyGuardianAndAuthorityUnpause() public {
        vm.prank(guardian);
        gov.setPaused(true);
        assertTrue(gov.paused());
        vm.prank(guardian);
        vm.expectRevert(abi.encodeWithSelector(Errors.UnpauseRequiresAuthority.selector, guardian));
        gov.setPaused(false);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotGuardian.selector, alice));
        gov.setPaused(true);
        gov.setPaused(false);
        assertFalse(gov.paused());
        gov.setGuardian(address(0));
        assertEq(gov.guardian(), address(0));
    }

    function testFinalizationKeepsOperationalGovernance() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAuthority.selector, alice));
        gov.finalizeProtocol();
        gov.finalizeProtocol();
        assertTrue(gov.protocolFinalized());
        vm.expectRevert(Errors.CutsDisabled.selector);
        IDiamondCut(diamond).diamondCut(new FacetCut[](0), address(0), "");
        gov.setMaxActiveRounds(2);
        gov.setRoomsConfigEnabled(1, false);
        gov.setPaused(true);
        gov.setPaused(false);
        gov.createRoomsConfig(fixture());
        vm.expectRevert(Errors.AlreadyFinalized.selector);
        gov.finalizeProtocol();
    }
}
