// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../contracts/AccessController.sol";

// Mock ConsentManager for test_ing
contract MockConsentManager {
    mapping(bytes32 => bool) private consents;
    
    function setConsent(address patient, address requester, uint8 dataType, uint8 purpose, bool value) external {
        bytes32 key = keccak256(abi.encodePacked(patient, requester, dataType, purpose));
        consents[key] = value;
    }
    
    function hasValidConsent(address patient, address requester, uint8 dataType, uint8 purpose) external view returns (bool) {
        bytes32 key = keccak256(abi.encodePacked(patient, requester, dataType, purpose));
        return consents[key];
    }
}

// Mock DataRegistry for test_ing
contract MockDataRegistry {
    struct DataPointer {
        bytes32 dataHash;
        uint256 timestamp;
        uint32 version;
        bool exists;
    }
    
    mapping(bytes32 => DataPointer) private dataPointers;
    bool public shouldRevert;
    string public revertReason;
    
    function setDataPointer(address patient, uint8 dataType, bytes32 dataHash, uint256 timestamp, uint32 version) external {
        bytes32 key = keccak256(abi.encodePacked(patient, dataType));
        dataPointers[key] = DataPointer(dataHash, timestamp, version, true);
    }
    
    function setShouldRevert(bool _shouldRevert, string memory _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }
    
    function getLatest_DataPointer(address patient, uint8 dataType) external view returns (bytes32, uint256, uint32) {
        if (shouldRevert) {
            if (bytes(revertReason).length > 0) {
                revert(revertReason);
            } else {
                revert();
            }
        }
        
        bytes32 key = keccak256(abi.encodePacked(patient, dataType));
        DataPointer memory pointer = dataPointers[key];
        
        require(pointer.exists, "Data not found");
        
        return (pointer.dataHash, pointer.timestamp, pointer.version);
    }
}

// Test contract
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
    
    uint8 constant PURPOSE_TREATMENT = 1;
    
    event AccessLogged(address indexed requester, address indexed patient, uint8 dataType, bool success, uint256 timestamp);
    event AccessDenied(address indexed requester, address indexed patient, uint8 dataType, string reason);
    
    constructor() {
        consentManager = new MockConsentManager();
        dataRegistry = new MockDataRegistry();
        accessController = new AccessController(address(consentManager), address(dataRegistry));
    }
    
    // Test 1: Constructor validation
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
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid DataRegistry address")),
                "Wrong error message"
            );
        }
    }
    
    // Test 2: Successful data access with valid consent
    function test_AccessDataWithValidConsent() external returns (bool) {
        // Setup: Grant consent - need to set it for msg.sender (this contract)
        consentManager.setConsent(patient, address(this), LAB_RESULTS, PURPOSE_TREATMENT, true);
        
        // Setup: Register data
        bytes32 expectedHash = keccak256("medical-data-hash");
        uint256 expectedTimestamp = block.timestamp;
        uint32 expectedVersion = 1;
        dataRegistry.setDataPointer(patient, LAB_RESULTS, expectedHash, expectedTimestamp, expectedVersion);
        
        // Execute: Access data (msg.sender will be this test_ contract)
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, PURPOSE_TREATMENT);
        
        // Verify
        require(dataHash == expectedHash, "Data hash mismatch");
        require(timestamp == expectedTimestamp, "Timestamp mismatch");
        require(version == expectedVersion, "Version mismatch");
        
        return true;
    }
    
    // Test 3: Access denied without consent
    function test_AccessDataWithoutConsent() external {
        // Setup: Register data but no consent
        bytes32 expectedHash = keccak256("medical-data-hash");
        dataRegistry.setDataPointer(patient, LAB_RESULTS, expectedHash, block.timestamp, 1);
        
        // Execute: Try to access without consent
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, PURPOSE_TREATMENT);
        
        // Verify: Should return empty values
        require(dataHash == bytes32(0), "Expected empty data hash");
        require(timestamp == 0, "Expected zero timestamp");
        require(version == 0, "Expected zero version");
    }
    
    // Test 4: Invalid patient address
    function test_AccessDataInvalidPatient() external {
        try accessController.accessData(address(0), LAB_RESULTS, PURPOSE_TREATMENT) {
            revert("Should have reverted with invalid patient");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid patient address")),
                "Wrong error message"
            );
        }
    }
    
    // Test 5: Invalid data type
    function test_AccessDataInvalidDataType() external {
        try accessController.accessData(patient, 0, PURPOSE_TREATMENT) {
            revert("Should have reverted with invalid dataType");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid dataType")),
                "Wrong error message"
            );
        }
        
        try accessController.accessData(patient, 4, PURPOSE_TREATMENT) {
            revert("Should have reverted with invalid dataType");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) == keccak256(bytes("Invalid dataType")),
                "Wrong error message"
            );
        }
    }
    
    // Test 6: Data retrieval failure with error message
    function test_AccessDataRetrievalFailureWithReason() external {
        // Setup: Grant consent but make registry fail
        consentManager.setConsent(patient, requester, LAB_RESULTS, PURPOSE_TREATMENT, true);
        dataRegistry.setShouldRevert(true, "Data not found");
        
        // Execute
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, PURPOSE_TREATMENT);
        
        // Verify: Should return empty values
        require(dataHash == bytes32(0), "Expected empty data hash");
        require(timestamp == 0, "Expected zero timestamp");
        require(version == 0, "Expected zero version");
    }
    
    // Test 7: Data retrieval failure without error message
    function test_AccessDataRetrievalFailureWithoutReason() external {
        // Setup: Grant consent but make registry fail without reason
        consentManager.setConsent(patient, requester, LAB_RESULTS, PURPOSE_TREATMENT, true);
        dataRegistry.setShouldRevert(true, "");
        
        // Execute
        (bytes32 dataHash, uint256 timestamp, uint32 version) = 
            accessController.accessData(patient, LAB_RESULTS, PURPOSE_TREATMENT);
        
        // Verify: Should return empty values
        require(dataHash == bytes32(0), "Expected empty data hash");
        require(timestamp == 0, "Expected zero timestamp");
        require(version == 0, "Expected zero version");
    }
    
    // Test 8: Check access permission (view function)
    function test__CheckAccessPermission() external {
        // Without consent
        bool hasAccess = accessController.checkAccessPermission(patient, requester, LAB_RESULTS, PURPOSE_TREATMENT);
        require(!hasAccess, "Should not have access without consent");
        
        // Grant consent
        consentManager.setConsent(patient, requester, LAB_RESULTS, PURPOSE_TREATMENT, true);
        
        // With consent
        hasAccess = accessController.checkAccessPermission(patient, requester, LAB_RESULTS, PURPOSE_TREATMENT);
        require(hasAccess, "Should have access with consent");
    }
    
    // Test 9: Get contract addresses
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
    
    // Test 10: Multiple data types
    function test_MultipleDataTypes() external returns (bool) {
        // Setup consents for all data types - using address(this) as the requester
        consentManager.setConsent(patient, address(this), LAB_RESULTS, PURPOSE_TREATMENT, true);
        consentManager.setConsent(patient, address(this), IMAGING, PURPOSE_TREATMENT, true);
        consentManager.setConsent(patient, address(this), FULL_RECORD, PURPOSE_TREATMENT, true);
        
        // Setup data for each type
        bytes32 hash1 = keccak256("lab-data");
        bytes32 hash2 = keccak256("imaging-data");
        bytes32 hash3 = keccak256("full-record-data");
        
        dataRegistry.setDataPointer(patient, LAB_RESULTS, hash1, block.timestamp, 1);
        dataRegistry.setDataPointer(patient, IMAGING, hash2, block.timestamp, 1);
        dataRegistry.setDataPointer(patient, FULL_RECORD, hash3, block.timestamp, 1);
        
        // Access each type
        (bytes32 dataHash1,,) = accessController.accessData(patient, LAB_RESULTS, PURPOSE_TREATMENT);
        (bytes32 dataHash2,,) = accessController.accessData(patient, IMAGING, PURPOSE_TREATMENT);
        (bytes32 dataHash3,,) = accessController.accessData(patient, FULL_RECORD, PURPOSE_TREATMENT);
        
        require(dataHash1 == hash1, "LAB_RESULTS hash mismatch");
        require(dataHash2 == hash2, "IMAGING hash mismatch");
        require(dataHash3 == hash3, "FULL_RECORD hash mismatch");
        
        return true;
    }
    
}