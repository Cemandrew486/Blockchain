// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/DataRegistry.sol";

contract DataRegistryTest is Test {
    DataRegistry registry;
    address patient = address(0x1);

    function setUp() public {
        registry = new DataRegistry();
    }

    function test_storeAndVersion() public {
        bytes32 hash1 = keccak256("record1"); // Placeholder for off chain data.
        bytes32 hash2 = keccak256("record2"); // Placeholder for off chain data.

        vm.prank(patient); // Set msg.sender = patient for the next call.
        registry.setDataPointer(1, hash1); // Assume a new lab result data came out for a patient. And pointing hash is hash1. 

        vm.prank(patient);
        registry.setDataPointer(1, hash2); // Here we add a new lab result with new hash(pointing it).

        (bytes32 latestHash, , uint32 latestVersion) =
            registry.getLatestDataPointer(patient, 1);

        assertEq(latestHash, hash2); // Check if the latestHash is equal to second hash which was the latest hash
        assertEq(latestVersion, 2); // Same logic but now check for the version

        uint256 count = registry.getVersionCount(patient, 1);
        assertEq(count, 2); // See if the number of total versions matches

        (bytes32 v1Hash, ) = registry.getDataPointerVersion(patient, 1, 1);
        assertEq(v1Hash, hash1); //Get the data pointer of the first version of the lab result for a patient and see if the hashes match.
    }

    function test_invalidType() public {
        vm.prank(patient);
        vm.expectRevert(bytes("Invalid dataType")); // Vmexpectrevert expects next call to revert.
        registry.setDataPointer(4, keccak256("invalid")); // This line will revert because there is no type of data whose id is 4. 
    }

    function test_emptyHash() public {
        vm.prank(patient);
        vm.expectRevert(bytes("Empty hash")); // Same revert logic here. We are expecting to next call to revert.
        registry.setDataPointer(1, bytes32(0)); // We give no hash here, so the call should revert.
    }

    function test_noLatest() public { 
        vm.expectRevert(bytes("No data for this type")); // Same revert logic.
        registry.getLatestDataPointer(patient, 1); // We haven't fed any data so this should also revert.
    }

    function test_InvalidVersion() public {
        vm.prank(patient);
        registry.setDataPointer(1, keccak256("record")); // Fake data to test. Lab result is equal to 1 and record is just a place holder for off chain data.

        vm.expectRevert(bytes("Invalid version")); // Same revert logic.
        registry.getDataPointerVersion(patient, 1, 2); // We try to get the second version of a lab result of a patient. But it does not exist so this should revert as well.
    }
}
