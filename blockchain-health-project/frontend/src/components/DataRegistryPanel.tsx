// src/components/DataRegistryPanel.tsx
import { useState } from 'react'
import type { FormEvent } from 'react'
import { publicClient, walletClient } from '../lib/viemClient'
import { DATA_REGISTRY_ADDRESS, dataRegistryAbi } from '../lib/contracts'
import { keccak256, stringToBytes } from 'viem'

type Props = { account: `0x${string}` }

export default function DataRegistryPanel({ account }: Props) {
  const [dataType, setDataType] = useState(1)
  const [dataContent, setDataContent] = useState('')
  const [status, setStatus] = useState<string | null>(null)
  const [versionCount, setVersionCount] = useState<number | null>(null)
  const [latestData, setLatestData] = useState<{hash: string, version: number, timestamp: string} | null>(null)

  const onRegisterData = async (e: FormEvent) => {
    e.preventDefault()
    if (!walletClient) {
      setStatus('Wallet not connected')
      return
    }

    try {
      setStatus('Hashing data and registering…')
      
      // Hash the data content (in real app, this would be encrypted data)
      const dataHash = keccak256(stringToBytes(dataContent))
      
      const hash = await walletClient.writeContract({
        address: DATA_REGISTRY_ADDRESS,
        abi: dataRegistryAbi,
        functionName: 'setDataPointer',
        args: [dataType, dataHash],
        account,
      })
      
      setStatus('Transaction sent, waiting for confirmation…')
      await publicClient.waitForTransactionReceipt({ hash })
      
      setStatus('Data registered successfully!')
      setDataContent('')
      
      // Refresh version count
      await loadVersionCount()
    } catch (err: any) {
      console.error(err)
      setStatus(`Error: ${err.message || 'Failed to register data'}`)
    }
  }

  const loadVersionCount = async () => {
    try {
      const count = await publicClient.readContract({
        address: DATA_REGISTRY_ADDRESS,
        abi: dataRegistryAbi,
        functionName: 'getVersionCount',
        args: [account, dataType],
      }) as bigint
      setVersionCount(Number(count))
    } catch (err) {
      console.error(err)
      setVersionCount(null)
    }
  }

  const loadLatestData = async () => {
    try {
      setStatus('Loading latest data…')
      const result = await publicClient.readContract({
        address: DATA_REGISTRY_ADDRESS,
        abi: dataRegistryAbi,
        functionName: 'getLatestDataPointer',
        args: [account, dataType],
      }) as readonly [string, bigint, number]
      
      const [hash, timestamp, version] = result
      setLatestData({
        hash,
        version,
        timestamp: new Date(Number(timestamp) * 1000).toLocaleString()
      })
      setStatus('Latest data loaded')
    } catch (err: any) {
      console.error(err)
      setStatus('No data found for this type')
      setLatestData(null)
    }
  }

  const onCheckVersions = async () => {
    await loadVersionCount()
    await loadLatestData()
  }

  return (
    <section>
      <h2>Data Registry (Patient)</h2>
      <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '-0.5rem' }}>
        Register new medical data pointers (hashes) to the blockchain
      </p>
      
      <form onSubmit={onRegisterData} style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', maxWidth: 500 }}>
        <label>
          Data type
          <select value={dataType} onChange={e => setDataType(Number(e.target.value))}>
            <option value={1}>1 - Lab Results</option>
            <option value={2}>2 - Imaging (X-ray, MRI)</option>
            <option value={3}>3 - Full Record</option>
          </select>
        </label>
        
        <label>
          Data content (will be hashed)
          <textarea 
            value={dataContent} 
            onChange={e => setDataContent(e.target.value)}
            placeholder="Enter medical data or reference (this will be hashed for privacy)"
            required
            style={{ minHeight: '80px' }}
          />
        </label>

        <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.25rem' }}>
          <button type="submit">Register Data</button>
          <button type="button" onClick={onCheckVersions}>Check Versions</button>
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

      {versionCount !== null && (
        <div style={{ 
          marginTop: '0.75rem', 
          padding: '0.75rem', 
          background: 'rgba(34, 197, 94, 0.1)', 
          borderRadius: '0.5rem',
          border: '1px solid rgba(34, 197, 94, 0.3)',
          fontSize: '0.9rem'
        }}>
          <p style={{ margin: 0 }}>
            <strong>Total versions for this data type:</strong> {versionCount}
          </p>
        </div>
      )}

      {latestData && (
        <div style={{ 
          marginTop: '1rem', 
          padding: '1rem', 
          background: 'rgba(59, 130, 246, 0.1)', 
          borderRadius: '0.5rem',
          border: '1px solid rgba(59, 130, 246, 0.3)'
        }}>
          <h3 style={{ marginTop: 0, fontSize: '1rem', color: '#60a5fa' }}>
            Latest Data (Version {latestData.version})
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
              {latestData.hash}
            </code>
            <p style={{ marginTop: '0.75rem', marginBottom: 0 }}>
              <strong>Registered:</strong> {latestData.timestamp}
            </p>
          </div>
        </div>
      )}

      <div style={{ 
        marginTop: '1rem', 
        padding: '0.75rem', 
        background: 'rgba(251, 191, 36, 0.1)', 
        borderRadius: '0.5rem',
        border: '1px solid rgba(251, 191, 36, 0.3)',
        fontSize: '0.85rem'
      }}>
        <p style={{ margin: 0, color: '#fbbf24' }}>
           <strong>Note:</strong> Each registration creates a new version. Grant consent to specific versions to allow authorized parties (doctors, researchers, insurance, etc.) to access them.
        </p>
      </div>
    </section>
  )
}
