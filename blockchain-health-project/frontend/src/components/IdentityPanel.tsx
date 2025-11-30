// src/components/IdentityPanel.tsx
import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { keccak256, stringToBytes } from 'viem'
import { publicClient, walletClient } from '../lib/viemClient'
import { DIGITAL_IDENTITY_ADDRESS, digitalIdentityAbi } from '../lib/contracts'

type Props = { account: `0x${string}` }

type User = {
  internalId: bigint
  userAddress: `0x${string}`
  role: number
  hashId: string
  isRegistered: boolean
}

const roleNames = ['NONE', 'PATIENT', 'DOCTOR', 'RESEARCHER', 'INSURANCE', 'SPECIALIST']

export default function IdentityPanel({ account }: Props) {
  const [email, setEmail] = useState('')
  const [medicalId, setMedicalId] = useState('')
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(false)
  const [txHash, setTxHash] = useState<string | null>(null)

  const loadUser = async () => {
    const res = await publicClient.readContract({
      address: DIGITAL_IDENTITY_ADDRESS,
      abi: digitalIdentityAbi,
      functionName: 'users',
      args: [account],
    }) as readonly [bigint, `0x${string}`, number, `0x${string}`, boolean]

    const [internalId, userAddress, role, hashId, isRegistered] = res
    setUser({ internalId, userAddress, role, hashId, isRegistered })
  }

  useEffect(() => {
    loadUser().catch(() => {})
  }, [account])

  const onRegister = async (e: FormEvent) => {
    e.preventDefault()
    setLoading(true)
    try {
      const hashInput = `${email.toLowerCase()}#${medicalId}`
      const hashId = keccak256(stringToBytes(hashInput))
      const hash = await walletClient.writeContract({
        address: DIGITAL_IDENTITY_ADDRESS,
        abi: digitalIdentityAbi,
        functionName: 'registerPatient',
        args: [hashId],
        account,
      })
      setTxHash(hash)
      await publicClient.waitForTransactionReceipt({ hash })
      await loadUser()
    } finally {
      setLoading(false)
    }
  }

  return (
    <section>
      <h2>1. Digital Identity</h2>
      {user?.isRegistered ? (
        <div>
          <p>You are registered as: <strong>{roleNames[user.role] ?? 'UNKNOWN'}</strong></p>
          <p>Internal ID: {user.internalId.toString()}</p>
          <p>HashId: <code>{user.hashId}</code></p>
        </div>
      ) : (
        <p>You are not registered yet.</p>
      )}

      <form onSubmit={onRegister} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', maxWidth: 400 }}>
        <label>
          Email
          <input value={email} onChange={e => setEmail(e.target.value)} required />
        </label>
        <label>
          Medical ID
          <input value={medicalId} onChange={e => setMedicalId(e.target.value)} required />
        </label>
        <button type="submit" disabled={loading}>
          {loading ? 'Registering…' : 'Register as patient'}
        </button>
      </form>
      {txHash && <p>Last tx: <code>{txHash}</code></p>}
    </section>
  )
}
