// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { RoomsConfig, Allocations } from "../shared/Types.sol";

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

    function allocate(uint256 gross, RoomsConfig memory c)
        internal
        pure
        returns (Allocations memory a)
    {
        a.pot = Math.mulDiv(gross, c.potBps, 10_000);
        a.operatorRevenue = Math.mulDiv(gross, c.operatorBps, 10_000);
        a.treasuryGross = gross - a.pot - a.operatorRevenue;
        a.finalizerTip = Math.mulDiv(a.treasuryGross, c.settlementTipBps, 10_000);
        a.treasuryNet = a.treasuryGross - a.finalizerTip;
    }

    function perTicket(uint256 pot, uint256 tickets)
        internal
        pure
        returns (uint256 unit, uint256 distributable, uint256 dust)
    {
        if (tickets == 0) return (0, 0, pot);
        unit = pot / tickets;
        distributable = unit * tickets;
        dust = pot - distributable;
    }
}
