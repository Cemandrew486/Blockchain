
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IConsentManager {
    function hasValidConsent(address patient, address requester, uint8 dataType) external view returns (bool);
}

interface IDataRegistry {
    function getLatestDataPointer(address patient, uint8 dataType) external view returns (bytes32, uint256, uint32);
}

contract AccessController {

    IConsentManager public consentManager;
    IDataRegistry public dataRegistry;

    event AccessLogged(
        address indexed requester, 
        address indexed patient, 
        uint8 dataType, 
        bool success,
        uint256 timestamp
    );

    event AccessDenied(
        address indexed requester,
        address indexed patient,
        uint8 dataType,
        string reason
    );

    constructor(address _consentManager, address _dataRegistry) {
        require(_consentManager != address(0), "Invalid ConsentManager address");
        require(_dataRegistry != address(0), "Invalid DataRegistry address");
        
        consentManager = IConsentManager(_consentManager);
        dataRegistry = IDataRegistry(_dataRegistry);
    }

    /**
     * @dev Access patient data if consent is valid
     * @param patient Address of the patient whose data is being accessed
     * @param dataType Type of medical data (1=LAB_RESULTS, 2=IMAGING, 3=FULL_RECORD)
     * @return dataHash The hash pointer to the encrypted off-chain data
     * @return timestamp When this data was registered
     * @return version Version number of the data
     */
    function accessData(
        address patient, 
        uint8 dataType
    ) external returns (bytes32 dataHash, uint256 timestamp, uint32 version) {
        require(patient != address(0), "Invalid patient address");
        require(dataType >= 1 && dataType <= 3, "Invalid dataType");

        // Check if requester has valid consent
        bool hasConsent = consentManager.hasValidConsent(patient, msg.sender, dataType);

        if (!hasConsent) {
            emit AccessLogged(msg.sender, patient, dataType, false, block.timestamp);
            emit AccessDenied(msg.sender, patient, dataType, "No valid consent");
            return (bytes32(0), 0, 0);
        }

        try dataRegistry.getLatestDataPointer(patient, dataType) returns (
            bytes32 _dataHash,
            uint256 _timestamp,
            uint32 _version
        ) {
            emit AccessLogged(msg.sender, patient, dataType, true, block.timestamp);
            return (_dataHash, _timestamp, _version);
        } catch Error(string memory reason) {
            emit AccessLogged(msg.sender, patient, dataType, false, block.timestamp);
            emit AccessDenied(msg.sender, patient, dataType, reason);
            return (bytes32(0), 0, 0);
        } catch {
            emit AccessLogged(msg.sender, patient, dataType, false, block.timestamp);
            emit AccessDenied(msg.sender, patient, dataType, "Data retrieval failed");
            return (bytes32(0), 0, 0);
        }
    }

    /**
     * @dev View function to check if access would be granted (doesn't log)
     * @param patient Address of the patient
     * @param requester Address of the requester
     * @param dataType Type of medical data
     * @return True if access would be granted
     */
    function checkAccessPermission(
        address patient,
        address requester,
        uint8 dataType
    ) external view returns (bool) {
        return consentManager.hasValidConsent(patient, requester, dataType);
    }

    function getDataRegistryAddress() external view returns (address) {
        return address(dataRegistry);
    }

    function getConsentManagerAddress() external view returns (address) {
        return address(consentManager);
    }
}
