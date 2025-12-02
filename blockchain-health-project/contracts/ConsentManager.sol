// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract ConsentManager {

    struct Consent {
        address patient;
        address requester;
        uint8 dataType;
        uint32 dataVersion;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }
    // Ahmetin adresi doktora izin vermekte
    mapping(address => mapping(address => Consent)) public consents;

    event ConsentGranted(address patient, address requester, uint8 dataType, uint32 dataVersion );
    event ConsentRevoked(address patient, address requester);

    function setConsent(address _requester, uint8 _dataType, uint32 _dataVersion, uint256 _durationDays) external {
        uint256 endTime = block.timestamp + (_durationDays * 1 days);
        consents[msg.sender][_requester] = Consent(msg.sender, _requester, _dataType, _dataVersion,  block.timestamp, endTime, true);
        emit ConsentGranted(msg.sender, _requester, _dataType, _dataVersion);
    }

    function revokeConsent(address _requester) external { // Revoking consent will revoke all the consent, not just for one version or specific type                                                  
        consents[msg.sender][_requester].active = false;
        emit ConsentRevoked(msg.sender, _requester);
    }

    function hasValidConsent(address _patient, address _requester, uint8 _dataType, uint32 _dataVersion) 
        external view returns (bool) 
    {
        Consent memory c = consents[_patient][_requester];

        return (c.active && block.timestamp < c.endTime && c.dataType == _dataType && c.dataVersion == _dataVersion);
    }
}
