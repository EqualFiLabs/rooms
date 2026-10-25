// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

interface IClaims {
    function claimPrize(uint256 roundId, address receiver) external returns (uint256 amount);
    function expirePrize(uint256 roundId) external returns (uint256 amount);
    function claimFinalizerTips(address asset, address receiver) external returns (uint256 amount);
}
