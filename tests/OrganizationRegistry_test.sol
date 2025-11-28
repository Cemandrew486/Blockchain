// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "remix_tests.sol";              // Remix test helpers
import "../contracts/OrganizationRegistry.sol";

// Unit tests for OrganizationRegistry
contract OrganizationRegistryTest {
    OrganizationRegistry org;
    address systemAdmin = address(this);

    /// Helper to compare addresses using Assert (it has no address overload)
    function assertEqAddress(
        address a,
        address b,
        string memory message
    ) internal {
        Assert.equal(
            bytes32(uint256(uint160(a))),
            bytes32(uint256(uint160(b))),
            message
        );
    }

    /// Runs once before all tests
    function beforeAll() public {
        // Deploy the contract; this test contract acts as systemAdmin
        org = new OrganizationRegistry(systemAdmin);
    }

    /// 1) systemAdmin must be set correctly at deployment
    function checkSystemAdminIsSet() public {
        assertEqAddress(
            org.systemAdmin(),
            systemAdmin,
            "systemAdmin should be the deployer (test contract)"
        );
    }

    /// 2) First registration should store org data and return orgId = 1
    function checkRegisterOrganizationStoresData() public {
        bytes32 hashName = keccak256(abi.encodePacked("Hospital One"));
        string memory countryCode = "NL";
        address adminAddr = address(0x123);

        uint256 orgId = org.registerOrganization(hashName, countryCode, adminAddr);
        Assert.equal(orgId, uint256(1), "First orgId should be 1");

        (
            bytes32 storedHash,
            string memory storedCountry,
            address storedAdmin,
            bool isActive
        ) = org.getOrganization(1);

        Assert.equal(storedHash, hashName, "hashName mismatch");
        Assert.equal(storedCountry, countryCode, "countryCode mismatch");
        assertEqAddress(storedAdmin, adminAddr, "admin address mismatch");
        Assert.ok(isActive, "Organization should be active after registration");

        uint256 mappedId = org.getOrgIdForAdmin(adminAddr);
        Assert.equal(mappedId, uint256(1), "adminToOrgId should map admin to orgId = 1");
    }

    /// 3) setOrgStatus should toggle isActive
    function checkSetOrgStatusTogglesActive() public {
        // Disable org 1
        org.setOrgStatus(1, false);
        bool activeAfterDisable = org.isActiveOrganization(1);
        Assert.ok(!activeAfterDisable, "Org should be inactive after setOrgStatus(false)");

        // Enable again
        org.setOrgStatus(1, true);
        bool activeAfterEnable = org.isActiveOrganization(1);
        Assert.ok(activeAfterEnable, "Org should be active after setOrgStatus(true)");
    }

    /// 4) updateOrganizationAdmin should move admin mapping correctly
    function checkUpdateOrganizationAdmin() public {
        address oldAdmin = address(0x123);
        address newAdmin = address(0x456);

        // Precondition: org 1 exists from earlier tests
        org.updateOrganizationAdmin(1, newAdmin);

        (
            ,
            ,
            address storedAdmin,
            /*bool isActive*/
        ) = org.getOrganization(1);
        assertEqAddress(storedAdmin, newAdmin, "Admin not updated in organization struct");

        uint256 newAdminOrgId = org.getOrgIdForAdmin(newAdmin);
        Assert.equal(newAdminOrgId, uint256(1), "newAdmin should map to orgId 1");

        uint256 oldAdminOrgId = org.getOrgIdForAdmin(oldAdmin);
        Assert.equal(oldAdminOrgId, uint256(0), "oldAdmin should no longer map to an org");
    }

    /// 5) Second organization with same admin must revert ("Admin already linked")
    function checkDuplicateAdminReverts() public {
        OrganizationRegistry localOrg = new OrganizationRegistry(systemAdmin);
        address adminAddr = address(0xABC);

        bytes32 hash1 = keccak256(abi.encodePacked("OrgA"));
        bytes32 hash2 = keccak256(abi.encodePacked("OrgB"));

        // First registration OK
        localOrg.registerOrganization(hash1, "DE", adminAddr);

        // Second registration with same admin must revert
        try localOrg.registerOrganization(hash2, "FR", adminAddr) {
            Assert.ok(false, "Second registration with same admin should have reverted");
        } catch Error(string memory reason) {
            // Require message from contract is "Admin already linked"
            Assert.equal(reason, "Admin already linked", "Wrong revert reason");
        } catch (bytes memory /*lowLevelData*/) {
            Assert.ok(false, "Expected revert with reason string");
        }
    }
}
