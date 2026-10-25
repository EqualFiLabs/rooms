// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRevenue } from "../interfaces/IRevenue.sol";
import { IOperatorFeeRouter } from "../interfaces/IOperatorFeeRouter.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibOperatorFeeRouter } from "../libraries/LibOperatorFeeRouter.sol";
import { Errors } from "../shared/Errors.sol";
import { Guarded } from "../shared/Guarded.sol";

contract RevenueFacet is IRevenue, Guarded {
    using SafeERC20 for IERC20;
    event OperatorRevenueFlushed(
        uint64 indexed integrationVersion,
        address indexed asset,
        address indexed router,
        uint256 amount
    );

    function flushOperatorRevenue(uint64 version, address asset, uint256 amount)
        external
        nonReentrant
        returns (uint256)
    {
        if (amount == 0) revert Errors.ZeroAmount();
        if (version == 0 || version > S.integrationStorage().currentVersion) {
            revert Errors.IntegrationNotFound(version);
        }
        S.AccountingStorage storage a = S.accountingStorage();
        uint256 available = a.pendingOperatorRevenue[version][asset];
        if (amount > available) {
            revert Errors.InsufficientOperatorRevenue(version, amount, available);
        }
        address router = S.integrationStorage().integrations[version].operatorFeeRouter;
        LibOperatorFeeRouter.enforceReady(router, asset);
        a.pendingOperatorRevenue[version][asset] -= amount;
        a.assets[asset].pendingOperatorRevenueTotal -= amount;
        emit OperatorRevenueFlushed(version, asset, router, amount);
        IERC20(asset).forceApprove(router, amount);
        IOperatorFeeRouter(router).addRewards(asset, amount);
        IERC20(asset).forceApprove(router, 0);
        return amount;
    }
}
