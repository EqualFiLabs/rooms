// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IOperatorFeeRouter } from "../interfaces/IOperatorFeeRouter.sol";
import { Errors } from "../shared/Errors.sol";

library LibOperatorFeeRouter {
    function enforceReady(address router, address asset) internal view {
        IOperatorFeeRouter r = IOperatorFeeRouter(router);
        if (
            !r.bootstrapFinalized() || r.totalEffectiveWeight() == 0 || !r.isRewardAsset(asset)
                || !r.rewardAssetEnabled(asset)
        ) revert Errors.OperatorRouterUnavailable(router, asset);
    }
}
