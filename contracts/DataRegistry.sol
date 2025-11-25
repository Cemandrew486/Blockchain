// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract DataRegistry {

    struct DataPointer {
        bytes32 pointerHash;
        uint256 timestamp;
    }

    mapping(address => mapping(uint8 => DataPointer)) public dataPointers;

    event DataPointerUpdated(address patient, uint8 dataType, bytes32 pointerHash);

    function setDataPointer(uint8 dataType, bytes32 pointerHash) external {
        dataPointers[msg.sender][dataType] = DataPointer(pointerHash, block.timestamp);
        emit DataPointerUpdated(msg.sender, dataType, pointerHash);
    }

    function getLatestDataPointer(address patient, uint8 dataType) 
        external view returns (bytes32, uint256) 
    {
        DataPointer memory dp = dataPointers[patient][dataType];
        return (dp.pointerHash, dp.timestamp);
    }
}
