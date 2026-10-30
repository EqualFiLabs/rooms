// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import {
    RoomsTest,
    RoomsInit,
    RoomsDiamond,
    DiamondCutFacet,
    IDiamondCut,
    FacetCut,
    FacetCutAction,
    Errors
} from "./helpers/RoomsTest.sol";

contract RoomsInitTest is RoomsTest {
    function testInitialStateAndReplay() public {
        (uint64 n, uint256 active, uint16 cap, address g, address t) = inspect.state();
        assertEq(n, 1);
        assertEq(active, 0);
        assertEq(cap, 4);
        assertEq(g, guardian);
        assertEq(t, treasury);
        (bool known, bool approved) = inspect.flags(address(token));
        assertTrue(known && approved);
        (, bool enabled) = inspect.config(1);
        assertTrue(enabled);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InitializationFailed.selector,
                abi.encodeWithSelector(Errors.AlreadyInitialized.selector)
            )
        );
        IDiamondCut(diamond)
            .diamondCut(
                new FacetCut[](0),
                address(new RoomsInit()),
                abi.encodeCall(RoomsInit.initialize, (initParams()))
            );
    }

    function testInvalidInitializationRollsBackEntireCut() public {
        address fresh = address(new RoomsDiamond(address(this), address(new DiamondCutFacet())));
        RoomsInit.InitParams memory p = initParams();
        p.roomsConfigs[0].roomCount = 1;
        FacetCut[] memory c = new FacetCut[](1);
        c[0] = FacetCut(
            address(new RoomsInit()), FacetCutAction.Add, one(RoomsInit.initialize.selector)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InitializationFailed.selector,
                abi.encodeWithSelector(Errors.InvalidConfig.selector)
            )
        );
        IDiamondCut(fresh)
            .diamondCut(c, address(new RoomsInit()), abi.encodeCall(RoomsInit.initialize, (p)));
        vm.expectRevert(
            abi.encodeWithSelector(Errors.FunctionNotFound.selector, RoomsInit.initialize.selector)
        );
        RoomsInit(fresh).initialize(p);
        p.roomsConfigs[0] = fixture();
        IDiamondCut(fresh)
            .diamondCut(c, address(new RoomsInit()), abi.encodeCall(RoomsInit.initialize, (p)));
    }

    function testRedundantPurchaseCeilingIsValid() public {
        address fresh = address(new RoomsDiamond(address(this), address(new DiamondCutFacet())));
        RoomsInit.InitParams memory p = initParams();
        p.roomsConfigs[0].maxTicketsPerPurchase = 200;
        IDiamondCut(fresh)
            .diamondCut(
                new FacetCut[](0),
                address(new RoomsInit()),
                abi.encodeCall(RoomsInit.initialize, (p))
            );
    }

    function testAuthorityMismatchAndDirectInitializerRejected() public {
        RoomsInit init = new RoomsInit();
        RoomsInit.InitParams memory p = initParams();
        vm.expectRevert(abi.encodeWithSelector(Errors.NotAuthority.selector, address(this)));
        init.initialize(p);
        p.authority = alice;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.InitializationFailed.selector,
                abi.encodeWithSelector(Errors.AuthorityMismatch.selector, address(this), alice)
            )
        );
        IDiamondCut(diamond)
            .diamondCut(new FacetCut[](0), address(init), abi.encodeCall(RoomsInit.initialize, (p)));
    }
}
