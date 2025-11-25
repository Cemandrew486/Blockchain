// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IConsentManager {
    function hasValidConsent(address patient, address requester, uint8 dataType, uint8 purpose) external view returns (bool);
}

interface IDataRegistry {
    function getLatestDataPointer(address patient, uint8 dataType) external view returns (bytes32, uint256);
}

contract AccessController {

    IConsentManager consentManager;
    IDataRegistry dataRegistry;

    event AccessLogged(address requester, address patient, uint8 dataType, bool success);

    constructor(address _consentManager, address _dataRegistry) {
        consentManager = IConsentManager(_consentManager);
        dataRegistry = IDataRegistry(_dataRegistry);
    }

    function accessData(address patient, uint8 dataType, uint8 purpose) external returns (bytes32) {
        bool valid = consentManager.hasValidConsent(patient, msg.sender, dataType, purpose);

        if (!valid) {
            emit AccessLogged(msg.sender, patient, dataType, false);
            return bytes32(0);
        }

        (bytes32 pointerHash, ) = dataRegistry.getLatestDataPointer(patient, dataType);
        emit AccessLogged(msg.sender, patient, dataType, true);
        return pointerHash;
    }
}
