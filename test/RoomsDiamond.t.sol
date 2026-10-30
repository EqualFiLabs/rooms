// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {
    RoomsTest,
    InspectFacet,
    DiamondLoupeFacet,
    IDiamondCut,
    IDiamondLoupe,
    RoomsDiamond,
    DiamondCutFacet,
    FacetCut,
    FacetCutAction,
    Errors
} from "./helpers/RoomsTest.sol";

contract ValueFacet {
    function value() external pure virtual returns (uint256) {
        return 7;
    }

    function fail() external pure {
        revert("exact reason");
    }
}

contract NextValueFacet is ValueFacet {
    function value() external pure override returns (uint256) {
        return 9;
    }
}

contract RoomsDiamondTest is RoomsTest {
    function testDispatchReplaceRemoveAndStorage() public {
        install(address(new ValueFacet()), one(ValueFacet.value.selector));
        assertEq(ValueFacet(diamond).value(), 7);
        cut(address(new NextValueFacet()), FacetCutAction.Replace, one(ValueFacet.value.selector));
        assertEq(ValueFacet(diamond).value(), 9);
        (uint64 n,, uint16 cap,,) = inspect.state();
        assertEq(n, 1);
        assertEq(cap, 4);
        install(address(new DiamondLoupeFacet()), one(IDiamondLoupe.facetAddress.selector));
        assertTrue(IDiamondLoupe(diamond).facetAddress(ValueFacet.value.selector) != address(0));
        cut(address(0), FacetCutAction.Remove, one(ValueFacet.value.selector));
        assertEq(IDiamondLoupe(diamond).facetAddress(ValueFacet.value.selector), address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.FunctionNotFound.selector, ValueFacet.value.selector)
        );
        ValueFacet(diamond).value();
    }

    function testAuthorityCodeAndRevertPropagation() public {
        FacetCut[] memory c = new FacetCut[](0);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAuthority.selector, alice));
        IDiamondCut(diamond).diamondCut(c, address(0), "");
        vm.expectRevert(abi.encodeWithSelector(Errors.NoCode.selector, alice));
        install(alice, one(ValueFacet.value.selector));
        install(address(new ValueFacet()), one(ValueFacet.fail.selector));
        vm.expectRevert("exact reason");
        ValueFacet(diamond).fail();
    }

    function testFinalizationPreservesInstalledOperation() public {
        install(address(new ValueFacet()), one(ValueFacet.value.selector));
        inspect.freeze();
        vm.expectRevert(Errors.CutsDisabled.selector);
        IDiamondCut(diamond).diamondCut(new FacetCut[](0), address(0), "");
        assertEq(ValueFacet(diamond).value(), 7);
        vm.expectRevert(Errors.AlreadyFinalized.selector);
        inspect.freeze();
    }

    function testRejectNativeBothRoutes() public {
        vm.deal(address(this), 2 ether);
        (bool ok,) = diamond.call{ value: 1 ether }("");
        assertFalse(ok);
        (ok,) = diamond.call{ value: 1 ether }(hex"12345678");
        assertFalse(ok);
    }

    function testGuardRejectsCrossFacetReentryAndRestores() public {
        assertFalse(
            inspect.guardedCall(
                diamond, abi.encodeCall(InspectFacet.guardedCall, (alice, bytes("")))
            )
        );
        assertTrue(inspect.guardedCall(alice, ""));
    }
}
