// src/lib/viemClient.ts
import { createPublicClient, createWalletClient, custom, http } from 'viem'
import { hardhat } from 'viem/chains'

// read-only client (needs Hardhat node on 127.0.0.1:8545)
export const publicClient = createPublicClient({
  chain: hardhat,
  transport: http('http://127.0.0.1:8545'),
})

// wallet client: may be null if no injected wallet (MetaMask) is present
export const walletClient =
  typeof window !== 'undefined' && (window as any).ethereum
    ? createWalletClient({
        chain: hardhat,
        transport: custom((window as any).ethereum),
      })
    : null
