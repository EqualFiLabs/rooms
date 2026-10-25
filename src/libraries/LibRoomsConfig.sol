// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { RoomsConfig, IntegrationConfig } from "../shared/Types.sol";
import { Errors } from "../shared/Errors.sol";
import { LibRoomsStorage as S } from "./LibRoomsStorage.sol";

library LibRoomsConfig {
    function validateContract(address target) internal view {
        if (target == address(0) || target == address(this)) revert Errors.InvalidAddress();
        if (target.code.length == 0) revert Errors.NoCode(target);
    }

    function validate(RoomsConfig memory c) internal view {
        validateContract(c.paymentToken);
        if (!S.accountingStorage().assetApproved[c.paymentToken]) {
            revert Errors.AssetNotApproved(c.paymentToken);
        }
        if (
            c.baseTicketPrice == 0 || c.ticketSupply == 0 || c.salesDuration < 4 || c.roomCount < 2
                || c.roomCount > 24 || c.potBps == 0 || uint256(c.potBps) + c.operatorBps >= 10_000
                || c.settlementTipBps >= 10_000
        ) {
            revert Errors.InvalidConfig();
        }
    }

    function validate(IntegrationConfig memory c) internal view {
        validateContract(c.drandRegistry);
        validateContract(c.operatorFeeRouter);
    }
}
