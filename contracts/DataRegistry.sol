// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract DataRegistry {

    // dataType codes:
    // 0 = Ignore (array index convention) 
    // 1 = LAB_RESULTS
    // 2 = IMAGING (X-ray, MRI pictures of the inside body
    // 3 = FULL_RECORD

    struct DataPointer {
        bytes32 dataHash;   // keccak256(encrypted off-chain record)
        uint256 timestamp;  // when this version was registered
        uint32 version;     // 0, 1, 2..., per (patient, dataType)
    }

    // address of the patient is given -> see which type is requested -> point to the array that stored that type of information
    mapping(address => mapping(uint8 => DataPointer[])) public dataPointers;

    event DataPointerUpdated(address indexed patient, uint8 indexed dataType, uint32 version, bytes32 dataHash);

    
    // dataType Encoded type of medical data (For an example : "1" means lab result)
    // dataHash keccak256(encrypted JSON or binary medical record) for an authorized contract) 
    
    // Some examples for better understanding. "Ahmet" is just a name
    // Ahmet -> lab1 results -> list [] (Contains Data pointer struct elements)
    // list[0] = data hash : datahash, timestamp: 1534234, version : 1
    // Ahmet -> lab1 results -> list [] (Contains Data pointer struct elements)
    // list[1] = data hash : datahash, timestamp: 1534234, version : 2

    function setDataPointer(uint8 dataType, bytes32 dataHash) external {
        require(dataType <= 3, "Invalid dataType");
        require(dataHash != bytes32(0), "Empty hash");

        DataPointer[] storage list = dataPointers[msg.sender][dataType];
        uint32 newVersion = uint32(list.length + 1);

        list.push(
            DataPointer({
                dataHash: dataHash,
                timestamp: block.timestamp,
                version: newVersion
            })
        );

        emit DataPointerUpdated(msg.sender, dataType, newVersion, dataHash);
    }

    //Get the latest record hash for a patient and dataType
    function getLatestDataPointer(
        address patient,
        uint8 dataType
    ) external view returns (bytes32 dataHash, uint256 timestamp, uint32 version) {
        DataPointer[] storage list = dataPointers[patient][dataType];
        require(list.length > 0, "No data for this type");

        DataPointer storage dp = list[list.length - 1];
        return (dp.dataHash, dp.timestamp, dp.version);
    }

    //Get a specific historical version
    function getDataPointerVersion(
        address patient,
        uint8 dataType,
        uint32 version
    ) external view returns (bytes32 dataHash, uint256 timestamp) {
        DataPointer[] storage list = dataPointers[patient][dataType];
        require(version >= 1 && version <= list.length, "Invalid version");

        DataPointer storage dp = list[version - 1];
        return (dp.dataHash, dp.timestamp);
    }

    //To check how many versions exist for this patient+dataType
    function getVersionCount(
        address patient,
        uint8 dataType
    ) external view returns (uint256) {
        return dataPointers[patient][dataType].length;
    }
}
