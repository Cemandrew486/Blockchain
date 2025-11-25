// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title StudentCertificate
 * @dev ERC-721 NFT for student achievements
 */
contract StudentCertificate {
    // Token name and symbol
    string public name = "Student Certificate";
    string public symbol = "CERT";

    // Owner and issuer
    address public owner;
    mapping(address => bool) public isIssuer;

    // Token data
    uint256 public nextTokenId = 1;
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => string) public tokenMetadata;

    // Approvals
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    // Certificate details
    struct Certificate {
        uint256 id;
        string studentName;
        string achievement;
        uint256 issuedDate;
        address issuedBy;
    }

    mapping(uint256 => Certificate) public certificates;
    mapping(address => uint256[]) public studentCertificates;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event CertificateIssued(uint256 indexed tokenId, address indexed student, string achievement);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyIssuer() {
        require(isIssuer[msg.sender], "Not authorized issuer");
        _;
    }

    constructor() {
        owner = msg.sender;
        isIssuer[msg.sender] = true;
    }

    /**
     * @dev Issue a certificate to a student
     */
    function issueCertificate(
        address student,
        string memory studentName,
        string memory achievement
    ) public onlyIssuer returns (uint256) {
        require(student != address(0), "Invalid student address");
        require(bytes(studentName).length > 0, "Student name required");
        require(bytes(achievement).length > 0, "Achievement required");

        uint256 tokenId = nextTokenId++;

        ownerOf[tokenId] = student;
        balanceOf[student]++;

        certificates[tokenId] = Certificate({
            id: tokenId,
            studentName: studentName,
            achievement: achievement,
            issuedDate: block.timestamp,
            issuedBy: msg.sender
        });

        studentCertificates[student].push(tokenId);

        emit Transfer(address(0), student, tokenId);
        emit CertificateIssued(tokenId, student, achievement);

        return tokenId;
    }

    /**
     * @dev Transfer certificate (disabled for soul-bound tokens)
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        revert("Certificates are non-transferable (soul-bound)");
    }

    /**
     * @dev Safe transfer (disabled)
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        revert("Certificates are non-transferable (soul-bound)");
    }

    /**
     * @dev Approve address to transfer token (disabled)
     */
    function approve(address to, uint256 tokenId) public {
        revert("Certificates are non-transferable (soul-bound)");
    }

    /**
     * @dev Set approval for all tokens (disabled)
     */
    function setApprovalForAll(address operator, bool approved) public {
        revert("Certificates are non-transferable (soul-bound)");
    }

    /**
     * @dev Get certificate details
     */
    function getCertificate(uint256 tokenId)
        public
        view
        returns (
            string memory studentName,
            string memory achievement,
            uint256 issuedDate,
            address issuedBy,
            address currentOwner
        )
    {
        require(ownerOf[tokenId] != address(0), "Certificate does not exist");
        Certificate memory cert = certificates[tokenId];
        return (
            cert.studentName,
            cert.achievement,
            cert.issuedDate,
            cert.issuedBy,
            ownerOf[tokenId]
        );
    }

    /**
     * @dev Get all certificates owned by a student
     */
    function getCertificatesByStudent(address student)
        public
        view
        returns (uint256[] memory)
    {
        return studentCertificates[student];
    }

    /**
     * @dev Get total number of certificates issued
     */
    function totalSupply() public view returns (uint256) {
        return nextTokenId - 1;
    }

    /**
     * @dev Check if token exists
     */
    function exists(uint256 tokenId) public view returns (bool) {
        return ownerOf[tokenId] != address(0);
    }

    /**
     * @dev Add authorized issuer (owner only)
     */
    function addIssuer(address issuer) public onlyOwner {
        require(issuer != address(0), "Invalid issuer address");
        isIssuer[issuer] = true;
    }

    /**
     * @dev Remove authorized issuer (owner only)
     */
    function removeIssuer(address issuer) public onlyOwner {
        isIssuer[issuer] = false;
    }

    /**
     * @dev Burn certificate (revoke)
     */
    function revokeCertificate(uint256 tokenId) public onlyIssuer {
        address student = ownerOf[tokenId];
        require(student != address(0), "Certificate does not exist");

        balanceOf[student]--;
        delete ownerOf[tokenId];
        delete certificates[tokenId];

        emit Transfer(student, address(0), tokenId);
    }
}
