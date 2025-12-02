// npx hardhat node
// node scripts/scaletest.cjs

const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");


const NUM_PATIENTS = 18; 

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

// stats[bucket] = { gas: number[], time: number[] }
const stats = {
  registration: { gas: [], time: [] }, 
  consent: { gas: [], time: [] },      
  dataWrite: { gas: [], time: [] },    
  dataAccess: { gas: [], time: [] },   
};

async function measureTx(label, tx, bucket) {
  const t0 = Date.now();
  const receipt = await tx.wait();
  const t1 = Date.now();

  const gasUsed = receipt.gasUsed.toNumber();
  const timeMs = t1 - t0;

  console.log(
    `${label} | gas=${gasUsed} | time=${timeMs} ms`
  );

  if (bucket && stats[bucket]) {
    stats[bucket].gas.push(gasUsed);
    stats[bucket].time.push(timeMs);
  }

  return receipt;
}

function summarize(bucketName, numUsers) {
  const bucket = stats[bucketName];
  const gasArr = bucket.gas;
  const timeArr = bucket.time;

  if (gasArr.length === 0) {
    return null;
  }

  const sum = (arr) => arr.reduce((a, b) => a + b, 0);
  const totalGas = sum(gasArr);
  const totalTime = sum(timeArr);
  const txCount = gasArr.length;

  const avgGasPerTx = totalGas / txCount;
  const avgTimePerTx = totalTime / txCount;
  const avgGasPerUser = totalGas / numUsers;
  const avgTimePerUser = totalTime / numUsers;
  const txPerUser = txCount / numUsers;

  return {
    bucketName,
    numUsers,
    txPerUser,
    totalGas,
    avgGasPerTx,
    avgGasPerUser,
    avgTimePerTx,
    avgTimePerUser,
  };
}

async function main() {
  const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:8545");

  const admin = provider.getSigner(0);
  const researcher = provider.getSigner(1);

  const adminAddr = await admin.getAddress();
  const researcherAddr = await researcher.getAddress();

  console.log("Admin:     ", adminAddr);
  console.log("Researcher:", researcherAddr);
  console.log(`Simulating ${NUM_PATIENTS} patients...\n`);

  const ConsentManager = loadArtifact("ConsentManager.sol", "ConsentManager");
  const DataRegistry = loadArtifact("DataRegistry.sol", "DataRegistry");
  const AccessController = loadArtifact("AccessController.sol", "AccessController");
  const DigitalIdentityRegistry = loadArtifact(
    "DigitalIdentityRegistry.sol",
    "DigitalIdentityRegistry"
  );

  // deploy contracts
  const ConsentFactory = new ethers.ContractFactory(
    ConsentManager.abi,
    ConsentManager.bytecode,
    admin
  );
  const consent = await ConsentFactory.deploy();
  await measureTx("Deploy ConsentManager", consent.deployTransaction, null);

  const DataFactory = new ethers.ContractFactory(
    DataRegistry.abi,
    DataRegistry.bytecode,
    admin
  );
  const dataRegistry = await DataFactory.deploy();
  await measureTx("Deploy DataRegistry", dataRegistry.deployTransaction, null);

  const IdFactory = new ethers.ContractFactory(
    DigitalIdentityRegistry.abi,
    DigitalIdentityRegistry.bytecode,
    admin
  );
  const identity = await IdFactory.deploy(researcherAddr, researcherAddr);
  await measureTx("Deploy DigitalIdentityRegistry", identity.deployTransaction, null);

  const AccessFactory = new ethers.ContractFactory(
    AccessController.abi,
    AccessController.bytecode,
    admin
  );
  const access = await AccessFactory.deploy(
    consent.address,
    dataRegistry.address
  );
  await measureTx("Deploy AccessController", access.deployTransaction, null);

  console.log("\nContracts deployed:");
  console.log("ConsentManager:          ", consent.address);
  console.log("DataRegistry:            ", dataRegistry.address);
  console.log("DigitalIdentityRegistry: ", identity.address);
  console.log("AccessController:        ", access.address);
  console.log("");

  const dataType = 1;
  const days = 30;

  for (let i = 0; i < NUM_PATIENTS; i++) {
    const patient = provider.getSigner(2 + i);
    const patientAddr = await patient.getAddress();

    const patientIdentity = identity.connect(patient);
    const patientConsent = consent.connect(patient);
    const patientData = dataRegistry.connect(patient);
    const requestAccess = access.connect(researcher);

    console.log(
      `\n--- Patient #${i + 1} (${patientAddr}) ---`
    );

    const hashId = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(`patient${i}@email|ID${i}`)//teset
    );
    const dummyHash = ethers.utils.keccak256(
      ethers.utils.toUtf8Bytes(`encrypted-data-${i}`)
    );

    const regTx = await patientIdentity.registerPatient(hashId);
    await measureTx(
      "DigitalIdentityRegistry.registerPatient()",
      regTx,
      "registration"
    );

    const consentTx = await patientConsent.setConsent(
      researcherAddr,
      dataType,
      days
    );
    await measureTx(
      "ConsentManager.setConsent()",
      consentTx,
      "consent"
    );

    const dataTx = await patientData.setDataPointer(
      dataType,
      dummyHash
    );
    await measureTx(
      "DataRegistry.setDataPointer()",
      dataTx,
      "dataWrite"
    );

    const accessTx = await requestAccess.accessData(
      patientAddr,
      dataType
    );
    //console.log("aaaaaa");
    await measureTx(
      "AccessController.accessData()",
      accessTx,
      "dataAccess"
    );
  }

  
  console.log("\n\n**** Average ****");
  console.log("Operation,Users,TxPerUser,TotalGas,AvgGasPerTx,AvgGasPerUser,AvgTimePerTxMs,AvgTimePerUserMs");

  const buckets = ["registration", "consent", "dataWrite", "dataAccess"];
  for (const b of buckets) {
    const s = summarize(b, NUM_PATIENTS);
    if (!s) continue;
    console.log(
      [
        s.bucketName,
        s.numUsers,
        s.txPerUser.toFixed(2),
        s.totalGas,
        s.avgGasPerTx.toFixed(2),
        s.avgGasPerUser.toFixed(2),
        s.avgTimePerTx.toFixed(2),
        s.avgTimePerUser.toFixed(2),
      ].join(",")
    );
  }

  console.log("\nDone.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
