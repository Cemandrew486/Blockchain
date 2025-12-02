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

        vm.prank(patient); // msg.sender is assigned to patient for the next call.
        registry.registerPatient(hashId); // Register a paitent with the given hash

        (
            uint256 internalId,
            address userAddress,
            DigitalIdentityRegistry.Role role,
            bytes32 storedHashId,
            bool isRegistered
        ) = registry.users(patient); // Return the values from the mapping.

        assertEq(userAddress, patient); //Check if addresses match.
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.PATIENT)); // Check if roles match.
        assertEq(storedHashId, hashId); //Check if hashes match.
        assertTrue(isRegistered); // Check if isRegistered returns true. (isRegistered returns true if the entity is registered.)
        assertGt(internalId, 0); // Internal id must be greater than 0 because it is incremented in the registration process
    }

    function test_RegisterPatientTwice() public {
        bytes32 hashId = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashId);

        vm.prank(patient);
        vm.expectRevert(bytes("User already registered")); // Next call should revert. 
        registry.registerPatient(hashId); // Using the same hash to trigger vmexpectrevert. (can't register the same person again)
    }

    function test_RegisterDoctorOnlyOwner() public {
        bytes32 hashId = keccak256("doc1");

        vm.prank(owner); // msg.sender is now equal to owner
        registry.registerDoctor(doc, hashId); // Owner is allowed to register doctors.

        (
            , // Ignore the first data
            address userAddress, 
            DigitalIdentityRegistry.Role role, 
            bytes32 storedHashId,
            bool isRegistered
        ) = registry.users(doc); // Return the values for registered doctor.

        assertEq(userAddress, doc);
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.DOCTOR)); // Same checkings as we did for the patient.
        assertEq(storedHashId, hashId);
        assertTrue(isRegistered);
    }

    function test_RegisterDoctorNonOwner() public {
        vm.prank(stranger); // msg.sender == stranger. Stranger is address that is not owner.
        vm.expectRevert(bytes("Only owner")); // Next call is expected to revert.
        registry.registerDoctor(doc, keccak256("doc1"));  // This should be wrong since the msg.sender is equal to stranger.
    }

    function test_RegisterResearcherOwnerOrInstitute() public {
        bytes32 hashId = keccak256("res1"); // This is an entity that could be researcher, owner or institute.

        vm.prank(owner); // Same. setting the msg.sender == owner.
        registry.registerResearcher(researcher, hashId); //Register one of those entities.

        (
            , // We don't care first two data.
            ,
            DigitalIdentityRegistry.Role roleOwner, 
            ,
            bool isRegisteredOwner
        ) = registry.users(researcher); // Return values for researcher (for this instance.)

        assertEq(uint8(roleOwner), uint8(DigitalIdentityRegistry.Role.RESEARCHER)); //Check role
        assertTrue(isRegisteredOwner);// Check if registered.

        address researcher2 = address(0x9);
        bytes32 hashId2 = keccak256("res2");

        vm.prank(institute); // Set msg.sender to institute
        registry.registerResearcher(researcher2, hashId2); // Register but this time institute.

        (
            ,
            ,
            DigitalIdentityRegistry.Role roleInst,
            ,
            bool isRegisteredInst
        ) = registry.users(researcher2); // Same logic

        assertEq(uint8(roleInst), uint8(DigitalIdentityRegistry.Role.RESEARCHER)); // Same checkings.
        assertTrue(isRegisteredInst); // Same checkings.
    }

    function test_RegisterResearcherUnauthorized() public { // Same logic for a stranger trying to register an entity.
        vm.prank(stranger);
        vm.expectRevert(bytes("Only owner or institute"));
        registry.registerResearcher(researcher, keccak256("res1"));
    }

    function test_RegisterInsuranceOnlyOwner() public { //Same checking, but this time msg.sender is owner.
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

    function test_RegisterInsuranceNonOwner() public { // Same stranger logic.
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

    function test_GetPatientNonDoctor() public { // A stranger tries to look into details of a result or data of a patient.
        bytes32 hashId = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashId);

        vm.prank(stranger);
        vm.expectRevert(bytes("Only doctor"));
        registry.getPatient(patient); // this line should revert since the msg.sender is stranger.
    }

    function test_GetStaffOnlyOwnerAndNotPatient() public { // only owner is allowed see staff members.
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

    function test_GetStaffNonOwner() public { // Try to get staff as non owner person
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        vm.prank(stranger);
        vm.expectRevert(bytes("Only owner"));
        registry.getStaff(doc);
    }

    function test_GetStaffOnPatient() public { // Owner tries to see a detail of a person
        bytes32 hashIdP = keccak256("patient1");

        vm.prank(patient);
        registry.registerPatient(hashIdP);

        vm.prank(owner);
        vm.expectRevert(bytes("What you do is illegal!"));
        registry.getStaff(patient);
    }

    function test_UpdateUserAddress() public { // To check if the updateUserAddress correctly works. It is designed to give a new address based 
                                               // on the internalId of an entity..
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc); // We register a doctor and change its address afterwards. (This is the goal at least :D)

        (
            uint256 internalId,
            ,
            ,
            ,
            bool isRegistered
        ) = registry.users(doc); 

        assertTrue(isRegistered);

        vm.prank(owner); // Same msg.sender settings
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
        assertEq(uint8(role), uint8(DigitalIdentityRegistry.Role.DOCTOR)); //Checking the attributes of the new registry. (Same doc new address)
        assertEq(storedHashId, hashIdDoc);
        assertTrue(newIsRegistered); 

        (
            ,
            ,
            ,
            ,
            bool oldIsRegistered
        ) = registry.users(doc);
        assertFalse(oldIsRegistered); // old address should be seen as not registered since new address is given to the doc. (The update address method
                                      // deletes all old data from the users mapping. It doesn't delet it just sets tthe values to the default values.

        address mappedAddr = registry.internalIdToAddress(internalId);
        assertEq(mappedAddr, newAddr);
    }

    function test_UpdateUserAddressRevertsForUnknownId() public {
        vm.prank(owner);
        vm.expectRevert(bytes("Unknown internalId")); // If an internal id does not exists then we shouldn't be able to assign a new address to that id.
        registry.updateUserAddress(999, newAddr);
    }

    function test_UpdateUserAddressRevertsForZeroAddress() public { // New address needs to be an actual address
        bytes32 hashIdDoc = keccak256("doc1");

        vm.prank(owner);
        registry.registerDoctor(doc, hashIdDoc);

        (uint256 internalId, , , , ) = registry.users(doc);

        vm.prank(owner);
        vm.expectRevert(bytes("Invalid new address"));
        registry.updateUserAddress(internalId, address(0));
    }

    function test_UpdateUserAddressRevertsIfNewAlreadyRegistered() public { // New address shouldn't be registered before.
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
