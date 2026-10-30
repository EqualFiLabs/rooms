// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RoomsTest } from "./helpers/RoomsTest.sol";
import { DeployRooms } from "../script/DeployRooms.s.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { RoomsInit } from "../src/initializers/RoomsInit.sol";
import { IRooms } from "../src/interfaces/IRooms.sol";
import { IDiamondCut } from "../src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../src/interfaces/IDiamondLoupe.sol";
import { IRoomsView } from "../src/interfaces/IRoomsView.sol";
import { GovernanceFacet } from "../src/facets/GovernanceFacet.sol";
import { FacetCut, FacetCutAction } from "../src/shared/DiamondTypes.sol";

contract RoomsAssemblyTest is RoomsTest {
    function testExternalTimelockAtomicActivationAndContinuingGovernance() public {
        vm.chainId(46_630);
        address[] memory actors = new address[](1);
        actors[0] = address(this);
        TimelockController authority = new TimelockController(2 days, actors, actors, address(0));
        RoomsInit.InitParams memory p = initParams();
        p.authority = address(authority);
        DeployRooms assemblyTool = new DeployRooms();
        DeployRooms.Assembly memory a = assemblyTool.prepare(p, 2 days);
        vm.expectRevert();
        IDiamondCut(a.diamond).diamondCut(new FacetCut[](0), address(0), "");
        vm.expectRevert();
        IRoomsView(a.diamond).activeRoundCount();
        bytes32 salt = keccak256("local activation");
        authority.schedule(a.diamond, 0, a.activationCalldata, bytes32(0), salt, 2 days);
        vm.expectRevert();
        authority.execute(a.diamond, 0, a.activationCalldata, bytes32(0), salt);
        vm.warp(block.timestamp + 2 days);
        authority.execute(a.diamond, 0, a.activationCalldata, bytes32(0), salt);
        FacetCut[] memory cuts = assemblyTool.applicationCuts(a.facets);
        assertTrue(matchesArtifacts(cuts, a.facets));
        uint256 count;
        for (uint256 i; i < cuts.length; ++i) {
            bytes4[] memory expected = artifactSelectors(facetNames()[i]);
            bytes4[] memory installed = IDiamondLoupe(a.diamond).facetFunctionSelectors(a.facets[i]);
            assertEq(installed.length, expected.length);
            for (uint256 j; j < expected.length; ++j) {
                assertEq(IDiamondLoupe(a.diamond).facetAddress(expected[j]), a.facets[i]);
                ++count;
            }
        }
        assertEq(count, 50);
        assertEq(IDiamondLoupe(a.diamond).facetAddresses().length, 8);
        address cutFacet = IDiamondLoupe(a.diamond).facetAddress(IDiamondCut.diamondCut.selector);
        bytes4[] memory constructorSelectors = artifactSelectors("DiamondCutFacet");
        assertEq(constructorSelectors.length, 1);
        assertEq(constructorSelectors[0], IDiamondCut.diamondCut.selector);
        assertEq(IDiamondLoupe(a.diamond).facetFunctionSelectors(cutFacet).length, 1);
        for (uint256 i; i < a.facets.length; ++i) {
            assertTrue(cutFacet != a.facets[i]);
        }
        // A same-count substitution must fail even if no lifecycle call exercises that view.
        cuts[6].functionSelectors[0] = bytes4(0xdeadbeef);
        assertFalse(matchesArtifacts(cuts, a.facets));
        cuts = assemblyTool.applicationCuts(a.facets);
        cuts[6].facetAddress = a.facets[0];
        assertFalse(matchesArtifacts(cuts, a.facets));
        assertEq(IRoomsView(a.diamond).maxActiveRounds(), 4);
        vm.prank(alice);
        token.approve(a.diamond, type(uint256).max);
        vm.prank(alice);
        assertEq(IRooms(a.diamond).openRound(1, 0, 1, 1 ether), 1);
        bytes memory finalize = abi.encodeCall(GovernanceFacet.finalizeProtocol, ());
        authority.schedule(a.diamond, 0, finalize, bytes32(0), salt, 2 days);
        vm.warp(block.timestamp + 2 days);
        authority.execute(a.diamond, 0, finalize, bytes32(0), salt);
        assertTrue(GovernanceFacet(a.diamond).protocolFinalized());
        bytes memory pause = abi.encodeCall(GovernanceFacet.setPaused, (true));
        authority.schedule(a.diamond, 0, pause, bytes32(0), salt, 2 days);
        vm.warp(block.timestamp + 2 days);
        authority.execute(a.diamond, 0, pause, bytes32(0), salt);
        assertTrue(GovernanceFacet(a.diamond).paused());
        vm.expectRevert();
        authority.schedule(a.diamond, 0, pause, bytes32(0), salt, 0);
    }

    function facetNames() internal pure returns (string[7] memory) {
        return [
            "DiamondLoupeFacet",
            "GovernanceFacet",
            "RoomsFacet",
            "SettlementFacet",
            "ClaimsFacet",
            "RevenueFacet",
            "RoomsViewFacet"
        ];
    }

    function artifactSelectors(string memory name)
        internal
        view
        returns (bytes4[] memory selectors)
    {
        string memory artifact = vm.readFile(string.concat("out/", name, ".sol/", name, ".json"));
        string[] memory signatures = vm.parseJsonKeys(artifact, ".methodIdentifiers");
        selectors = new bytes4[](signatures.length);
        for (uint256 i; i < signatures.length; ++i) {
            selectors[i] = bytes4(keccak256(bytes(signatures[i])));
        }
    }

    function matchesArtifacts(FacetCut[] memory cuts, address[7] memory facets)
        internal
        view
        returns (bool)
    {
        if (cuts.length != facets.length) return false;
        string[7] memory names = facetNames();
        for (uint256 i; i < facets.length; ++i) {
            if (cuts[i].facetAddress != facets[i] || cuts[i].action != FacetCutAction.Add) {
                return false;
            }
            bytes4[] memory expected = artifactSelectors(names[i]);
            if (cuts[i].functionSelectors.length != expected.length) return false;
            for (uint256 j; j < expected.length; ++j) {
                uint256 matches;
                for (uint256 k; k < expected.length; ++k) {
                    if (cuts[i].functionSelectors[k] == expected[j]) ++matches;
                }
                if (matches != 1) return false;
            }
        }
        return true;
    }

    function testPreparationRejectsWrongChainDelayAndInitialSplit() public {
        DeployRooms assemblyTool = new DeployRooms();
        RoomsInit.InitParams memory p = initParams();
        vm.expectRevert();
        assemblyTool.prepare(p, 1);
        vm.chainId(46_630);
        address[] memory actors = new address[](1);
        actors[0] = address(this);
        p.authority = address(new TimelockController(2, actors, actors, address(0)));
        vm.expectRevert();
        assemblyTool.prepare(p, 1);
        p.roomsConfigs[0].potBps = 4000;
        vm.expectRevert();
        assemblyTool.prepare(p, 2);
    }
}
