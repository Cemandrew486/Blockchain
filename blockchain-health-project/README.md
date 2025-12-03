# Blockchain Health Data Sharing System

A decentralized healthcare data management system built with Solidity smart contracts, enabling secure patient data storage, consent management, and access control on the Ethereum blockchain.

## Project Overview

This project implements a complete blockchain-based health data sharing platform with:

- **Smart Contracts**:
  - `DigitalIdentityRegistry.sol` - Patient and provider identity management
  - `OrganizationRegistry.sol` - Healthcare organization verification
  - `DataRegistry.sol` - Medical record storage with version control
  - `ConsentManager.sol` - Patient consent and authorization management
  - `AccessController.sol` - Role-based access control system
  - `HealthConsentToken.sol` - NFT-based consent tokens

- **Frontend Application**: React-based UI for patients and healthcare providers
- **Comprehensive Testing**: Solidity unit tests using Foundry and integration tests
- **Deployment Scripts**: Automated deployment with gas measurement and performance testing

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v18 or higher)
- **npm** or **pnpm**
- **Git**
- **MetaMask** browser extension (for frontend interaction)

## Installation

1. Clone the repository:
```shell
git clone <repository-url>
cd blockchain-health-project
```

2. Install dependencies:
```shell
npm install
```

3. Install frontend dependencies:
```shell
cd frontend
npm install
cd ..
```

## Compilation

Compile all smart contracts:

```shell
npx hardhat compile
```

This will generate the contract artifacts in the `artifacts/` directory and ABIs for contract interaction.

## Testing

### Run All Tests

Execute all Solidity and JavaScript tests:

```shell
npx hardhat test
```

### Run Specific Test Types

Run only Solidity tests (Foundry format):
```shell
npx hardhat test solidity
```

Run only Node.js integration tests:
```shell
npx hardhat test nodejs
```

### Test Coverage

The test suite includes:
- Unit tests for each smart contract (in `test/` directory)
- Integration tests for complete workflows
- Access control and permission testing
- Consent management scenarios
- Data versioning and audit trail verification

## Deployment

### Local Hardhat Network

#### Step 1: Start Local Blockchain Node

In the first terminal, start the Hardhat node:

```shell
npx hardhat node
```

This will:
- Start a local Ethereum node at `http://127.0.0.1:8545`
- Create 20 test accounts with 10,000 ETH each
- Display account addresses and private keys
- Keep the node running for development

**Keep this terminal open** - the node must remain active.

#### Step 2: Deploy Smart Contracts

In a second terminal, deploy all contracts:

```shell
node scripts/deployAndMeasure.cjs
```

This script will:
- Deploy all six smart contracts in the correct order
- Measure and display gas costs for each deployment
- Show contract addresses for frontend configuration
- Execute sample transactions to demonstrate functionality
- Display performance metrics

### Sepolia Testnet Deployment

To deploy to Sepolia testnet:

1. Set up your private key using Hardhat Keystore:
```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

2. Ensure your account has Sepolia test ETH (get from [Sepolia Faucet](https://sepoliafaucet.com/))

3. Deploy to Sepolia:
```shell
node scripts/deployAndMeasure.cjs --network sepolia
```

## Running the Frontend Application

### Prerequisites

1. **MetaMask Setup**: Install the [MetaMask browser extension](https://metamask.io/)

2. **Connect to Local Network**:
   - Open MetaMask
   - Click the network dropdown
   - Select "Add Network" → "Add Network Manually"
   - Enter the following:
     - **Network Name**: Hardhat Local
     - **RPC URL**: `http://127.0.0.1:8545`
     - **Chain ID**: `31337`
     - **Currency Symbol**: ETH
   - Click "Save"

3. **Import Test Account**:
   - Copy a private key from the Hardhat node terminal (from Step 1)
   - In MetaMask: Click account icon → "Import Account"
   - Paste the private key
   - You should now have 10,000 test ETH

### Start the Frontend

1. Navigate to the frontend directory:
```shell
cd frontend
```

2. Start the development server:
```shell
npm run dev
```

3. Open your browser to `http://localhost:5173`

### Using the Application

The frontend provides two main interfaces:

**Patient View**:
- Register your digital identity on the blockchain
- Upload medical records with IPFS/encrypted data hashes
- Manage data versions and updates
- Grant/revoke consent to healthcare providers
- View complete audit logs of data access

**Requester View**:
- Request access to patient data
- View granted consents
- Access authorized medical records
- View audit trail of your access history

**Important Notes**:
- MetaMask will prompt for confirmation on every blockchain transaction
- Gas fees are free on the local Hardhat network
- All transactions are instant on the local network
- Switch between accounts in MetaMask to test different roles (patient/doctor)

## Performance Testing

Run scale tests to measure system performance:

```shell
node scripts/scaletest.cjs
```

This will simulate multiple users, data uploads, and consent operations to measure:
- Gas consumption under load
- Transaction throughput
- Contract performance with large datasets

## Configuration

### Hardhat Configuration

The project is configured in `hardhat.config.ts` with:
- Solidity compiler version 0.8.28
- Local network on port 8545
- Sepolia testnet support
- Gas reporting enabled

### Frontend Configuration

Contract addresses and ABIs are located in `frontend/src/lib/`:
- Update contract addresses after deployment
- ABIs are automatically imported from artifacts

## Troubleshooting

### Common Issues

1. **"Error: could not detect network"**
   - Ensure `npx hardhat node` is running
   - Check that RPC URL is `http://127.0.0.1:8545`

2. **MetaMask not connecting**
   - Verify network is set to "Hardhat Local" (Chain ID 31337)
   - Try resetting MetaMask account (Settings → Advanced → Reset Account)

3. **Frontend can't find contracts**
   - Verify contracts are deployed using `deployAndMeasure.cjs`
   - Check contract addresses match in frontend configuration
