// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";
import { AssetAccounting } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";

library LibRoomsAccounting {
    function total(AssetAccounting memory a) internal pure returns (uint256) {
        return a.activeRoundEscrow + a.prizeLiability + a.pendingRolloverTotal
            + a.finalizerLiability + a.pendingOperatorRevenueTotal + a.treasuryAvailable;
    }

    function balanceAndAccounted(address asset)
        internal
        view
        returns (uint256 balance, uint256 accounted)
    {
        if (!S.accountingStorage().knownAsset[asset]) revert Errors.UnknownAsset(asset);
        accounted = total(S.accountingStorage().assets[asset]);
        balance = IERC20(asset).balanceOf(address(this));
    }

    function surplus(address asset) internal view returns (uint256) {
        (uint256 balance, uint256 accounted) = balanceAndAccounted(asset);
        return balance > accounted ? balance - accounted : 0;
    }
}
