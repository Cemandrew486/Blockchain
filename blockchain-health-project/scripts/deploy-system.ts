// scripts/deploy-system.ts
import hre from "hardhat";

async function main() {
  // cast once if TS complains about types
  const anyHre = hre as any;

  // Grab a few local accounts for roles
  const [deployer, instituteResearcher, doctor] =
    await anyHre.viem.getWalletClients();

  console.log("Deployer:           ", deployer.account.address);
  console.log("InstituteResearcher:", instituteResearcher.account.address);
  console.log("Doctor:             ", doctor.account.address);
  console.log("");

  console.log("Deploying ConsentManager...");
  const consentManager = await anyHre.viem.deployContract("ConsentManager");
  console.log("  ConsentManager:", consentManager.address);

  console.log("Deploying DataRegistry...");
  const dataRegistry = await anyHre.viem.deployContract("DataRegistry");
  console.log("  DataRegistry:", dataRegistry.address);

  console.log("Deploying HealthConsentToken...");
  const healthConsentToken = await anyHre.viem.deployContract("HealthConsentToken");
  console.log("  HealthConsentToken:", healthConsentToken.address);

  console.log("Deploying OrganizationRegistry...");
  const organizationRegistry = await anyHre.viem.deployContract(
    "OrganizationRegistry",
    [deployer.account.address] // _systemAdmin
  );
  console.log("  OrganizationRegistry:", organizationRegistry.address);

  console.log("Deploying DigitalIdentityRegistry...");
  const digitalIdentityRegistry = await anyHre.viem.deployContract(
    "DigitalIdentityRegistry",
    [
      instituteResearcher.account.address, // _instituteResearcher
      doctor.account.address,              // _doctor
    ]
  );
  console.log("  DigitalIdentityRegistry:", digitalIdentityRegistry.address);

  console.log("Deploying AccessController...");
  const accessController = await anyHre.viem.deployContract(
    "AccessController",
    [
      consentManager.address, // _consentManager
      dataRegistry.address,   // _dataRegistry
    ]
  );
  console.log("  AccessController:", accessController.address);

  console.log("\n=== Deployment complete ===");
  console.table([
    { name: "ConsentManager",          address: consentManager.address },
    { name: "DataRegistry",            address: dataRegistry.address },
    { name: "HealthConsentToken",      address: healthConsentToken.address },
    { name: "OrganizationRegistry",    address: organizationRegistry.address },
    { name: "DigitalIdentityRegistry", address: digitalIdentityRegistry.address },
    { name: "AccessController",        address: accessController.address },
  ]);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
