// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../contracts/AccessController.sol";

// Mock ConsentManager used to simulate consent checks in isolation
// version-aware version stores a boolean per (patient, requester, dataType, dataVersion)
// First create necessary mockdata sets and functions to actually test AccessController
contract MockConsentManager {
    mapping(bytes32 => bool) private consents; // This is not matching structure we did in the consentManager, because the goal of the tests here different 
                                               // rather than checking again if the consentManager works correctly. 
    
    function setConsent(
        address patient,
        address requester,
        uint8 dataType,
        uint32 dataVersion,
        bool value
    ) external {
        bytes32 key = keccak256(abi.encodePacked(patient, requester, dataType, dataVersion)); // hash of the Imaginary off-chain data
        consents[key] = value;
    }
    
    function hasValidConsent(
        address patient,
        address requester,
        uint8 dataType,
        uint32 dataVersion
    ) external view returns (bool) {
        bytes32 key = keccak256(abi.encodePacked(patient, requester, dataType, dataVersion));
        return consents[key];
    }
}

// version-aware mockdata and implements both getLatestDataPointer and getDataPointerVersion.
contract MockDataRegistry {
    struct DataPointer {
        bytes32 dataHash;
        uint256 timestamp;
        uint32 version;
        bool exists;
    }
    
    // key for a specific version: keccak(patient, dataType, version)
    mapping(bytes32 => DataPointer) private dataPointers;
    // key for latest-version lookup: keccak(patient, dataType) → latestVersion (Just for easiness. Doctors shouldn't remember the index number of the last test they did)
    mapping(bytes32 => uint32) private latestVersion;

    bool public shouldRevert;
    string public revertReason;
    
    function setDataPointer(
        address patient,
        uint8 dataType,
        uint32 version,
        bytes32 dataHash,
        uint256 timestamp
    ) external {
        bytes32 versionKey = keccak256(abi.encodePacked(patient, dataType, version));
        dataPointers[versionKey] = DataPointer(dataHash, timestamp, version, true);

        // track latest version per (patient, dataType)
        bytes32 baseKey = keccak256(abi.encodePacked(patient, dataType));
        if (version > latestVersion[baseKey]) {
            latestVersion[baseKey] = version;
        }
    }
    
    function setShouldRevert(bool _shouldRevert, string memory _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }

    // This is for easiness but we should also add this to check
    function getLatestDataPointer(
        address patient,
        uint8 dataType
    ) external view returns (bytes32, uint256, uint32) {
        if (shouldRevert) {
            if (bytes(revertReason).length > 0) {
                revert(revertReason);
            } else {
                revert();
            }
        }

        bytes32 baseKey = keccak256(abi.encodePacked(patient, dataType));
        uint32 v = latestVersion[baseKey]; 
        require(v != 0, "Data not found"); // The version actually needs to exist

        bytes32 versionKey = keccak256(abi.encodePacked(patient, dataType, v));
        DataPointer memory pointer = dataPointers[versionKey];
        require(pointer.exists, "Data not found"); // Thre should be a data 

        return (pointer.dataHash, pointer.timestamp, pointer.version);
    }

    function getDataPointerVersion(
        address patient,
        uint8 dataType,
        uint32 version
    ) external view returns (bytes32 dataHash, uint256 timestamp) {
        if (shouldRevert) {
            if (bytes(revertReason).length > 0) {
                revert(revertReason);
            } else {
                revert();
            }
        }

        bytes32 versionKey = keccak256(abi.encodePacked(patient, dataType, version));
        DataPointer memory pointer = dataPointers[versionKey];
        require(pointer.exists, "Data not found");

        return (pointer.dataHash, pointer.timestamp);
    }
}

// tests for AccessController using the above mocks
contract AccessController_t {
    AccessController public accessController;
    MockConsentManager public consentManager;
    MockDataRegistry public dataRegistry;
    
    address public patient = address(0x1234);
    address public requester = address(0x5678);
    address public unauthorizedRequester = address(0x9ABC);
    
    uint8 constant LAB_RESULTS = 1;
    uint8 constant IMAGING = 2;
    uint8 constant FULL_RECORD = 3;

    uint32 constant VERSION_1 = 1;
    
    // Event signatures
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
    
    constructor() {
        consentManager = new MockConsentManager();
        dataRegistry = new MockDataRegistry();
        accessController = new AccessController(address(consentManager), address(dataRegistry));
    }
    
    // Constructor validation (ConsentManager address must not be zero)
    function test_ConstructorInvalidConsentManager() external {
        try new AccessController(address(0), address(dataRegistry)) {
            revert("Should have reverted with invalid ConsentManager");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid ConsentManager address")),
                "Wrong error message"
            );
        }
    }
    
    function test_ConstructorInvalidDataRegistry() external {
        try new AccessController(address(consentManager), address(0)) {
            revert("Should have reverted with invalid DataRegistry");
        } catch Error(string memory reason) { // If the function reverts with a string message, catch it and store that string inside the reason variable.
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid DataRegistry address")),
                "Wrong error message"
            );
        }
    }
    
    // Successful data access with valid consent
    function test_AccessDataWithValidConsent() external returns (bool) {
        // Grant consent for (patient, this test contract, LAB_RESULTS, VERSION_1)
        // accessController will see msg.sender = this contract which needs to be a doctor or someone who has authority see the data
        consentManager.setConsent(patient, address(this), LAB_RESULTS, VERSION_1, true);
        
        // \Register a data pointer for the same
        bytes32 expectedHash = keccak256("medical-data-hash");
        uint256 expectedTimestamp = block.timestamp;
        uint32 expectedVersion = VERSION_1;
        dataRegistry.setDataPointer(patient, LAB_RESULTS, expectedVersion, expectedHash, expectedTimestamp);
        
        // Access data (msg.sender = this test contract as requester)
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, VERSION_1);
        
        // Verify
        require(dataHash == expectedHash, "Data hash mismatch");
        require(timestamp == expectedTimestamp, "Timestamp mismatch");
        require(version == expectedVersion, "Version mismatch");
        
        return true;
    }
    
    // Access denied when consent is missing
    function test_AccessDataWithoutConsent() external {
        // Register data but do NOT grant consent for requester
        bytes32 expectedHash = keccak256("medical-data-hash");
        dataRegistry.setDataPointer(patient, LAB_RESULTS, VERSION_1, expectedHash, block.timestamp);
        
        // Try to access without consent
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, VERSION_1);
        
        // Should return empty values since there was no access thus feeding no parameter
        require(dataHash == bytes32(0), "Expected empty data hash");
        require(timestamp == 0, "Expected zero timestamp");
        require(version == 0, "Expected zero version");
    }
    
    // Invalid patient address must revert with explicit reason
    function test_AccessDataInvalidPatient() external {
        try accessController.accessData(address(0), LAB_RESULTS, VERSION_1) {
            revert("Should have reverted with invalid patient");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid patient address")),
                "Wrong error message"
            );
        }
    }
    
    // Invalid data type
    function test_AccessDataInvalidDataType() external {
        try accessController.accessData(patient, 0, VERSION_1) {
            revert("Should have reverted with invalid dataType");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid dataType")),
                "Wrong error message"
            );
        }
        
        try accessController.accessData(patient, 4, VERSION_1) { // Nothing is indexed to for our data types go until 3
            revert("Should have reverted with invalid dataType");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid dataType")),
                "Wrong error message"
            );
        }
    }
    
    // Data retrieval failure with error message
    function test_AccessDataRetrievalFailureWithReason() external {
        //Grant consent for this contract as requester
        consentManager.setConsent(patient, address(this), LAB_RESULTS, VERSION_1, true);
        dataRegistry.setShouldRevert(true, "Data not found");
        
        // accessData should catch the revert and return empty tuple
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, VERSION_1);
        
        // Should return empty values
        require(dataHash == bytes32(0), "Expected empty data hash");
        require(timestamp == 0, "Expected zero timestamp");
        require(version == 0, "Expected zero version");
    }
    
    //Check access permission (view function)
    function test__CheckAccessPermission() external {
        // Without consent, should be false
        bool hasAccess = accessController.checkAccessPermission(patient, requester, LAB_RESULTS, VERSION_1);
        require(!hasAccess, "Should not have access without consent");
        
        // Grant consent for the same requester, dataType and version
        consentManager.setConsent(patient, requester, LAB_RESULTS, VERSION_1, true);
        
        // With consent should be true
        hasAccess = accessController.checkAccessPermission(patient, requester, LAB_RESULTS, VERSION_1);
        require(hasAccess, "Should have access with consent");
    }
    
    //Get contract addresses 
    function test__GetAddresses() view external {
        require(
            accessController.getDataRegistryAddress() == address(dataRegistry),
            "DataRegistry address mismatch"
        );
        require(
            accessController.getConsentManagerAddress() == address(consentManager),
            "ConsentManager address mismatch"
        );
    }
    
    //Multiple data types
    function test_MultipleDataTypes() external returns (bool) {
        //grant consent for all data types (requester = this contract)
        consentManager.setConsent(patient, address(this), LAB_RESULTS, VERSION_1, true);
        consentManager.setConsent(patient, address(this), IMAGING, VERSION_1, true);
        consentManager.setConsent(patient, address(this), FULL_RECORD, VERSION_1, true);
        
        //register one data pointer per type, version 1
        bytes32 hash1 = keccak256("lab-data");
        bytes32 hash2 = keccak256("imaging-data");
        bytes32 hash3 = keccak256("full-record-data");
        
        dataRegistry.setDataPointer(patient, LAB_RESULTS, VERSION_1, hash1, block.timestamp);
        dataRegistry.setDataPointer(patient, IMAGING, VERSION_1, hash2, block.timestamp);
        dataRegistry.setDataPointer(patient, FULL_RECORD, VERSION_1, hash3, block.timestamp);
        
        //access each type and verify the corresponding hash is returned
        (bytes32 dataHash1,,) = accessController.accessData(patient, LAB_RESULTS, VERSION_1);
        (bytes32 dataHash2,,) = accessController.accessData(patient, IMAGING, VERSION_1);
        (bytes32 dataHash3,,) = accessController.accessData(patient, FULL_RECORD, VERSION_1);
        
        require(dataHash1 == hash1, "LAB_RESULTS hash mismatch");
        require(dataHash2 == hash2, "IMAGING hash mismatch");
        require(dataHash3 == hash3, "FULL_RECORD hash mismatch");
        
        return true;
    }
}
