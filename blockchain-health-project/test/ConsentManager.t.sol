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
        // Grant consent as the patient for (requester, dataType=1) for 7 days
        vm.prank(patient); // Set msg.sender = patient for the next call.
        consent.setConsent(requester, 1, 7);

        (
            address storedPatient,
            address storedRequester,
            uint8 storedDataType,
            uint256 startTime,
            uint256 endTime,
            bool active
        ) = consent.consents(patient, requester);

        // Verify: consent mapping stores the expected values
        assertEq(storedPatient, patient);
        assertEq(storedRequester, requester);
        assertEq(storedDataType, 1);
        assertTrue(active);
        assertGt(endTime, startTime); // End time should be in the future relative to start time

        // Check validity for the exact (patient, requester, dataType)
        bool valid = consent.hasValidConsent(patient, requester, 1);
        assertTrue(valid);
    }

    function test_ConsentExpiry() public {
        // Grant a short-lived consent (1 day)
        vm.prank(patient);
        consent.setConsent(requester, 1, 1);

        // Move time forward beyond endTime so the consent expires
        vm.warp(block.timestamp + 2 days);

        // Now the consent should be invalid due to expiry
        bool valid = consent.hasValidConsent(patient, requester, 1);
        assertFalse(valid);
    }

    function test_RevokeConsent() public {
        // Grant a consent and then revoke it
        vm.prank(patient);
        consent.setConsent(requester, 1, 5);

        bool beforeRevoke = consent.hasValidConsent(patient, requester, 1);
        assertTrue(beforeRevoke); // Should be valid before revocation

        vm.prank(patient);
        consent.revokeConsent(requester);

        bool afterRevoke = consent.hasValidConsent(patient, requester, 1);
        assertFalse(afterRevoke); // Revocation should make it invalid
    }

    function test_DiffDataType() public {
        // Grant consent for dataType=1 and verify it does NOT apply to dataType=2
        vm.prank(patient);
        consent.setConsent(requester, 1, 7);

        bool valid = consent.hasValidConsent(patient, requester, 2);
        assertFalse(valid); // Different dataType should not be valid
    }

    function test_SetConsentEmitsEvent() public {
        // Expect the ConsentGranted event with patient and requester indexed
        vm.prank(patient);
        vm.expectEmit(true, true, false, true);
        emit ConsentManager.ConsentGranted(patient, requester, 1);

        consent.setConsent(requester, 1, 7);
    }

    function test_RevokeConsentEmitsEvent() public {
        // Grant first, then expect and trigger ConsentRevoked
        vm.prank(patient);
        consent.setConsent(requester, 1, 7);

        vm.prank(patient);
        vm.expectEmit(true, true, false, false);
        emit ConsentManager.ConsentRevoked(patient, requester);

        consent.revokeConsent(requester);
    }
}
