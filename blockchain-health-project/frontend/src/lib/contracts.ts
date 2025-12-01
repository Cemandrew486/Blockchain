// src/lib/contracts.ts
import type { Abi } from 'viem'

// Deployed contract addresses 
export const DIGITAL_IDENTITY_ADDRESS = '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9' as `0x${string}`
export const CONSENT_MANAGER_ADDRESS   = '0x5FbDB2315678afecb367f032d93F642f64180aa3' as `0x${string}`
export const ACCESS_CONTROLLER_ADDRESS = '0x5FC8d32690cc91D4c39d9d3abcBD16989F875707' as `0x${string}`
export const DATA_REGISTRY_ADDRESS     = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512' as `0x${string}`
export const ORG_REGISTRY_ADDRESS      = '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9' as `0x${string}`
export const HEALTH_CONSENT_TOKEN_ADDRESS = '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' as `0x${string}`

export const digitalIdentityAbi: Abi = [
  {
    type: 'function',
    name: 'registerPatient',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'hashId', type: 'bytes32' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'users',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [
      { name: 'internalId', type: 'uint256' },
      { name: 'userAddress', type: 'address' },
      { name: 'role', type: 'uint8' },
      { name: 'hashId', type: 'bytes32' },
      { name: 'isRegistered', type: 'bool' },
    ],
  },
]

export const consentManagerAbi: Abi = [
  {
    type: 'function',
    name: 'setConsent',
    stateMutability: 'nonpayable',
    inputs: [
      { name: '_requester', type: 'address' },
      { name: '_dataType', type: 'uint8' },
      { name: '_durationDays', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'revokeConsent',
    stateMutability: 'nonpayable',
    inputs: [{ name: '_requester', type: 'address' }],
    outputs: [],
  },
  {
    type: 'function',
    name: 'hasValidConsent',
    stateMutability: 'view',
    inputs: [
      { name: 'patient', type: 'address' },
      { name: 'requester', type: 'address' },
      { name: 'dataType', type: 'uint8' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
]

export const accessControllerAbi: Abi = [
  {
    type: 'event',
    name: 'AccessLogged',
    anonymous: false,
    inputs: [
      { name: 'requester', type: 'address', indexed: true },
      { name: 'patient', type: 'address', indexed: true },
      { name: 'dataType', type: 'uint8', indexed: false },
      { name: 'success', type: 'bool', indexed: false },
      { name: 'timestamp', type: 'uint256', indexed: false },
    ],
  },
  {
    type: 'function',
    name: 'accessData',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'patient', type: 'address' },
      { name: 'dataType', type: 'uint8' },
    ],
    outputs: [
      { name: 'dataHash', type: 'bytes32' },
      { name: 'timestamp', type: 'uint256' },
      { name: 'version', type: 'uint32' },
    ],
  },
]
