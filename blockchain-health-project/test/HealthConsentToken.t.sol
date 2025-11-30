// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../contracts/HealthConsentToken.sol";

contract HealthConsentTokenTest is Test {
    HealthConsentToken token;

    address patient1 = address(0x1);
    address patient2 = address(0x2);

    function setUp() public {
        token = new HealthConsentToken();
    }

        // reward = durationDays *10*(dataType + 1) testing
    function test_mintFormula() public {
        uint8 dataType = 1;
        uint256 durationDays = 7;
        uint256 expected = durationDays * 10 * (dataType + 1);

        token.mintForConsent(patient1, dataType, durationDays);

        uint256 bal = token.balanceOf(patient1);
        assertEq(bal, expected);
    }

    function test_mintAccumulates() public {
        token.mintForConsent(patient1, 1, 5); //100
        token.mintForConsent(patient1, 2, 3); // 90

        uint256 bal = token.balanceOf(patient1);
        assertEq(bal, 190); // toplam 190
    }

    function test_mintSeparatePatients() public {
        token.mintForConsent(patient1, 1, 5); // 100
        token.mintForConsent(patient2, 1, 5); // 100

        uint256 bal1 = token.balanceOf(patient1);
        uint256 bal2 = token.balanceOf(patient2);

        assertEq(bal1, 100);
        assertEq(bal2, 100);
    }

    function test_zeroDuration() public {
        // durationDays = 0 → reward = 0
        token.mintForConsent(patient1, 1, 0);

        uint256 bal = token.balanceOf(patient1);
        assertEq(bal, 0);
    }

    function test_eventEmit() public {
        uint8 dataType = 1;
        uint256 durationDays = 7;
        uint256 expected = durationDays * 10 * (dataType + 1);

        vm.expectEmit(true, false, false, true);
        emit HealthConsentToken.TokensMinted(patient1, expected);

        token.mintForConsent(patient1, dataType, durationDays);
    }
}
