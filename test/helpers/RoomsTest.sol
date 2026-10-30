// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { Test } from "forge-std/Test.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { RoomsDiamond } from "../../src/RoomsDiamond.sol";
import { DiamondCutFacet } from "../../src/facets/DiamondCutFacet.sol";
import { DiamondLoupeFacet } from "../../src/facets/DiamondLoupeFacet.sol";
import { IDiamondCut } from "../../src/interfaces/IDiamondCut.sol";
import { IDiamondLoupe } from "../../src/interfaces/IDiamondLoupe.sol";
import { RoomsInit } from "../../src/initializers/RoomsInit.sol";
import { LibRoomsStorage as S } from "../../src/libraries/LibRoomsStorage.sol";
import { LibDiamond } from "../../src/libraries/LibDiamond.sol";
import { Guarded } from "../../src/shared/Guarded.sol";
import { Errors } from "../../src/shared/Errors.sol";
import { FacetCut, FacetCutAction } from "../../src/shared/DiamondTypes.sol";
import { RoomsConfig, IntegrationConfig, Round, AssetAccounting } from "../../src/shared/Types.sol";

contract TestToken is ERC20 {
    bool public fail;
    address public callback;
    bytes public callbackData;
    bool public callbackSucceeded;
    bytes public callbackResult;
    constructor() ERC20("Test asset", "TEST") { }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setFail(bool value) external {
        fail = value;
    }

    function setCallback(address target, bytes calldata data) external {
        callback = target;
        callbackData = data;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(!fail, "transfer disabled");
        if (callback != address(0) && from != address(0)) {
            (callbackSucceeded, callbackResult) = callback.call(callbackData);
        }
        super._update(from, to, amount);
    }
}

contract MockRegistry {
    bool public stale;
    bool public badTime;
    bool public rejectProof;
    mapping(uint64 => bool) public hasSig;
    mapping(uint64 => uint64) public postedAt;
    mapping(uint64 => bytes32) public randomnessOf;

    function firstRoundAfter(uint256 t) external view returns (uint64) {
        return stale ? 0 : uint64(t / 3 + 1);
    }

    function roundTime(uint64 r) external view returns (uint64) {
        return badTime ? 0 : r * 3;
    }

    function setBad(bool a, bool b, bool c) external {
        stale = a;
        badTime = b;
        rejectProof = c;
    }

    function cache(uint64 r, bytes32 randomness) public {
        require(!hasSig[r], "already cached");
        hasSig[r] = true;
        postedAt[r] = uint64(block.timestamp);
        randomnessOf[r] = randomness;
    }

    function postSig(uint64 r, bytes calldata sig) external returns (bool) {
        require(!rejectProof && sig.length != 0, "bad proof");
        cache(r, keccak256(sig));
        return true;
    }
}

contract MockRouter {
    bool public ready = true;
    uint256 public totalAdded;

    function setReady(bool value) external {
        ready = value;
    }

    function bootstrapFinalized() external view returns (bool) {
        return ready;
    }

    function totalEffectiveWeight() external view returns (uint256) {
        return ready ? 1 : 0;
    }

    function isRewardAsset(address) external view returns (bool) {
        return ready;
    }

    function rewardAssetEnabled(address) external view returns (bool) {
        return ready;
    }

    function addRewards(address asset, uint256 amount) external {
        require(ready, "not ready");
        require(IERC20(asset).transferFrom(msg.sender, address(this), amount));
        totalAdded += amount;
    }
}

/// @dev Test-only observation of namespaced ledgers; never installed in release assemblies.
contract InspectFacet is Guarded {
    function state()
        external
        view
        returns (uint64 configs, uint256 active, uint16 cap, address guardian, address treasury)
    {
        S.GameStorage storage g = S.gameStorage();
        return (
            g.nextConfigVersion,
            g.activeRoundCount,
            g.maxActiveRounds,
            S.governanceStorage().guardian,
            S.governanceStorage().treasuryRecipient
        );
    }

    function config(uint64 v) external view returns (RoomsConfig memory, bool) {
        return (S.gameStorage().configs[v], S.gameStorage().configEnabled[v]);
    }

    function roundState(uint256 id) external view returns (Round memory) {
        return S.gameStorage().rounds[id];
    }

    function accounting(address a) external view returns (AssetAccounting memory) {
        return S.accountingStorage().assets[a];
    }

    function tickets(uint256 id, uint8 room, address user)
        external
        view
        returns (uint256, uint256)
    {
        return (
            S.gameStorage().roomTickets[id][room], S.gameStorage().userRoomTickets[id][room][user]
        );
    }

    function flags(address asset) external view returns (bool, bool) {
        return (S.accountingStorage().knownAsset[asset], S.accountingStorage().assetApproved[asset]);
    }

    function rollover(uint64 v) external view returns (uint256) {
        return S.gameStorage().pendingRollover[v];
    }

    function credit(address a, address user) external view returns (uint256) {
        return S.accountingStorage().finalizerCredits[a][user];
    }

    function bucket(uint64 v, address a) external view returns (uint256) {
        return S.accountingStorage().pendingOperatorRevenue[v][a];
    }

    function activeFor(uint64 v) external view returns (uint256) {
        return S.gameStorage().activeRoundForConfig[v];
    }

    function guardedCall(address target, bytes calldata data)
        external
        nonReentrant
        returns (bool ok)
    {
        (ok,) = target.call(data);
    }

    function freeze() external {
        LibDiamond.enforceAuthority();
        LibDiamond.disableCuts();
    }
}

abstract contract RoomsTest is Test {
    address internal diamond;
    TestToken internal token;
    MockRegistry internal registry;
    MockRouter internal router;
    InspectFacet internal inspect;
    address internal guardian = address(0xB0B);
    address internal treasury = address(0xCAFE);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xBEEF);

    function setUp() public virtual {
        vm.warp(1_000_000);
        token = new TestToken();
        registry = new MockRegistry();
        router = new MockRouter();
        diamond = address(new RoomsDiamond(address(this), address(new DiamondCutFacet())));
        installInspection();
        RoomsInit.InitParams memory p = initParams();
        IDiamondCut(diamond)
            .diamondCut(
                new FacetCut[](0),
                address(new RoomsInit()),
                abi.encodeCall(RoomsInit.initialize, (p))
            );
        token.mint(alice, 1e30);
        token.mint(bob, 1e30);
        vm.prank(alice);
        token.approve(diamond, type(uint256).max);
        vm.prank(bob);
        token.approve(diamond, type(uint256).max);
    }

    function fixture() internal view returns (RoomsConfig memory) {
        return RoomsConfig(address(token), 1 ether, 100, 400, 30, 0, 5000, 2000, 500, 2);
    }

    function initParams() internal view returns (RoomsInit.InitParams memory p) {
        p.authority = address(this);
        p.guardian = guardian;
        p.treasuryRecipient = treasury;
        p.maxActiveRounds = 4;
        p.integration = IntegrationConfig(address(registry), address(router));
        p.approvedAssets = new address[](1);
        p.approvedAssets[0] = address(token);
        p.roomsConfigs = new RoomsConfig[](1);
        p.roomsConfigs[0] = fixture();
    }

    function install(address facet, bytes4[] memory selectors) internal {
        cut(facet, FacetCutAction.Add, selectors);
    }

    function cut(address facet, FacetCutAction action, bytes4[] memory selectors) internal {
        FacetCut[] memory c = new FacetCut[](1);
        c[0] = FacetCut(facet, action, selectors);
        IDiamondCut(diamond).diamondCut(c, address(0), "");
    }

    function one(bytes4 selector) internal pure returns (bytes4[] memory a) {
        a = new bytes4[](1);
        a[0] = selector;
    }

    function installInspection() internal {
        bytes4[] memory s = new bytes4[](12);
        s[0] = InspectFacet.state.selector;
        s[1] = InspectFacet.config.selector;
        s[2] = InspectFacet.roundState.selector;
        s[3] = InspectFacet.accounting.selector;
        s[4] = InspectFacet.tickets.selector;
        s[5] = InspectFacet.flags.selector;
        s[6] = InspectFacet.rollover.selector;
        s[7] = InspectFacet.credit.selector;
        s[8] = InspectFacet.bucket.selector;
        s[9] = InspectFacet.activeFor.selector;
        s[10] = InspectFacet.guardedCall.selector;
        s[11] = InspectFacet.freeze.selector;
        install(address(new InspectFacet()), s);
        inspect = InspectFacet(diamond);
    }
}
