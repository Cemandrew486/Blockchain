// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract DigitalIdentityRegistry {
    // High-level roles in the system
    enum Role { NONE, PATIENT, DOCTOR, RESEARCHER, INSURANCE, SPECIALIST }

    uint256 private internalIdCounter;
    

    struct User {
        uint256 internalId;
        address userAddress;
        Role role;
        bytes32 hashId;     // Hashed identifier, keccak256(email + medicalId for patients and licenseId or workEmail for staff )
        bool isRegistered;
        // All other sensitive attributes (name, surname, age, description) are handled off-chain
    }

    address public owner;                // System / hospital admin, head doctor or someone who literally owns the hospital
    address public instituteResearcher;  // research institute admin (We assume this guy is chosen by the owner)
    address public doctor; 

    mapping(address => User) public users;
    mapping(uint256 => address) public internalIdToAddress;


    event UserRegistered(address indexed user, Role role, bytes32 hashId);
    event UserAddressUpdated(uint256 internalId, address oldAddress, address newAddress);

    constructor(address _instituteResearcher, address _doctor) {
        owner = msg.sender;                     // Deployer is system owner
        instituteResearcher = _instituteResearcher;
        doctor = _doctor;
    }

    //Modifiers start
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyOwnerOrInstitute() {
        require(msg.sender == owner || msg.sender == instituteResearcher, "Only owner or institute");
        _;
    }

    modifier onlyDoctor(){
        require (msg.sender == doctor, "Violating hippocratic oath is not allowed");
        _;
    }
    //Modifiers end

    // To register people
    function _register(
        address account,
        Role role,
        bytes32 hashId
    ) internal {
        require(!users[account].isRegistered, "User already registered");
        internalIdCounter += 1;
        uint256 newId = internalIdCounter;

        users[account] = User({
            internalId: newId,
            userAddress: account,
            role: role,
            hashId: hashId,
            isRegistered: true
        });

        internalIdToAddress[newId] = account;

        emit UserRegistered(account, role, hashId);
    }

    // Patients register themselves (This can be done through a small kiosk with a good ui interface in hospitals in real life)
    // hashId = web3.utils.keccak256(email + medicalId) done off-chain(the chain will only see the hash but off chain we should be able to see email + medicalId)
    function registerPatient(
        bytes32 hashId
        // name, surname, age, shortDescription are handled off-chain and NOT sent on-chain for privacy
    ) external {
        _register(msg.sender, Role.PATIENT, hashId);
    }

    // Owner registers doctors (e.g. hospital admin, head doctor or someone who literally owns the hospital)
    // doctorAddress: Ethereum address of the doctor
    // hashId: web3.utils.keccak256(licenseId or workEmail)
    function registerDoctor(
        address doctorAddress,
        bytes32 hashId
        // name, surname, age are handled off-chain
    ) external onlyOwner {
        _register(doctorAddress, Role.DOCTOR, hashId);
    }

    // Owner or research institute registers researchers
    // researcherAddress: Ethereum address of the researcher
    function registerResearcher(
        address researcherAddress,
        bytes32 hashId
        // name, surname, age are handled off-chain
    ) external onlyOwnerOrInstitute {
        _register(researcherAddress, Role.RESEARCHER, hashId);
    }

    // Owner registers insurance employees
    // employeeAddress: Ethereum address of the insurance employee
    function registerInsurance(
        address employeeAddress,
        bytes32 hashId
        // name, surname, age are handled off-chain
    ) external onlyOwner {
        _register(employeeAddress, Role.INSURANCE, hashId);
    }

    //To make it more readable the desired result
    function getPatient(address account) external onlyDoctor view returns (
        address userAddress,
        Role role,
        bytes32 hashId,
        bool isRegistered,
        uint256 internalId
    )  {
        User memory u = users[account];
        require(u.role == Role.PATIENT, "This is only for looking patients");

        return (
            u.userAddress,
            u.role,
            u.hashId,
            u.isRegistered,
            u.internalId // For off chain hashing / linking to medical record
        );
    }

    //To make it more readable the desired result (Allow only doctors to make sure that the hippocratic oath is not violated)
    function getStaff(address account) external onlyOwner view returns (
        address userAddress,
        Role role,
        bytes32 hashId,
        bool isRegistered,
        uint256 internalId
    ){
        User memory u = users[account];
        require(u.role != Role.PATIENT, "What you do is illegal!");

        return (
            u.userAddress,
            u.role,
            u.hashId,
            u.isRegistered,
            u.internalId
        );
    }

    function updateUserAddress(uint256 internalId, address newAddress) external onlyOwner {
    require(newAddress != address(0), "Invalid new address");
    
    // Find current address for this internalId
    address currentAddress = internalIdToAddress[internalId];
    require(currentAddress != address(0), "Unknown internalId");

    // Make sure new address is not already registered
    require(!users[newAddress].isRegistered, "New address already registered");

    // Load existing user
    User storage u = users[currentAddress];

    // Recreate user under new address
    users[newAddress] = User({
        internalId: u.internalId,
        userAddress: newAddress,
        role: u.role,
        hashId: u.hashId,
        isRegistered: u.isRegistered
    });

    // Clean up old mapping entry (This delete keyword resets a variable to its default value, as if it was never set.)
    delete users[currentAddress];

    // Update reverse index
    internalIdToAddress[internalId] = newAddress;

    emit UserAddressUpdated(internalId, currentAddress, newAddress);
}


}
