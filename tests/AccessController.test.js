import { expect } from "chai";
import hre from "hardhat";

describe("AccessController Tests", function () {
  let accessControllerTest;

  beforeEach(async function () {
    const AccessControllerTest = await hre.ethers.getContractFactory("AccessController_t");
    accessControllerTest = await AccessControllerTest.deploy();
    await accessControllerTest.waitForDeployment();
  });

  it("Should test constructor with invalid ConsentManager", async function () {
    await accessControllerTest.testConstructorInvalidConsentManager();
  });

  it("Should test constructor with invalid DataRegistry", async function () {
    await accessControllerTest.testConstructorInvalidDataRegistry();
  });

  it("Should test access data with valid consent", async function () {
    await accessControllerTest.testAccessDataWithValidConsent();
  });

  it("Should test access data without consent", async function () {
    await accessControllerTest.testAccessDataWithoutConsent();
  });

  it("Should test invalid patient address", async function () {
    await accessControllerTest.testAccessDataInvalidPatient();
  });

  it("Should test invalid data type", async function () {
    await accessControllerTest.testAccessDataInvalidDataType();
  });

  it("Should test data retrieval failure with reason", async function () {
    await accessControllerTest.testAccessDataRetrievalFailureWithReason();
  });

  it("Should test data retrieval failure without reason", async function () {
    await accessControllerTest.testAccessDataRetrievalFailureWithoutReason();
  });

  it("Should test check access permission", async function () {
    await accessControllerTest.testCheckAccessPermission();
  });

  it("Should test get addresses", async function () {
    await accessControllerTest.testGetAddresses();
  });

  it("Should test multiple data types", async function () {
    await accessControllerTest.testMultipleDataTypes();
  });
});