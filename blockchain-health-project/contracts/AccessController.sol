// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IConsentManager {
    // added data version so it matches consentManager now
    function hasValidConsent(
        address patient,
        address requester,
        uint8 dataType,
        uint32 dataVersion
    ) external view returns (bool);
}

interface IDataRegistry {
    // For easiness we keep this
    function getLatestDataPointer(
        address patient,
        uint8 dataType
    ) external view returns (bytes32, uint256, uint32);

    // Returns a specific version of the data
    function getDataPointerVersion(
        address patient,
        uint8 dataType,
        uint32 version
    ) external view returns (bytes32 dataHash, uint256 timestamp);
}

contract AccessController {

    IConsentManager public consentManager;
    IDataRegistry public dataRegistry;

    event AccessLogged(
        address indexed requester, 
        address indexed patient, 
        uint8 dataType, 
        uint32 dataVersion,
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
        // If a contract is deployed in a adress say 0xAAAAA then the AAA is the contract manager, that contractmanager has the tools and functions (i.e has access)
        // So this will be only used just to use some functions from ConsentManager and data registry, -no special entity-.
        require(_consentManager != address(0), "Invalid ConsentManager address");
        require(_dataRegistry != address(0), "Invalid DataRegistry address");
        
        consentManager = IConsentManager(_consentManager);
        dataRegistry = IDataRegistry(_dataRegistry);
    }

    /**
     * @dev Access patient data if consent is valid
     * @param patient Address of the patient whose data is being accessed
     * @param dataType Type of medical data (1=LAB_RESULTS, 2=IMAGING, 3=FULL_RECORD)
     * @param dataVersion Exact version of the data being requested
     * @return dataHash The hash pointer to the encrypted off-chain data
     * @return timestamp When this data was registered
     * @return version Version number of the data (echoes dataVersion)
     */
    function accessData(
        address patient, 
        uint8 dataType,
        uint32 dataVersion
    ) external returns (bytes32 dataHash, uint256 timestamp, uint32 version) {
        require(patient != address(0), "Invalid patient address");
        require(dataType >= 1 && dataType <= 3, "Invalid dataType");
        require(dataVersion > 0, "Invalid dataVersion");

        //Check if requester has valid consent for this dataType and this dataVersion
        bool hasConsent = consentManager.hasValidConsent(
            patient,
            msg.sender,
            dataType,
            dataVersion
        );

        if (!hasConsent) {
            emit AccessLogged(msg.sender, patient, dataType, dataVersion, false, block.timestamp);
            emit AccessDenied(msg.sender, patient, dataType, "No valid consent");
            return (bytes32(0), 0, 0);
        }

        //try to fetch that specific version from the registry
        try dataRegistry.getDataPointerVersion(patient, dataType, dataVersion) returns (
            bytes32 _dataHash,
            uint256 _timestamp
        ) {
            emit AccessLogged(msg.sender, patient, dataType, dataVersion, false, block.timestamp);
            return (_dataHash, _timestamp, dataVersion);
        } catch Error(string memory reason) {
            emit AccessLogged(msg.sender, patient, dataType, dataVersion, false, block.timestamp);
            emit AccessDenied(msg.sender, patient, dataType, reason);
            return (bytes32(0), 0, 0);
        } catch {
            emit AccessLogged(msg.sender, patient, dataType, dataVersion, false, block.timestamp);
            emit AccessDenied(
                msg.sender,
                patient,
                dataType,
                "Requested version does not exist or data retrieval failed"
            );
            return (bytes32(0), 0, 0);
        }
    }

    /**
     * @dev View function to check if access would be granted (doesn't log)
     * @param patient Address of the patient
     * @param requester Address of the requester
     * @param dataType Type of medical data
     * @param dataVersion Version of the data
     * @return True if access would be granted
     */
    function checkAccessPermission( // Check if the doctor has an access to patient's specific version of a datatype
        address patient,
        address requester,
        uint8 dataType,
        uint32 dataVersion
    ) external view returns (bool) {
        return consentManager.hasValidConsent(
            patient,
            requester,
            dataType,
            dataVersion
        );
    }

    function getDataRegistryAddress() external view returns (address) { // Some helper functions to see which address deployed the contract
        return address(dataRegistry);
    }

    function getConsentManagerAddress() external view returns (address) { // Some helper functions to see which address deployed the contract
        return address(consentManager);
    }
}
