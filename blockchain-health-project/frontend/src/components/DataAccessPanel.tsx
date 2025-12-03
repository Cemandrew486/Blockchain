// src/components/DataAccessPanel.tsx
import { useState, useEffect, useCallback } from 'react'
import type { FormEvent } from 'react'
import { publicClient, walletClient } from '../lib/viemClient'
import { ACCESS_CONTROLLER_ADDRESS, accessControllerAbi, DATA_REGISTRY_ADDRESS, dataRegistryAbi } from '../lib/contracts'

type Props = { account: `0x${string}` }

export default function DataAccessPanel({ account }: Props) {
  const [patientAddress, setPatientAddress] = useState('')
  const [dataType, setDataType] = useState(1)
  const [dataVersion, setDataVersion] = useState(1)
  const [status, setStatus] = useState<string | null>(null)
  const [dataHash, setDataHash] = useState<string | null>(null)
  const [timestamp, setTimestamp] = useState<string | null>(null)
  const [hasPermission, setHasPermission] = useState<boolean | null>(null)
  const [availableVersions, setAvailableVersions] = useState<number[]>([1])

  const onCheckPermission = async () => {
    try {
      setStatus('Checking permission…')
      const result = await publicClient.readContract({
        address: ACCESS_CONTROLLER_ADDRESS,
        abi: accessControllerAbi,
        functionName: 'checkAccessPermission',
        args: [patientAddress as `0x${string}`, account, dataType, dataVersion],
      }) as boolean
      setHasPermission(result)
      setStatus(result ? '✅ You have permission' : '❌ No permission')
    } catch (err) {
      console.error(err)
      setStatus('Error checking permission')
      setHasPermission(null)
    }
  }

  const onAccessData = async (e: FormEvent) => {
    e.preventDefault()
    if (!walletClient) {
      setStatus('Wallet not connected')
      return
    }

    try {
      setStatus('Accessing data…')
      setDataHash(null)
      setTimestamp(null)
      
      const hash = await walletClient.writeContract({
        address: ACCESS_CONTROLLER_ADDRESS,
        abi: accessControllerAbi,
        functionName: 'accessData',
        args: [patientAddress as `0x${string}`, dataType, dataVersion],
        account,
      })
      
      setStatus('Transaction sent, waiting for confirmation…')
      await publicClient.waitForTransactionReceipt({ hash })
      
      // Read the result from the contract
      const result = await publicClient.readContract({
        address: ACCESS_CONTROLLER_ADDRESS,
        abi: accessControllerAbi,
        functionName: 'accessData',
        args: [patientAddress as `0x${string}`, dataType, dataVersion],
        account,
      }) as readonly [string, bigint, number]
      
      const [returnedHash, returnedTimestamp, returnedVersion] = result
      
      if (returnedHash === '0x0000000000000000000000000000000000000000000000000000000000000000') {
        setStatus('❌ Access denied or data not found')
        setDataHash(null)
        setTimestamp(null)
      } else {
        setDataHash(returnedHash)
        setTimestamp(new Date(Number(returnedTimestamp) * 1000).toLocaleString())
        setStatus(`✅ Access granted! Version: ${returnedVersion}`)
      }
    } catch (err: any) {
      console.error(err)
      setStatus(`Error: ${err.message || 'Failed to access data'}`)
      setDataHash(null)
    }
  }

  const loadAvailableVersions = useCallback(async () => {
    if (!patientAddress || patientAddress.length < 42) {
      setAvailableVersions([1])
      return
    }
    
    try {
      const count = await publicClient.readContract({
        address: DATA_REGISTRY_ADDRESS,
        abi: dataRegistryAbi,
        functionName: 'getVersionCount',
        args: [patientAddress as `0x${string}`, dataType],
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
  }, [patientAddress, dataType, dataVersion])

  useEffect(() => {
    loadAvailableVersions()
  }, [loadAvailableVersions])

  const isViewingOwnData = patientAddress.toLowerCase() === account.toLowerCase()

  return (
    <section>
      <h2>🔍 Data Access (Requester)</h2>
      <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '-0.5rem' }}>
        Access patient data if you have valid consent (Doctor, Researcher, Insurance, etc.)
      </p>

      {isViewingOwnData && patientAddress && (
        <div style={{ 
          padding: '0.75rem', 
          background: 'rgba(59, 130, 246, 0.1)', 
          borderRadius: '0.5rem',
          border: '1px solid rgba(59, 130, 246, 0.3)',
          marginBottom: '1rem',
          fontSize: '0.85rem'
        }}>
          <p style={{ margin: 0, color: '#60a5fa' }}>
            💡 <strong>Viewing your own data:</strong> You still need to grant consent to yourself first. 
            Switch to Patient View → Consent Management to grant yourself access, then come back here.
          </p>
        </div>
      )}
      
      <form onSubmit={onAccessData} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', maxWidth: 500, margin: '0 auto' }}>
        <label>
          Patient address
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <input 
              value={patientAddress} 
              onChange={e => setPatientAddress(e.target.value)} 
              placeholder="0x..." 
              required 
              style={{ flex: 1 }}
            />
            <button 
              type="button"
              onClick={() => setPatientAddress(account)}
              style={{ 
                padding: '0.55rem 0.75rem',
                fontSize: '0.8rem',
                whiteSpace: 'nowrap',
                background: '#111827',
                color: 'var(--text)'
              }}
            >
              Use My Address
            </button>
          </div>
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

        <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.25rem' }}>
          <button type="submit">Access Data</button>
          <button type="button" onClick={onCheckPermission}>Check Permission</button>
        </div>
      </form>

      {status && (
        <div style={{ 
          marginTop: '1rem', 
          padding: '0.75rem', 
          background: 'rgba(15, 23, 42, 0.6)', 
          borderRadius: '0.5rem',
          fontSize: '0.9rem'
        }}>
          <p style={{ margin: 0 }}>{status}</p>
        </div>
      )}

      {hasPermission !== null && (
        <div style={{ 
          marginTop: '0.75rem', 
          padding: '0.75rem', 
          background: hasPermission ? 'rgba(34, 197, 94, 0.1)' : 'rgba(239, 68, 68, 0.1)', 
          borderRadius: '0.5rem',
          border: `1px solid ${hasPermission ? 'rgba(34, 197, 94, 0.3)' : 'rgba(239, 68, 68, 0.3)'}`,
          fontSize: '0.9rem'
        }}>
          <p style={{ margin: 0, fontWeight: 500 }}>
            Permission status: <strong>{hasPermission ? '✅ GRANTED' : '❌ DENIED'}</strong>
          </p>
        </div>
      )}

      {dataHash && (
        <div style={{ 
          marginTop: '1rem', 
          padding: '1rem', 
          background: 'rgba(34, 197, 94, 0.1)', 
          borderRadius: '0.5rem',
          border: '1px solid rgba(34, 197, 94, 0.3)'
        }}>
          <h3 style={{ marginTop: 0, fontSize: '1rem', color: 'var(--accent)' }}>
            📄 Data Retrieved
          </h3>
          <div style={{ fontSize: '0.85rem' }}>
            <p style={{ marginBottom: '0.5rem' }}>
              <strong>Data Hash:</strong>
            </p>
            <code style={{ 
              display: 'block', 
              padding: '0.5rem', 
              background: '#020617', 
              borderRadius: '0.25rem',
              wordBreak: 'break-all',
              fontSize: '0.8rem'
            }}>
              {dataHash}
            </code>
            <p style={{ marginTop: '0.75rem', marginBottom: 0 }}>
              <strong>Timestamp:</strong> {timestamp}
            </p>
          </div>
          <p style={{ 
            marginTop: '1rem', 
            fontSize: '0.85rem', 
            color: 'var(--text-muted)',
            fontStyle: 'italic'
          }}>
            💡 Use this hash to retrieve the actual medical data from your off-chain database.
          </p>
        </div>
      )}
    </section>
  )
}
