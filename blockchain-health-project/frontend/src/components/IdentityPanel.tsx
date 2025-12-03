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
    if (!walletClient) {
      return
    }
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
      <h2>Digital Identity</h2>
      <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '-0.5rem' }}>
        Blockchain-verified identity registration
      </p>
      
      {user?.isRegistered ? (
        <div style={{ 
          padding: '1rem', 
          background: 'rgba(34, 197, 94, 0.1)', 
          borderRadius: '0.5rem',
          border: '1px solid rgba(34, 197, 94, 0.3)',
          marginBottom: '1rem',
          maxWidth: '500px',
          margin: '0 auto 1rem auto'
        }}>
          <p style={{ margin: '0 0 0.5rem 0' }}>
            <strong>Role:</strong> <span style={{ color: 'var(--accent)' }}>{roleNames[user.role] ?? 'UNKNOWN'}</span>
          </p>
          <p style={{ margin: '0 0 0.5rem 0' }}>
            <strong>Internal ID:</strong> {user.internalId.toString()}
          </p>
          <p style={{ margin: 0, fontSize: '0.85rem' }}>
            <strong>Hash ID:</strong><br />
            <code style={{ fontSize: '0.75rem', wordBreak: 'break-all' }}>{user.hashId}</code>
          </p>
        </div>
      ) : (
        <div style={{ 
          padding: '0.75rem', 
          background: 'rgba(251, 191, 36, 0.1)', 
          borderRadius: '0.5rem',
          border: '1px solid rgba(251, 191, 36, 0.3)',
          marginBottom: '1rem',
          fontSize: '0.9rem'
        }}>
          <p style={{ margin: 0 }}>⚠️ You are not registered yet. Please register below.</p>
        </div>
      )}

      <form onSubmit={onRegister} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', maxWidth: 400, margin: '0 auto' }}>
        <label>
          Email
          <input value={email} onChange={e => setEmail(e.target.value)} placeholder="your.email@example.com" required />
        </label>
        <label>
          Medical ID
          <input value={medicalId} onChange={e => setMedicalId(e.target.value)} placeholder="Your medical ID number" required />
        </label>
        <button type="submit" disabled={loading}>
          {loading ? 'Registering…' : 'Register as patient'}
        </button>
      </form>
      
      {txHash && (
        <div style={{ 
          marginTop: '0.75rem', 
          padding: '0.5rem', 
          background: 'rgba(15, 23, 42, 0.6)', 
          borderRadius: '0.5rem',
          fontSize: '0.85rem'
        }}>
          <p style={{ margin: 0 }}>
            <strong>Transaction:</strong> <code style={{ fontSize: '0.75rem' }}>{txHash}</code>
          </p>
        </div>
      )}
    </section>
  )
}
