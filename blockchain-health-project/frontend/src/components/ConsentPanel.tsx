// src/components/ConsentPanel.tsx
import { useState } from 'react'
import type { FormEvent } from 'react'
import { publicClient, walletClient } from '../lib/viemClient'
import { CONSENT_MANAGER_ADDRESS, consentManagerAbi } from '../lib/contracts'

type Props = { account: `0x${string}` }

export default function ConsentPanel({ account }: Props) {
  const [requester, setRequester] = useState('')
  const [dataType, setDataType] = useState(1)
  const [purpose, setPurpose] = useState(1)
  const [durationDays, setDurationDays] = useState(30)
  const [status, setStatus] = useState<string | null>(null)
  const [hasConsent, setHasConsent] = useState<boolean | null>(null)

  const onGrant = async (e: FormEvent) => {
    e.preventDefault()
    setStatus('Sending transaction…')
    const hash = await walletClient.writeContract({
      address: CONSENT_MANAGER_ADDRESS,
      abi: consentManagerAbi,
      functionName: 'setConsent',
      args: [requester as `0x${string}`, dataType, purpose, BigInt(durationDays)],
      account,
    })
    setStatus(`Tx sent: ${hash}`)
    await publicClient.waitForTransactionReceipt({ hash })
    setStatus('Consent granted.')
  }

  const onRevoke = async () => {
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
      args: [account, requester as `0x${string}`, dataType, purpose],
    }) as boolean
    setHasConsent(result)
  }

  return (
    <section>
      <h2>2. Consent Management</h2>
      <form onSubmit={onGrant} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', maxWidth: 500 }}>
        <label>
          Requester address
          <input value={requester} onChange={e => setRequester(e.target.value)} required />
        </label>
        <label>
          Data type
          <select value={dataType} onChange={e => setDataType(Number(e.target.value))}>
            <option value={1}>1 - Lab results</option>
            <option value={2}>2 - Imaging</option>
            <option value={3}>3 - Full record</option>
          </select>
        </label>
        <label>
          Purpose
          <select value={purpose} onChange={e => setPurpose(Number(e.target.value))}>
            <option value={1}>1 - Treatment</option>
            <option value={2}>2 - Research</option>
            <option value={3}>3 - Insurance</option>
          </select>
        </label>
        <label>
          Duration (days)
          <input type="number" min={1} value={durationDays} onChange={e => setDurationDays(Number(e.target.value))} />
        </label>
        <button type="submit">Grant consent</button>
      </form>

      <div style={{ marginTop: '0.5rem', display: 'flex', gap: '0.5rem' }}>
        <button type="button" onClick={onRevoke}>Revoke consent</button>
        <button type="button" onClick={onCheck}>Check valid?</button>
      </div>

      {status && <p>{status}</p>}
      {hasConsent !== null && (
        <p>Has valid consent? <strong>{hasConsent ? 'YES' : 'NO'}</strong></p>
      )}
    </section>
  )
}
