// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { Guarded } from "../../src/shared/Guarded.sol";
import { LibRoomsSettlement } from "../../src/libraries/LibRoomsSettlement.sol";

contract SettlementComponents is Guarded {
    function acquire(uint256 id, bytes calldata sig)
        external
        nonReentrant
        returns (bytes32, uint8)
    {
        return LibRoomsSettlement.acquire(id, sig);
    }
}
