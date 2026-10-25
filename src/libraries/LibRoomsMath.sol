// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

library LibRoomsMath {
    function epoch(uint256 elapsed, uint32 duration) internal pure returns (uint8) {
        return uint8(Math.mulDiv(elapsed, 4, duration));
    }

    function multiplier(uint8 e) internal pure returns (uint16) {
        return 10_000 + uint16(e) * 2500;
    }

    function unitPrice(uint96 base, uint8 e) internal pure returns (uint256) {
        return Math.mulDiv(base, multiplier(e), 10_000, Math.Rounding.Ceil);
    }
}
