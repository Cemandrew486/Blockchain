// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/DigitalIdentityRegistry.sol";

contract DigitalIdentityRegistryTest is Test {
    DigitalIdentityRegistry registry;

    address owner = address(0x1);
    address institute = address(0x2);
    address doc = address(0x3);
    address patient = address(0x4);
    address researcher = address(0x5);
    address insurer = address(0x6);
    address stranger = address(0x7);
    address newAddr = address(0x8);

    function setUp() public {
        vm.prank(owner);
        registry = new DigitalIdentityRegistry(institute, doc);
    }

    function test_ConstructorSetsRoles() public {
        assertEq(registry.owner(), owner);
        assertEq(registry.instituteResearcher(), institute);
        assertEq(registry.doctor(), doc);
    }

    function test_RegisterPatient() public {
        bytes32 hashId = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashId);

        (
            uint256 internalId,
            address userAddress,
            DigitalIdentityRegistry.Role role,
            bytes32 storedHashId,
            bool isRegistered
        ) = registry.users(patient);

        assertEq(userAddress, patient);
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.PATIENT));
        assertEq(storedHashId, hashId);
        assertTrue(isRegistered);
        assertGt(internalId, 0);
    }

    function test_RegisterPatientTwice() public {
        bytes32 hashId = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashId);

        vm.prank(patient);
        vm.expectRevert(bytes("User already registered"));
        registry.registerPatient(hashId);
    }

    function test_RegisterDoctorOnlyOwner() public {
        bytes32 hashId = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashId);

        (
            ,
            address userAddress,
            DigitalIdentityRegistry.Role role,
            bytes32 storedHashId,
            bool isRegistered
        ) = registry.users(doc);

        assertEq(userAddress, doc);
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.DOCTOR));
        assertEq(storedHashId, hashId);
        assertTrue(isRegistered);
    }

    function test_RegisterDoctorNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("Only owner"));
        registry.registerDoctor(doc, keccak256("doc1"));
    }

    function test_RegisterResearcherOwnerOrInstitute() public {
        bytes32 hashId = keccak256("res1");

        vm.prank(owner);
        registry.registerResearcher(researcher, hashId);

        (
            ,
            ,
            DigitalIdentityRegistry.Role roleOwner,
            ,
            bool isRegisteredOwner
        ) = registry.users(researcher);

        assertEq(uint8(roleOwner), uint8(DigitalIdentityRegistry.Role.RESEARCHER));
        assertTrue(isRegisteredOwner);

        address researcher2 = address(0x9);
        bytes32 hashId2 = keccak256("res2");

        vm.prank(institute);
        registry.registerResearcher(researcher2, hashId2);

        (
            ,
            ,
            DigitalIdentityRegistry.Role roleInst,
            ,
            bool isRegisteredInst
        ) = registry.users(researcher2);

        assertEq(uint8(roleInst), uint8(DigitalIdentityRegistry.Role.RESEARCHER));
        assertTrue(isRegisteredInst);
    }

    function test_RegisterResearcherUnauthorized() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("Only owner or institute"));
        registry.registerResearcher(researcher, keccak256("res1"));
    }

    function test_RegisterInsuranceOnlyOwner() public {
        bytes32 hashId = keccak256("ins1");

        vm.prank(owner);
        registry.registerInsurance(insurer, hashId);

        (
            ,
            ,
            DigitalIdentityRegistry.Role role,
            ,
            bool isRegistered
        ) = registry.users(insurer);

        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.INSURANCE));
        assertTrue(isRegistered);
    }

    function test_RegisterInsuranceNonOwner() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("Only owner"));
        registry.registerInsurance(insurer, keccak256("ins1"));
    }

    function test_GetPatientOnlyDoctorAndRoleCheck() public {
        bytes32 hashId = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashId);

        vm.prank(doc);
        (
            address userAddress,
            DigitalIdentityRegistry.Role role,
            bytes32 returnedHash,
            bool isRegistered,
            uint256 internalId
        ) = registry.getPatient(patient);

        assertEq(userAddress, patient);
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.PATIENT));
        assertEq(returnedHash, hashId);
        assertTrue(isRegistered);
        assertGt(internalId, 0);
    }

    function test_GetPatientNonDoctor() public { 
        bytes32 hashId = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashId);

        vm.prank(stranger);
        vm.expectRevert(bytes("Violating hippocratic oath is not allowed"));
        registry.getPatient(patient); // başkası
    }

    function test_GetStaffOnlyOwnerAndNotPatient() public {
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        vm.prank(owner);
        (
            address userAddress,
            DigitalIdentityRegistry.Role role,
            bytes32 returnedHash,
            bool isRegistered,
            uint256 internalId
        ) = registry.getStaff(doc);

        assertEq(userAddress, doc);
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.DOCTOR));
        assertEq(returnedHash, hashIdDoc);
        assertTrue(isRegistered);
        assertGt(internalId, 0);
    }

    function test_GetStaffNonOwner() public {
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        vm.prank(stranger);
        vm.expectRevert(bytes("Only owner"));
        registry.getStaff(doc);
    }

    function test_GetStaffOnPatient() public {
        bytes32 hashIdP = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashIdP);

        vm.prank(owner);
        vm.expectRevert(bytes("What you do is illegal!"));
        registry.getStaff(patient);
    }

    function test_UpdateUserAddress() public {
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        (
            uint256 internalId,
            ,
            ,
            ,
            bool isRegistered
        ) = registry.users(doc);

        assertTrue(isRegistered);

        vm.prank(owner);
        registry.updateUserAddress(internalId, newAddr);

        (
            uint256 newInternalId,
            address userAddress,
            DigitalIdentityRegistry.Role role,
            bytes32 storedHashId,
            bool newIsRegistered
        ) = registry.users(newAddr);

        assertEq(newInternalId, internalId);
        assertEq(userAddress, newAddr);
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.DOCTOR));
        assertEq(storedHashId, hashIdDoc);
        assertTrue(newIsRegistered);

        (
            ,
            ,
            ,
            ,
            bool oldIsRegistered
        ) = registry.users(doc);
        assertFalse(oldIsRegistered);

        address mappedAddr = registry.internalIdToAddress(internalId);
        assertEq(mappedAddr, newAddr);
    }

    function test_UpdateUserAddressRevertsForUnknownId() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Unknown internalId"));
        registry.updateUserAddress(999, newAddr);
    }

    function test_UpdateUserAddressRevertsForZeroAddress() public {
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        (uint256 internalId, , , , ) = registry.users(doc);

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid new address"));
        registry.updateUserAddress(internalId, address(0));
    }

    function test_UpdateUserAddressRevertsIfNewAlreadyRegistered() public {
        bytes32 hashIdDoc = keccak256("doc1");
        bytes32 hashIdOther = keccak256("other");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        vm.prank(owner);
        registry.registerDoctor(newAddr, hashIdOther);

        (uint256 internalId, , , , ) = registry.users(doc);

        vm.prank(owner);
        vm.expectRevert(bytes("New address already registered"));
        registry.updateUserAddress(internalId, newAddr);
    }
}
