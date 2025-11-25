// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract OrganizationRegistry {

    struct Organization {
        bytes32 nameHash;
        string countryCode;
        address admin;
        bool isActive;
    }

    mapping(uint256 => Organization) public organizations;
    uint256 public orgCount;

    event OrganizationRegistered(uint256 orgId, address admin);
    event OrgStatusUpdated(uint256 orgId, bool isActive);

    function registerOrganization(bytes32 _nameHash, string memory _countryCode, address _admin) external {
        orgCount++;
        organizations[orgCount] = Organization(_nameHash, _countryCode, _admin, true);
        emit OrganizationRegistered(orgCount, _admin);
    }

    function setOrgStatus(uint256 orgId, bool _status) external {
        require(organizations[orgId].admin == msg.sender, "Not org admin");
        organizations[orgId].isActive = _status;
        emit OrgStatusUpdated(orgId, _status);
    }
}
