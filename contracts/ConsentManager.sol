// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract ConsentManager {

    struct Consent {
        address patient;
        address requester;
        uint8 dataType;
        uint8 purpose;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    mapping(address => mapping(address => Consent)) public consents;

    event ConsentGranted(address patient, address requester, uint8 dataType);
    event ConsentRevoked(address patient, address requester);

    function setConsent(address _requester, uint8 _dataType, uint8 _purpose, uint256 _durationDays) external {
        uint256 endTime = block.timestamp + (_durationDays * 1 days);
        consents[msg.sender][_requester] = Consent(msg.sender, _requester, _dataType, _purpose, block.timestamp, endTime, true);
        emit ConsentGranted(msg.sender, _requester, _dataType);
    }

    function revokeConsent(address _requester) external {
        consents[msg.sender][_requester].active = false;
        emit ConsentRevoked(msg.sender, _requester);
    }

    function hasValidConsent(address patient, address requester, uint8 dataType, uint8 purpose) 
        external view returns (bool) 
    {
        Consent memory c = consents[patient][requester];

        return (c.active && block.timestamp < c.endTime && c.dataType == dataType && c.purpose == purpose);
    }
}
