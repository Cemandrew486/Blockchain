// npx hardhat node
// node scripts/deployAndMeasure.cjs

const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

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

async function logTxCost(label, tx) {
  const t0 = Date.now();
  const receipt = await tx.wait();
  const t1 = Date.now();

  const gasUsed = receipt.gasUsed;
  const gasPrice = receipt.effectiveGasPrice || receipt.gasPrice;

  console.log(`\n=== ${label} ===`);
  console.log(`Gas used: ${gasUsed.toString()}`);

  const totalWei = gasUsed.mul(gasPrice);
  console.log(`Gas price: ${ethers.utils.formatUnits(gasPrice, "gwei")} gwei`);
  console.log(`Total cost: ${ethers.utils.formatEther(totalWei)} ETH`);
  console.log(`Confirmation time: ${t1 - t0} ms`);

  return receipt;
}

async function main() {
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545"); //idk if i need this but doesnt work otherwise

  const admin = provider.getSigner(0);
  const patient = provider.getSigner(1);
  const doctor = provider.getSigner(2);
  const researcher = provider.getSigner(3);
  const orgAdmin = provider.getSigner(4);
  const insuranceEmployee = provider.getSigner(5);
  const newUserAddressSigner = provider.getSigner(6);

  const adminAddr = await admin.getAddress();
  const patientAddr = await patient.getAddress();
  const doctorAddr = await doctor.getAddress();
  const researcherAddr = await researcher.getAddress();
  const orgAdminAddr = await orgAdmin.getAddress();
  const insuranceEmployeeAddr = await insuranceEmployee.getAddress();
  const newUserAddr = await newUserAddressSigner.getAddress();

  console.log("Admin:     ", adminAddr);
  console.log("Patient:   ", patientAddr);
  console.log("Doctor:    ", doctorAddr);
  console.log("Requester: ", researcherAddr);
  console.log("OrgAdmin:  ", orgAdminAddr);
  console.log("NewUser:   ", newUserAddr);

  const ConsentManager = loadArtifact("ConsentManager.sol", "ConsentManager");
  const DataRegistry = loadArtifact("DataRegistry.sol", "DataRegistry");
  const AccessController = loadArtifact("AccessController.sol", "AccessController");
  const DigitalIdentityRegistry = loadArtifact(
    "DigitalIdentityRegistry.sol",
    "DigitalIdentityRegistry"
  );
  const HealthConsentToken = loadArtifact(
    "HealthConsentToken.sol",
    "HealthConsentToken"
  );
  const OrganizationRegistry = loadArtifact(
    "OrganizationRegistry.sol",
    "OrganizationRegistry"
  );

  // **** Deploy contracts ****

  const ConsentFactory = new ethers.ContractFactory(
    ConsentManager.abi,
    ConsentManager.bytecode,
    admin
  );
  const consent = await ConsentFactory.deploy();
  await logTxCost("Deploy ConsentManager", consent.deployTransaction);

  const DataFactory = new ethers.ContractFactory(
    DataRegistry.abi,
    DataRegistry.bytecode,
    admin
  );
  const dataRegistry = await DataFactory.deploy();
  await logTxCost("Deploy DataRegistry", dataRegistry.deployTransaction);

  const TokenFactory = new ethers.ContractFactory(
    HealthConsentToken.abi,
    HealthConsentToken.bytecode,
    admin
  );
  const token = await TokenFactory.deploy();
  await logTxCost("Deploy HealthConsentToken", token.deployTransaction);

  const OrgFactory = new ethers.ContractFactory(
    OrganizationRegistry.abi,
    OrganizationRegistry.bytecode,
    admin
  );
  const orgRegistry = await OrgFactory.deploy(adminAddr);
  await logTxCost("Deploy OrganizationRegistry", orgRegistry.deployTransaction);

  const IdFactory = new ethers.ContractFactory(
    DigitalIdentityRegistry.abi,
    DigitalIdentityRegistry.bytecode,
    admin
  );
  const identity = await IdFactory.deploy(researcherAddr, doctorAddr);
  await logTxCost("Deploy DigitalIdentityRegistry", identity.deployTransaction);

  const AccessFactory = new ethers.ContractFactory(
    AccessController.abi,
    AccessController.bytecode,
    admin
  );
  const access = await AccessFactory.deploy(
    consent.address,
    dataRegistry.address
  );
  await logTxCost("Deploy AccessController", access.deployTransaction);

  console.log("\nAll contracts deployed.");
  console.log("\nDeployed addresses:");
  console.log("ConsentManager:          ", consent.address);
  console.log("DataRegistry:            ", dataRegistry.address);
  console.log("HealthConsentToken:      ", token.address);
  console.log("OrganizationRegistry:    ", orgRegistry.address);
  console.log("DigitalIdentityRegistry: ", identity.address);
  console.log("AccessController:        ", access.address);
  console.log("");

  // ****  Identity - Consent - Data - Access ****

  const patientIdentity = identity.connect(patient);
  const hashId = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("patient@email|ID001")
  );
  const regTx = await patientIdentity.registerPatient(hashId);
  await logTxCost("DigitalIdentityRegistry.registerPatient()", regTx);

  const patientConsent = consent.connect(patient);
  const dataType = 1;
  const days = 30;

  const consentTx = await patientConsent.setConsent(
    researcherAddr,
    dataType,
    days
  );
  await logTxCost("ConsentManager.setConsent()", consentTx);

  const patientData = dataRegistry.connect(patient);
  const dummyHash = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("encrypted-data")
  );
  const dataTx = await patientData.setDataPointer(dataType, dummyHash);
  await logTxCost("DataRegistry.setDataPointer()", dataTx);

  const requestAccess = access.connect(researcher);
  const accessTx = await requestAccess.accessData(
    patientAddr,
    dataType
  );
  await logTxCost("AccessController.accessData()", accessTx);

  const tokenForPatient = token.connect(admin);
  const mintTx = await tokenForPatient.mintForConsent(
    patientAddr,
    dataType,
    days
  );
  await logTxCost("HealthConsentToken.mintForConsent()", mintTx);

  const revokeTx = await patientConsent.revokeConsent(researcherAddr);
  await logTxCost("ConsentManager.revokeConsent()", revokeTx);

  // **** Organization Registry operations ****

  const hashOrgName = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("Awesome Hospital")
  );
  const registerOrgTx = await orgRegistry.registerOrganization(
    hashOrgName,
    "NL",
    orgAdminAddr
  );
  await logTxCost(
    "OrganizationRegistry.registerOrganization()",
    registerOrgTx
  );

  const orgId = 1;

  const setStatusTx = await orgRegistry.setOrgStatus(orgId, false);
  await logTxCost("OrganizationRegistry.setOrgStatus()", setStatusTx);

  const updateAdminTx = await orgRegistry.updateOrganizationAdmin(
    orgId,
    newUserAddr
  );
  await logTxCost(
    "OrganizationRegistry.updateOrganizationAdmin()",
    updateAdminTx
  );

  // **** Staff registration in Identity Registry ****

  const ownerIdentity = identity.connect(admin);
  const doctorHashId = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("doctoremail")
  );
  const regDoctorTx = await ownerIdentity.registerDoctor(
    doctorAddr,
    doctorHashId
  );
  await logTxCost(
    "DigitalIdentityRegistry.registerDoctor()",
    regDoctorTx
  );

  const researcherHashId = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("researcheremail")
  );
  const regResearcherTx = await ownerIdentity.registerResearcher(
    researcherAddr,
    researcherHashId
  );
  await logTxCost(
    "DigitalIdentityRegistry.registerResearcher()",
    regResearcherTx
  );

  const insuranceHashId = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("employemail")
  );
  const regInsuranceTx = await ownerIdentity.registerInsurance(
    insuranceEmployeeAddr,
    insuranceHashId
  );
  await logTxCost(
    "DigitalIdentityRegistry.registerInsurance()",
    regInsuranceTx
  );

  // **** Doctor viewing patient & updating user address ****

  const doctorView = identity.connect(doctor);
  const patientInfo = await doctorView.getPatient(patientAddr);
  const internalId = patientInfo[4];

  const updateUserTx = await ownerIdentity.updateUserAddress(
    internalId,
    newUserAddr
  );
  await logTxCost(
    "DigitalIdentityRegistry.updateUserAddress()",
    updateUserTx
  );

  console.log("\nDONE ");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
