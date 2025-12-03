// src/components/ConsentPanel.tsx
import { useState, useEffect, useCallback } from 'react'
import type { FormEvent } from 'react'
import { publicClient, walletClient } from '../lib/viemClient'
import { CONSENT_MANAGER_ADDRESS, consentManagerAbi, DATA_REGISTRY_ADDRESS, dataRegistryAbi } from '../lib/contracts'

type Props = { account: `0x${string}` }

export default function ConsentPanel({ account }: Props) {
  const [requester, setRequester] = useState('')
  const [dataType, setDataType] = useState(1)
  const [dataVersion, setDataVersion] = useState(1)
  const [durationDays, setDurationDays] = useState(30)
  const [status, setStatus] = useState<string | null>(null)
  const [hasConsent, setHasConsent] = useState<boolean | null>(null)
  const [availableVersions, setAvailableVersions] = useState<number[]>([1])

  const onGrant = async (e: FormEvent) => {
    e.preventDefault()
    if (!walletClient) {
      setStatus('Wallet not connected')
      return
    }
    setStatus('Sending transaction…')
    const hash = await walletClient.writeContract({
      address: CONSENT_MANAGER_ADDRESS,
      abi: consentManagerAbi,
      functionName: 'setConsent',
      args: [requester as `0x${string}`, dataType, dataVersion, BigInt(durationDays)],
      account,
    })
    setStatus(`Tx sent: ${hash}`)
    await publicClient.waitForTransactionReceipt({ hash })
    setStatus('Consent granted.')
  }

  const onRevoke = async () => {
    if (!walletClient) {
      setStatus('Wallet not connected')
      return
    }
    setStatus('Revoking…')
    const hash = await walletClient.writeContract({
      address: CONSENT_MANAGER_ADDRESS,
      abi: consentManagerAbi,
      functionName: 'revokeConsent',
      args: [requester as `0x${string}`],
      account,
    })
    await publicClient.waitForTransactionReceipt({ hash })
    setStatus('Consent revoked.')
  }

  const onCheck = async () => {
    const result = await publicClient.readContract({
      address: CONSENT_MANAGER_ADDRESS,
      abi: consentManagerAbi,
      functionName: 'hasValidConsent',
      args: [account, requester as `0x${string}`, dataType, dataVersion],
    }) as boolean
    setHasConsent(result)
  }

  const loadAvailableVersions = useCallback(async () => {
    try {
      const count = await publicClient.readContract({
        address: DATA_REGISTRY_ADDRESS,
        abi: dataRegistryAbi,
        functionName: 'getVersionCount',
        args: [account, dataType],
      }) as bigint
      
      const versionCount = Number(count)
      if (versionCount > 0) {
        const versions = Array.from({ length: versionCount }, (_, i) => i + 1)
        setAvailableVersions(versions)
        // Reset to first version if current selection is out of range
        if (dataVersion > versionCount) {
          setDataVersion(1)
        }
      } else {
        setAvailableVersions([1])
        setDataVersion(1)
      }
    } catch (err) {
      console.error('Error loading versions:', err)
      setAvailableVersions([1])
    }
  }, [account, dataType, dataVersion])

  useEffect(() => {
    loadAvailableVersions()
  }, [loadAvailableVersions])

  return (
    <section>
      <h2>Consent Management (Patient)</h2>
      <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '-0.5rem' }}>
        Grant permission for requesters (doctors, researchers, insurance, etc.) to access specific data versions
      </p>
      
      <div style={{ 
        padding: '0.75rem', 
        background: 'rgba(239, 68, 68, 0.1)', 
        borderRadius: '0.5rem',
        border: '1px solid rgba(239, 68, 68, 0.3)',
        marginBottom: '1rem',
        fontSize: '0.85rem'
      }}>
        <p style={{ margin: 0, color: '#ef4444' }}>
          <strong>Current Limitation:</strong> You can only grant ONE consent per requester at a time. 
          Granting new consent will replace the previous one.
        </p>
      </div>
      <form onSubmit={onGrant} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', maxWidth: 500 }}>
        <label>
          Requester address (Doctor, Researcher, Insurance, etc.)
          <input value={requester} onChange={e => setRequester(e.target.value)} placeholder="0x..." required />
        </label>
        <label>
          Data type
          <select value={dataType} onChange={e => setDataType(Number(e.target.value))}>
            <option value={1}>1 - Lab Results</option>
            <option value={2}>2 - Imaging (X-ray, MRI)</option>
            <option value={3}>3 - Full Record</option>
          </select>
        </label>
        <label>
          Data version
          <select value={dataVersion} onChange={e => setDataVersion(Number(e.target.value))}>
            {availableVersions.map(v => (
              <option key={v} value={v}>Version {v}</option>
            ))}
          </select>
        </label>
        <label>
          Duration (days)
          <input type="number" min={1} value={durationDays} onChange={e => setDurationDays(Number(e.target.value))} />
        </label>
        <button type="submit">Grant consent</button>
      </form>

      <div style={{ marginTop: '0.75rem', display: 'flex', gap: '0.5rem' }}>
        <button type="button" onClick={onRevoke}>Revoke consent</button>
        <button type="button" onClick={onCheck}>Check valid?</button>
      </div>

      {status && <p style={{ marginTop: '0.5rem', fontSize: '0.9rem' }}>{status}</p>}
      {hasConsent !== null && (
        <p style={{ marginTop: '0.5rem', fontSize: '0.9rem' }}>
          Has valid consent? <strong>{hasConsent ? '✅ YES' : '❌ NO'}</strong>
        </p>
      )}
    </section>
  )
}
