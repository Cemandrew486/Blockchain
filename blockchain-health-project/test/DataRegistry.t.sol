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
        bytes32 hash1 = keccak256("record1");
        bytes32 hash2 = keccak256("record2");

        vm.prank(patient);
        registry.setDataPointer(1, hash1);

        vm.prank(patient);
        registry.setDataPointer(1, hash2);

        (bytes32 latestHash, , uint32 latestVersion) =
            registry.getLatestDataPointer(patient, 1);

        assertEq(latestHash, hash2);
        assertEq(latestVersion, 2);

        uint256 count = registry.getVersionCount(patient, 1);
        assertEq(count, 2);

        (bytes32 v1Hash, ) = registry.getDataPointerVersion(patient, 1, 1);
        assertEq(v1Hash, hash1);
    }

    function test_invalidType() public {
        vm.prank(patient);
        vm.expectRevert(bytes("Invalid dataType"));
        registry.setDataPointer(4, keccak256("invalid"));
    }

    function test_emptyHash() public {
        vm.prank(patient);
        vm.expectRevert(bytes("Empty hash"));
        registry.setDataPointer(1, bytes32(0));
    }

    function test_noLatest() public {
        vm.expectRevert(bytes("No data for this type"));
        registry.getLatestDataPointer(patient, 1);
    }

    function test_InvalidVersion() public {
        vm.prank(patient);
        registry.setDataPointer(1, keccak256("record"));

        vm.expectRevert(bytes("Invalid version"));
        registry.getDataPointerVersion(patient, 1, 2);
    }
}
