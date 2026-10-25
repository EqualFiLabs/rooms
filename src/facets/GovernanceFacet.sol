// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { IGovernance } from "../interfaces/IGovernance.sol";
import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibRoomsStorage as S } from "../libraries/LibRoomsStorage.sol";
import { LibRoomsConfig } from "../libraries/LibRoomsConfig.sol";
import { RoomsConfig, IntegrationConfig } from "../shared/Types.sol";
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

    function setAssetApproved(address asset, bool approved) external onlyAuthority nonReentrant {
        LibRoomsConfig.validateContract(asset);
        S.AccountingStorage storage a = S.accountingStorage();
        a.assetApproved[asset] = approved;
        if (approved) a.knownAsset[asset] = true;
        emit AssetApprovalUpdated(asset, approved);
    }

    function setIntegrationConfig(IntegrationConfig calldata config)
        external
        onlyAuthority
        nonReentrant
    {
        LibRoomsConfig.validate(config);
        S.IntegrationStorage storage i = S.integrationStorage();
        uint64 v = ++i.currentVersion;
        i.integrations[v] = config;
        emit IntegrationConfigUpdated(v, config.drandRegistry, config.operatorFeeRouter);
    }

    function integrationConfig()
        external
        view
        returns (IntegrationConfig memory config, uint64 version)
    {
        S.IntegrationStorage storage i = S.integrationStorage();
        version = i.currentVersion;
        config = i.integrations[version];
    }

    function setMaxActiveRounds(uint16 limit) external onlyAuthority nonReentrant {
        S.GameStorage storage g = S.gameStorage();
        uint16 previous = g.maxActiveRounds;
        g.maxActiveRounds = limit;
        emit MaxActiveRoundsUpdated(previous, limit);
    }

    function setTreasuryRecipient(address recipient) external onlyAuthority nonReentrant {
        if (recipient == address(0) || recipient == address(this)) revert Errors.InvalidAddress();
        S.GovernanceStorage storage g = S.governanceStorage();
        address previous = g.treasuryRecipient;
        g.treasuryRecipient = recipient;
        emit TreasuryRecipientUpdated(previous, recipient);
    }

    function setGuardian(address guardian_) external onlyAuthority nonReentrant {
        address previous = S.governanceStorage().guardian;
        S.governanceStorage().guardian = guardian_;
        emit GuardianUpdated(previous, guardian_);
    }

    function setPaused(bool value) external nonReentrant {
        if (msg.sender != LibDiamond.authority()) {
            if (msg.sender != S.governanceStorage().guardian) {
                revert Errors.NotGuardian(msg.sender);
            }
            if (!value) revert Errors.UnpauseRequiresAuthority(msg.sender);
        }
        S.governanceStorage().paused = value;
        emit PauseStateUpdated(value);
    }

    function paused() external view returns (bool) {
        return S.governanceStorage().paused;
    }

    function guardian() external view returns (address) {
        return S.governanceStorage().guardian;
    }

    function treasuryRecipient() external view returns (address) {
        return S.governanceStorage().treasuryRecipient;
    }

    function protocolFinalized() external view returns (bool) {
        return LibDiamond.cutsDisabled();
    }

    function finalizeProtocol() external onlyAuthority nonReentrant {
        LibDiamond.disableCuts();
        emit ProtocolFinalized();
    }
}
