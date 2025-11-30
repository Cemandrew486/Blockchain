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



  // contracts
  const ConsentFactory = new ethers.ContractFactory(
    ConsentManager.abi,
    ConsentManager.bytecode,
    admin
  );
  const consent = await ConsentFactory.deploy();
  await logTxCost(
    "Deploy ConsentManager",
    await consent.deployTransaction.wait()
  );


  const DataFactory = new ethers.ContractFactory(
    DataRegistry.abi,
    DataRegistry.bytecode,
    admin
  );
  const dataRegistry = await DataFactory.deploy();
  await logTxCost(
    "Deploy DataRegistry",
    await dataRegistry.deployTransaction.wait()
  );


  const TokenFactory = new ethers.ContractFactory(
    HealthConsentToken.abi,
    HealthConsentToken.bytecode,
    admin
  );
  const token = await TokenFactory.deploy();
  await logTxCost(
    "Deploy HealthConsentToken",
    await token.deployTransaction.wait()
  );


  const OrgFactory = new ethers.ContractFactory(
    OrganizationRegistry.abi,
    OrganizationRegistry.bytecode,
    admin
  );
  const orgRegistry = await OrgFactory.deploy(adminAddr);
  await logTxCost(
    "Deploy OrganizationRegistry",
    await orgRegistry.deployTransaction.wait()
  );


  const IdFactory = new ethers.ContractFactory(
    DigitalIdentityRegistry.abi,
    DigitalIdentityRegistry.bytecode,
    admin
  );
  const identity = await IdFactory.deploy(researcherAddr, doctorAddr);
  await logTxCost(
    "Deploy DigitalIdentityRegistry",
    await identity.deployTransaction.wait()
  );


  const AccessFactory = new ethers.ContractFactory(
    AccessController.abi,
    AccessController.bytecode,
    admin
  );
  const access = await AccessFactory.deploy(
    consent.address,
    dataRegistry.address
  );
  await logTxCost(
    "Deploy AccessController",
    await access.deployTransaction.wait()
  );

  console.log("\nAll contracts deployed.");
  console.log("\nDeployed addresses:");
  console.log("ConsentManager:          ", consent.address);
  console.log("DataRegistry:            ", dataRegistry.address);
  console.log("HealthConsentToken:      ", token.address);
  console.log("OrganizationRegistry:    ", orgRegistry.address);
  console.log("DigitalIdentityRegistry: ", identity.address);
  console.log("AccessController:        ", access.address);
  console.log("");



  const patientIdentity = identity.connect(patient);
  const hashId = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("patient@email|ID001")
  );
  const regTx = await patientIdentity.registerPatient(hashId);
  await logTxCost("DigitalIdentityRegistry.registerPatient()", await regTx.wait());

  const patientConsent = consent.connect(patient);
  const dataType = 1; 
  const purpose = 1;
  const days = 30;

  const consentTx = await patientConsent.setConsent(
    researcherAddr,
    dataType,
    purpose,
    days
  );
  await logTxCost("ConsentManager.setConsent()", await consentTx.wait());

  const patientData = dataRegistry.connect(patient);
  const dummyHash = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("encrypted-data")
  );
  const dataTx = await patientData.setDataPointer(dataType, dummyHash);
  await logTxCost("DataRegistry.setDataPointer()", await dataTx.wait());

  const requestAccess = access.connect(researcher);
  const accessTx = await requestAccess.accessData(
    patientAddr,
    dataType,
    purpose
  );
  await logTxCost("AccessController.accessData()", await accessTx.wait());

  
  const tokenForPatient = token.connect(admin);
  const mintTx = await tokenForPatient.mintForConsent(
    patientAddr,
    dataType,
    days
  );
  await logTxCost("HealthConsentToken.mintForConsent()", await mintTx.wait());

  const revokeTx = await patientConsent.revokeConsent(researcherAddr);
  await logTxCost("ConsentManager.revokeConsent()", await revokeTx.wait());

  const hashOrgName = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("Awesome Hospital")
  );
  const registerOrgTx = await orgRegistry.registerOrganization(
    hashOrgName,
    "NL",
    orgAdminAddr
  );
  const registerOrgReceipt = await registerOrgTx.wait();
  await logTxCost(
    "OrganizationRegistry.registerOrganization()",
    registerOrgReceipt
  );

  const orgId = 1;


  const setStatusTx = await orgRegistry.setOrgStatus(orgId, false);
  await logTxCost("OrganizationRegistry.setOrgStatus()", await setStatusTx.wait());


  const updateAdminTx = await orgRegistry.updateOrganizationAdmin(
    orgId,
    newUserAddr
  );
  await logTxCost(
    "OrganizationRegistry.updateOrganizationAdmin()",
    await updateAdminTx.wait()
  );

 
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
    await regDoctorTx.wait()
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
    await regResearcherTx.wait()
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
    await regInsuranceTx.wait()
  );



  const doctorView = identity.connect(doctor);
  const patientInfo = await doctorView.getPatient(patientAddr);
  const internalId = patientInfo[4];

  const updateUserTx = await ownerIdentity.updateUserAddress(
    internalId,
    newUserAddr
  );
  await logTxCost(
    "DigitalIdentityRegistry.updateUserAddress()",
    await updateUserTx.wait()
  );

  console.log("\nDONE ");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
