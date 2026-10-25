// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

interface IRevenue {
    function flushOperatorRevenue(uint64 integrationVersion, address asset, uint256 amount)
        external
        returns (uint256 flushed);
    function flushTreasury(address asset, uint256 amount) external returns (uint256 flushed);
    function availableTokenSurplus(address asset) external view returns (uint256 amount);
    function absorbTokenSurplus(address asset) external returns (uint256 amount);
}
