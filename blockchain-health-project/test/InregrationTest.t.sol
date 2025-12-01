// SPDX-License-Identifier: MIT
// This integration test exercises the happy path across multiple contracts.

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
        // Deploy all contracts as the institute account
        vm.startPrank(institute);

        consent = new ConsentManager();
        dataRegistry = new DataRegistry();
        access = new AccessController(address(consent), address(dataRegistry));
        identity = new DigitalIdentityRegistry(institute, doctor);

        vm.stopPrank(); // Stop impersonating
    }

    function test_FullUserWorkflow() public {
        // 1) Patient self-registers in the identity registry (stores hashId and marks as registered)
        vm.prank(patient);
        identity.registerPatient(keccak256("patient"));

        // 2) Patient grants consent to requester for dataType=1 for 7 days
        vm.prank(patient);
        consent.setConsent(requester, 1, 7);

        // 3) Patient registers an off-chain data pointer (represented by the keccak256 hash)
        vm.prank(patient);
        dataRegistry.setDataPointer(1, keccak256("DATA"));

        // 4) Requester accesses patient's latest data for dataType=1 (should succeed)
        vm.prank(requester);
        (bytes32 hash,,) = access.accessData(patient, 1);
        assertEq(hash, keccak256("DATA"));

        // 5) Patient revokes consent, invalidating future access attempts
        vm.prank(patient);
        consent.revokeConsent(requester);

        // 6) Requester tries again but now access is denied (returns empty tuple)
        vm.prank(requester);
        (bytes32 denied,,) = access.accessData(patient, 1);
        assertEq(denied, bytes32(0));
    }
}
