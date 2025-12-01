// SPDX-License-Identifier: MIT
//npx hardhat test

pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import "../contracts/ConsentManager.sol";
import "../contracts/DataRegistry.sol";
import "../contracts/AccessController.sol";
import "../contracts/DigitalIdentityRegistry.sol";

contract IntegrationTest is Test {

    ConsentManager consent;
    DataRegistry dataRegistry;
    AccessController access;
    DigitalIdentityRegistry identity;

    address patient = address(0x1);
    address requester = address(0x2);
    address doctor = address(0x3);
    address institute = address(0x4);

    function setUp() public {
        vm.startPrank(institute);

        consent = new ConsentManager();
        dataRegistry = new DataRegistry();
        access = new AccessController(address(consent), address(dataRegistry));
        identity = new DigitalIdentityRegistry(institute, doctor);

        vm.stopPrank();
    }

    function test_FullUserWorkflow() public {

        vm.prank(patient);
        identity.registerPatient(keccak256("patient"));

        vm.prank(patient);
        consent.setConsent(requester, 1, 7);

        vm.prank(patient);
        dataRegistry.setDataPointer(1, keccak256("DATA"));

        vm.prank(requester);
        (bytes32 hash,,) = access.accessData(patient, 1);
        assertEq(hash, keccak256("DATA"));

        vm.prank(patient);
        consent.revokeConsent(requester);

        vm.prank(requester);
        (bytes32 denied,,) = access.accessData(patient, 1);
        assertEq(denied, bytes32(0));
    }
}
