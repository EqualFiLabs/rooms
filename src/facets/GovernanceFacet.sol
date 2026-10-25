// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { IGovernance } from "../interfaces/IGovernance.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibRoomsConfig } from "../libraries/LibRoomsConfig.sol";
import { RoomsConfig } from "../shared/Types.sol";
import { Guarded } from "../shared/Guarded.sol";
import { Errors } from "../shared/Errors.sol";

contract GovernanceFacet is IGovernance, Guarded {
    modifier onlyAuthority() {
        LibDiamond.enforceAuthority();
        _;
    }

    function createRoomsConfig(RoomsConfig calldata config)
        external
        onlyAuthority
        nonReentrant
        returns (uint64 version)
    {
        LibRoomsConfig.validate(config);
        S.GameStorage storage g = S.gameStorage();
        version = ++g.nextConfigVersion;
        g.configs[version] = config;
        emit RoomsConfigCreated(version, config.paymentToken, config);
    }

    function setRoomsConfigEnabled(uint64 version, bool enabled)
        external
        onlyAuthority
        nonReentrant
    {
        S.GameStorage storage g = S.gameStorage();
        if (version == 0 || version > g.nextConfigVersion) revert Errors.ConfigNotFound(version);
        g.configEnabled[version] = enabled;
        emit RoomsConfigEnabled(version, enabled);
    }
}
