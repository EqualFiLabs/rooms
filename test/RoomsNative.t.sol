// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { RevenueTest } from "./helpers/RevenueTest.sol";
import { Errors } from "./helpers/RoomsTest.sol";

contract ForcedNative {
    constructor(address payable target) payable {
        selfdestruct(target);
    }
}

contract NativeReceiver {
    bool public reject = true;
    address public target;
    bytes public data;
    bool public reentered;
    bytes public reason;

    function configure(bool fail, address t, bytes calldata d) external {
        reject = fail;
        target = t;
        data = d;
    }

    receive() external payable {
        require(!reject, "receiver rejected");
        if (target != address(0)) (reentered, reason) = target.call(data);
    }
}

contract RoomsNativeTest is RevenueTest {
    function testForcedNativeGoesOnlyToCurrentTreasury() public {
        vm.deal(address(this), 3 ether);
        new ForcedNative{ value: 2 ether }(payable(diamond));
        uint256 before = treasury.balance;
        assertEq(revenue.flushNativeSurplus(), 2 ether);
        assertEq(treasury.balance, before + 2 ether);
        assertEq(diamond.balance, 0);
        vm.expectRevert(Errors.NoNativeSurplus.selector);
        revenue.flushNativeSurplus();
        (bool ok,) = diamond.call{ value: 1 ether }("");
        assertFalse(ok);
        (ok,) = diamond.call{ value: 1 ether }(abi.encodeCall(revenue.flushNativeSurplus, ()));
        assertFalse(ok);
    }

    function testNativeReceiverFailureRetryAndSharedGuard() public {
        NativeReceiver receiver = new NativeReceiver();
        gov.setTreasuryRecipient(address(receiver));
        vm.deal(address(this), 1 ether);
        new ForcedNative{ value: 1 ether }(payable(diamond));
        vm.expectRevert(Errors.NativeTransferFailed.selector);
        revenue.flushNativeSurplus();
        assertEq(diamond.balance, 1 ether);
        receiver.configure(false, diamond, abi.encodeCall(revenue.flushNativeSurplus, ()));
        gov.setPaused(true);
        revenue.flushNativeSurplus();
        assertFalse(receiver.reentered());
        assertEq(bytes4(receiver.reason()), Errors.Reentrancy.selector);
        assertEq(address(receiver).balance, 1 ether);
        assertEq(diamond.balance, 0);
    }
}
