// scripts/deployAndMeasure.js
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

// Helper: load artifact
function loadArtifact(file, name) {
  const artifactPath = path.join(
    __dirname,
    "..",
    "artifacts",
    "contracts",
    file,
    `${name}.json`
  );
  return JSON.parse(fs.readFileSync(artifactPath, "utf8"));
}

// Helper: log gas & ETH cost
async function logTxCost(label, receipt) {
  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.effectiveGasPrice || receipt.gasPrice;

  console.log(`\n=== ${label} ===`);
  console.log(`Gas used: ${gasUsed.toString()}`);

  const totalWei = gasUsed.mul(gasPrice);
  console.log(`Gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);
  console.log(`Total cost: ${ethers.utils.formatEther(totalWei)} ETH`);
}

async function main() {
  // Connect to local Hardhat node
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

  // Roles
  const admin = provider.getSigner(0);
  const patient = provider.getSigner(1);
  const doctor = provider.getSigner(2);
  const researcher = provider.getSigner(3);

  const adminAddr = await admin.getAddress();
  const patientAddr = await patient.getAddress();
  const doctorAddr = await doctor.getAddress();
  const researcherAddr = await researcher.getAddress();

  console.log("Admin:", adminAddr);
  console.log("Patient:", patientAddr);
  console.log("Doctor:", doctorAddr);
  console.log("Requester:", researcherAddr);

  // Load artifacts
  const ConsentManager = loadArtifact("ConsentManager.sol", "ConsentManager");
  const DataRegistry = loadArtifact("DataRegistry.sol", "DataRegistry");
  const AccessController = loadArtifact("AccessController.sol", "AccessController");
  const DigitalIdentityRegistry = loadArtifact("DigitalIdentityRegistry.sol", "DigitalIdentityRegistry");
  const HealthConsentToken = loadArtifact("HealthConsentToken.sol", "HealthConsentToken");
  const OrganizationRegistry = loadArtifact("OrganizationRegistry.sol", "OrganizationRegistry");

  // Deploy ConsentManager
  const ConsentFactory = new ethers.ContractFactory(ConsentManager.abi, ConsentManager.bytecode, admin);
  const consent = await ConsentFactory.deploy();
  await logTxCost("Deploy ConsentManager", await consent.deployTransaction.wait());

  // Deploy DataRegistry
  const DataFactory = new ethers.ContractFactory(DataRegistry.abi, DataRegistry.bytecode, admin);
  const dataRegistry = await DataFactory.deploy();
  await logTxCost("Deploy DataRegistry", await dataRegistry.deployTransaction.wait());

  // Deploy HealthConsentToken
  const TokenFactory = new ethers.ContractFactory(HealthConsentToken.abi, HealthConsentToken.bytecode, admin);
  const token = await TokenFactory.deploy();
  await logTxCost("Deploy HealthConsentToken", await token.deployTransaction.wait());

  // Deploy OrganizationRegistry
  const OrgFactory = new ethers.ContractFactory(OrganizationRegistry.abi, OrganizationRegistry.bytecode, admin);
  const orgRegistry = await OrgFactory.deploy(adminAddr);
  await logTxCost("Deploy OrganizationRegistry", await orgRegistry.deployTransaction.wait());

  // Deploy DigitalIdentityRegistry
  const IdFactory = new ethers.ContractFactory(DigitalIdentityRegistry.abi, DigitalIdentityRegistry.bytecode, admin);
  const identity = await IdFactory.deploy(researcherAddr, doctorAddr);
  await logTxCost("Deploy DigitalIdentityRegistry", await identity.deployTransaction.wait());

  // Deploy AccessController
  const AccessFactory = new ethers.ContractFactory(AccessController.abi, AccessController.bytecode, admin);
  const access = await AccessFactory.deploy(consent.address, dataRegistry.address);
  await logTxCost("Deploy AccessController", await access.deployTransaction.wait());

  console.log("\nAll contracts deployed.");
  console.log("\nDeployed addresses:");
  console.log("ConsentManager:          ", consent.address);
  console.log("DataRegistry:            ", dataRegistry.address);
  console.log("HealthConsentToken:      ", token.address);
  console.log("OrganizationRegistry:    ", orgRegistry.address);
  console.log("DigitalIdentityRegistry: ", identity.address);
  console.log("AccessController:        ", access.address);
  console.log(""); // blank line

  // ========== SIMULATION ==========

  // Registration
  const patientIdentity = identity.connect(patient);
  const hashId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("patient@email|ID001"));
  const regTx = await patientIdentity.registerPatient(hashId);
  await logTxCost("registerPatient()", await regTx.wait());

  // Consent
  const patientConsent = consent.connect(patient);
  const dataType = 1; // LAB
  const days = 30;

  const consentTx = await patientConsent.setConsent(researcherAddr, dataType, days);
  await logTxCost("setConsent()", await consentTx.wait());

  // Data pointer
  const patientData = dataRegistry.connect(patient);
  const dummyHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("encrypted-data"));
  const dataTx = await patientData.setDataPointer(dataType, dummyHash);
  await logTxCost("setDataPointer()", await dataTx.wait());

  // Data access
  const requestAccess = access.connect(researcher);
  const accessTx = await requestAccess.accessData(patientAddr, dataType);
  await logTxCost("accessData()", await accessTx.wait());

  console.log("\nDONE ✅  ");
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
