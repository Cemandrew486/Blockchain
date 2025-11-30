// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/ConsentManager.sol";

contract ConsentManagerTest is Test {
    ConsentManager consent;

    address patient = address(0x1);
    address requester = address(0x2);

    function setUp() public {
        consent = new ConsentManager();
    }

    function test_SetConsentStoresConsentAndIsValid() public {
        vm.prank(patient);
        consent.setConsent(requester, 1, 1, 7);

        (
            address storedPatient,
            address storedRequester,
            uint8 storedDataType,
            uint8 storedPurpose,
            uint256 startTime,
            uint256 endTime,
            bool active
        ) = consent.consents(patient, requester);

        assertEq(storedPatient, patient);
        assertEq(storedRequester, requester);
        assertEq(storedDataType, 1);
        assertEq(storedPurpose, 1);
        assertTrue(active);
        assertGt(endTime, startTime);

        bool valid = consent.hasValidConsent(patient, requester, 1, 1);
        assertTrue(valid);
    }

    function test_ConsentExpiry() public {
        vm.prank(patient);
        consent.setConsent(requester, 1, 1, 1);

        vm.warp(block.timestamp + 2 days);

        bool valid = consent.hasValidConsent(patient, requester, 1, 1);
        assertFalse(valid);
    }

    function test_RevokeConsent() public {
        vm.prank(patient);
        consent.setConsent(requester, 1, 1, 5);

        bool beforeRevoke = consent.hasValidConsent(patient, requester, 1, 1);
        assertTrue(beforeRevoke);

        vm.prank(patient);
        consent.revokeConsent(requester);

        bool afterRevoke = consent.hasValidConsent(patient, requester, 1, 1);
        assertFalse(afterRevoke);
    }

    function test_DiffDataType() public { // consent different data type
        vm.prank(patient);
        consent.setConsent(requester, 1, 1, 7);

        bool valid = consent.hasValidConsent(patient, requester, 2, 1);
        assertFalse(valid);
    }

    function test_DiffPurpose() public { // consent different purpose
        vm.prank(patient);
        consent.setConsent(requester, 1, 1, 7);

        bool valid = consent.hasValidConsent(patient, requester, 1, 2);
        assertFalse(valid);
    }

    function test_SetConsentEmitsEvent() public {
        vm.prank(patient);
        vm.expectEmit(true, true, false, true);
        emit ConsentManager.ConsentGranted(patient, requester, 1);

        consent.setConsent(requester, 1, 1, 7);
    }

    function test_RevokeConsentEmitsEvent() public {
        vm.prank(patient);
        consent.setConsent(requester, 1, 1, 7);

        vm.prank(patient);
        vm.expectEmit(true, true, false, false);
        emit ConsentManager.ConsentRevoked(patient, requester);

        consent.revokeConsent(requester);
    }
}
