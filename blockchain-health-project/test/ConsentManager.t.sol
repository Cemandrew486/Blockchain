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
        // Mock data. These could be also set as constants for gas efficiency. (But since these are justs test they should be run just once.)
        uint8 dataType = 1;
        uint32 dataVersion = 1;
        uint256 durationDays = 7;

        // Grant consent as the patient
        vm.prank(patient); // Set msg.sender = patient for the next call.
        consent.setConsent(requester, dataType, dataVersion, durationDays);

        (
            address storedPatient,
            address storedRequester,
            uint8 storedDataType,
            uint32 storedDataVersion,
            uint256 startTime,
            uint256 endTime,
            bool active
        ) = consent.consents(patient, requester);

        //  Evaluate the stored fields
        assertEq(storedPatient, patient);
        assertEq(storedRequester, requester);
        assertEq(storedDataType, dataType);
        assertEq(storedDataVersion, dataVersion);
        assertTrue(active);
        assertGt(endTime, startTime); // End time should be after start time (These are numbers, like 176590 > 173452)

        // Valid for the exact (patient, requester, dataType, dataVersion)
        bool validExact = consent.hasValidConsent(patient, requester, dataType, dataVersion);
        assertTrue(validExact);

        // INVALID for same dataType but different version
        dataVersion += 1;
        bool validWrongVersion = consent.hasValidConsent(patient, requester, dataType, dataVersion);
        assertFalse(validWrongVersion);
    }

    function test_ConsentExpiry() public {
        uint8 dataType = 1;
        uint32 dataVersion = 1;

        // Grant a short-lived consent (1 day) 
        vm.prank(patient);
        consent.setConsent(requester, dataType, dataVersion, 1);

        // Should be valid immediately
        bool validNow = consent.hasValidConsent(patient, requester, dataType, dataVersion);
        assertTrue(validNow);

        // Move time forward beyond endTime so the consent expires
        vm.warp(block.timestamp + 2 days);

        // Now the consent should be invalid due to expiry
        bool validAfter = consent.hasValidConsent(patient, requester, dataType, dataVersion);
        assertFalse(validAfter);
    }

    function test_RevokeConsent() public {
        // In consent manager when we revoke the permission, we revoke for all but this test specifically revokes for 
        // given data version, and datatype. This could be also done in consent manager but the reasoning changes from one to one.
        uint8 dataType = 1;
        uint32 dataVersion = 1;

        // Grant a consent and then revoke it
        vm.prank(patient);
        consent.setConsent(requester, dataType, dataVersion, 5);

        bool beforeRevoke = consent.hasValidConsent(patient, requester, dataType, dataVersion);
        assertTrue(beforeRevoke); // Should be valid before revocation

        vm.prank(patient);
        consent.revokeConsent(requester);

        bool afterRevoke = consent.hasValidConsent(patient, requester, dataType, dataVersion);
        assertFalse(afterRevoke); // Revocation should make it invalid

        // Also check that 'active' flag is false in storage
        (
            ,
            , //Same structure in other tests, we  ignore those data.
            ,
            ,
            ,
            ,
            bool active
        ) = consent.consents(patient, requester);

        assertFalse(active);
    }

    function test_DiffDataType() public {
        uint8 dataType = 1;
        uint32 dataVersion = 1;

        // Grant consent for dataType=1, dataVersion=1
        vm.prank(patient);
        consent.setConsent(requester, dataType, dataVersion, 7);

        // Different dataType should not be valid
        bool validDifferentType = consent.hasValidConsent(patient, requester, 2, dataVersion);
        assertFalse(validDifferentType);

        // Same type, different version should also not be valid
        bool validDifferentVersion = consent.hasValidConsent(patient, requester, dataType, dataVersion + 1);
        assertFalse(validDifferentVersion);
    }

    function test_SetConsentEmitsEvent() public {
        uint8 dataType = 1;
        uint32 dataVersion = 1;

        vm.prank(patient);
        vm.expectEmit(true, true, false, true); // Expect matching
        emit ConsentManager.ConsentGranted(patient, requester, dataType, dataVersion);

        consent.setConsent(requester, dataType, dataVersion, 7);
    }

    function test_RevokeConsentEmitsEvent() public {
        uint8 dataType = 1;
        uint32 dataVersion = 1;

        // Grant first, then expect and trigger ConsentRevoked
        vm.prank(patient);
        consent.setConsent(requester, dataType, dataVersion, 7);

        vm.prank(patient);
        vm.expectEmit(true, true, false, false);
        emit ConsentManager.ConsentRevoked(patient, requester);

        consent.revokeConsent(requester);
    }
}
