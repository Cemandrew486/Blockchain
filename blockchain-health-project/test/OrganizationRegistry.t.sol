// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";          
import "../contracts/OrganizationRegistry.sol";

// Unit tests for OrganizationRegistry
contract OrganizationRegistryTest is Test {
    OrganizationRegistry org;
    address systemAdmin = address(this);

    /// Helper to compare addresses using assert (it has no address overload)
    function assertEqAddress(
        address a,
        address b,
        string memory message
    ) pure internal  {
        assertEq(
            bytes32(uint256(uint160(a))), // First cast into 160 because ethereum addresses are 160 bit long
                                          // Then cast it into 256 bit because assert eq supports it and solidity cannot
                                          // directly cast address -> uint256. This is for safety. 
            bytes32(uint256(uint160(b))),
            message
        );
    }

       /// Runs before each test
    function setUp() public {
        // Deploy the contract; this test contract acts as systemAdmin
        org = new OrganizationRegistry(systemAdmin);
    }


    /// 1) systemAdmin must be set correctly at deployment
    function test_checkSystemAdminIsSet() public view {
        assertEqAddress(
            org.systemAdmin(),
            systemAdmin,
            "systemAdmin should be the deployer (test contract)"
        );
    }

    /// 2) First registration should store org data and return orgId = 1
    function test_checkRegisterOrganizationStoresData() public {
        bytes32 hashName = keccak256(abi.encodePacked("Hospital One"));
        string memory countryCode = "NL";
        address adminAddr = address(0x123);

        uint256 orgId = org.registerOrganization(hashName, countryCode, adminAddr);
        assertEq(orgId, uint256(1), "First orgId should be 1");

        (
            bytes32 storedHash,
            string memory storedCountry,
            address storedAdmin,
            bool isActive
        ) = org.getOrganization(1);

        assertEq(storedHash, hashName, "hashName mismatch");
        assertEq(storedCountry, countryCode, "countryCode mismatch");
        assertEqAddress(storedAdmin, adminAddr, "admin address mismatch");
        assertTrue(isActive, "Organization should be active after registration");

        uint256 mappedId = org.getOrgIdForAdmin(adminAddr);
        assertEq(mappedId, uint256(1), "adminToOrgId should map admin to orgId = 1");
    }

    /// 3) setOrgStatus should toggle isActive
    function test_checkSetOrgStatusTogglesActive() public {
        // Register an organization first
        bytes32 hashName = keccak256(abi.encodePacked("Org1"));
        string memory countryCode = "TR";
        address adminAddr = address(0x123);

        org.registerOrganization(hashName, countryCode, adminAddr);
        // Disable org 1 and verify
        org.setOrgStatus(1, false);
        bool activeAfterDisable = org.isActiveOrganization(1);
        assertFalse(activeAfterDisable, "Org should be inactive after setOrgStatus(false)");

        // Enable again and verify
        org.setOrgStatus(1, true);
        bool activeAfterEnable = org.isActiveOrganization(1);
        assertTrue(activeAfterEnable, "Org should be active after setOrgStatus(true)");
    }

    /// 4) updateOrganizationAdmin should move admin mapping correctly
    function test_checkUpdateOrganizationAdmin() public {
        address oldAdmin = address(0x123);
        address newAdmin = address(0x456);

        bytes32 hashName = keccak256(abi.encodePacked("Org1"));
        org.registerOrganization(hashName, "NL", oldAdmin);

        // Update the admin and verify mapping changes
        org.updateOrganizationAdmin(1, newAdmin);

        (
            ,
            ,
            address storedAdmin,
            /*bool isActive*/
        ) = org.getOrganization(1);
        assertEqAddress(storedAdmin, newAdmin, "Admin not updated in organization struct");

        uint256 newAdminOrgId = org.getOrgIdForAdmin(newAdmin);
        assertEq(newAdminOrgId, uint256(1), "newAdmin should map to orgId 1");

        uint256 oldAdminOrgId = org.getOrgIdForAdmin(oldAdmin);
        assertEq(oldAdminOrgId, uint256(0), "oldAdmin should no longer map to an org");
    }

    /// 5) Second organization with same admin must revert ("Admin already linked")
    function test_checkDuplicateAdminReverts() public {
        OrganizationRegistry localOrg = new OrganizationRegistry(systemAdmin);
        address adminAddr = address(0xABC);

        bytes32 hash1 = keccak256(abi.encodePacked("OrgA"));
        bytes32 hash2 = keccak256(abi.encodePacked("OrgB"));

        // First registration OK
        localOrg.registerOrganization(hash1, "DE", adminAddr);

        // Second registration with same admin must revert
        try localOrg.registerOrganization(hash2, "FR", adminAddr) {
            assertTrue(false, "Second registration with same admin should have reverted");
        } catch Error(string memory reason) {
            // Require message from contract is "Admin already linked"
            assertEq(reason, "Admin already linked", "Wrong revert reason");
        } catch (bytes memory /*lowLevelData*/) {
            assertTrue(false, "Expected revert with reason string");
        }
    }
}
