// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract DigitalIdentityRegistry {

    enum Role { NONE, PATIENT, DOCTOR, RESEARCHER, INSURANCE }

    struct User {
        address userAddress;
        Role role;
        bytes32 hashID;
        bool isRegistered;
    }

    mapping(address => User) public users;

    event UserRegistered(address user, Role role);

    function registerPatient(bytes32 _hashID) external {
        users[msg.sender] = User(msg.sender, Role.PATIENT, _hashID, true);
        emit UserRegistered(msg.sender, Role.PATIENT);
    }

    function registerDoctor(bytes32 _hashID) external {
        users[msg.sender] = User(msg.sender, Role.DOCTOR, _hashID, true);
        emit UserRegistered(msg.sender, Role.DOCTOR);
    }

    function getUser(address _addr) external view returns (User memory) {
        return users[_addr];
    }
}
