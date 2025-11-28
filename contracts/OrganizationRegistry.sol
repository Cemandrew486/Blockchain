// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract OrganizationRegistry {
    // Only this address can add or update organisations
    address public systemAdmin;

    uint256 private orgCounter;

    struct Organization {
        uint256 orgId;        // numeric id
        bytes32 hashName;     
        string countryCode;   // e.g. "NL", "DE"
        address admin;        // Org admin address 
        bool isActive;        
        // Only active orgs may onboard staff
    }

    mapping(uint256 => Organization) public organizations;

    mapping(address => uint256) public adminToOrgId;

    // events 
    event OrganizationRegistered(
        uint256 indexed orgId,
        bytes32 indexed hashName,
        string countryCode,
        address indexed admin
    );

    event OrganizationStatusUpdated(
        uint256 indexed orgId,
        bool isActive
    );

    event OrganizationAdminUpdated(
        uint256 indexed orgId,
        address indexed oldAdmin,
        address indexed newAdmin
    );

    //modifier
    modifier onlySystemAdmin() {
        require(msg.sender == systemAdmin, "Only system admin");
        _;
    }

    // Constructor sets the global system admin
    // In many setups this will simply be the deployer
    constructor(address _systemAdmin) {
        require(_systemAdmin != address(0), "Invalid admin");
        systemAdmin = _systemAdmin;
    }

    // register a new organisation
    function registerOrganization(
        bytes32 hashName,
        string calldata countryCode,
        address adminAddr
    ) external onlySystemAdmin returns (uint256 orgId) {
        require(hashName != bytes32(0), "Empty name hash");
        require(adminAddr != address(0), "Invalid admin address");
        require(adminToOrgId[adminAddr] == 0, "Admin already linked");

        orgCounter += 1;
        orgId = orgCounter;

        organizations[orgId] = Organization({
            orgId: orgId,
            hashName: hashName,
            countryCode: countryCode,
            admin: adminAddr,
            isActive: true
        });

        adminToOrgId[adminAddr] = orgId;

        emit OrganizationRegistered(orgId, hashName, countryCode, adminAddr);
    }

    // Enable or disable an existing organisation
    function setOrgStatus(uint256 orgId, bool status) external onlySystemAdmin {
        Organization storage org = organizations[orgId];
        require(org.orgId != 0, "Unknown organization");

        org.isActive = status;
        emit OrganizationStatusUpdated(orgId, status);
    }

    // Return the main fields for an organisation in one call
    function getOrganization(
        uint256 orgId
    )
        external
        view
        returns (
            bytes32 hashName,
            string memory countryCode,
            address admin,
            bool isActive
        )
    {
        Organization storage org = organizations[orgId];
        require(org.orgId != 0, "Unknown organization");

        return (org.hashName, org.countryCode, org.admin, org.isActive);
    }

    // Check if an organisation exists and is currently active
    function isActiveOrganization(uint256 orgId) external view returns (bool) {
        Organization storage org = organizations[orgId];
        return org.orgId != 0 && org.isActive;
    }

    // Look up which organisation an admin address belongs to
    // returns 0 if the address is not an organisation admin
    function getOrgIdForAdmin(address adminAddr) external view returns (uint256) {
        return adminToOrgId[adminAddr];
    }

    // change the admin address for a given organisation
    // useful if an org changes its on-chain admin wallet without losing its orgId and stored data
    function updateOrganizationAdmin(
        uint256 orgId,
        address newAdmin
    ) external onlySystemAdmin {
        require(newAdmin != address(0), "Invalid new admin");

        Organization storage org = organizations[orgId];
        require(org.orgId != 0, "Unknown organization");

        // clear mapping for the old admin if there was one.
        address oldAdmin = org.admin;
        if (oldAdmin != address(0)) {
            adminToOrgId[oldAdmin] = 0;
        }
        // set the new admin
        org.admin = newAdmin;
        adminToOrgId[newAdmin] = orgId;

        emit OrganizationAdminUpdated(orgId, oldAdmin, newAdmin);
    }
}
