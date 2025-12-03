import { useEffect, useState } from 'react'
import { walletClient } from './lib/viemClient'
import IdentityPanel from './components/IdentityPanel'
import ConsentPanel from './components/ConsentPanel'
import DataRegistryPanel from './components/DataRegistryPanel'
import DataAccessPanel from './components/DataAccessPanel'
import AuditLogPanel from './components/AuditLogPanel'
import './App.css'

function App() {
  const [account, setAccount] = useState<`0x${string}` | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<'patient' | 'doctor'>('patient')

  useEffect(() => {
    const connect = async () => {
      if (!walletClient) {
        setError('No Ethereum wallet detected. Install MetaMask and reload the page.')
        return
      }

      try {
        const addresses = await walletClient.getAddresses()
        if (addresses.length > 0) {
          setAccount(addresses[0])
        } else {
          const [addr] = await walletClient.requestAddresses()
          setAccount(addr)
        }
      } catch (err) {
        console.error(err)
        setError('Failed to connect to wallet. Check MetaMask and reload.')
      }
    }

    connect()
  }, [])

  if (error) {
    return (
      <div style={{ padding: '1rem', fontFamily: 'sans-serif' }}>
        <h1>Health Data Sharing</h1>
        <p style={{ color: 'red' }}>{error}</p>
      </div>
    )
  }

  if (!account) {
    return (
      <div style={{ padding: '1rem', fontFamily: 'sans-serif' }}>
        <h1>Health Data Sharing</h1>
        <p>Connecting to wallet…</p>
      </div>
    )
  }

  return (
    <div className="app-container">
      <div style={{ textAlign: 'center', marginBottom: '1rem' }}>
        <h1>Health Data Sharing</h1>
        <p style={{ margin: '0.25rem 0', fontSize: '0.85rem' }}>
          Connected as: <code>{account}</code>
        </p>
        <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: 0 }}>
          Secure blockchain-based medical data management with version control
        </p>
      </div>

      {/* Tab Navigation */}
      <div style={{ 
        display: 'flex', 
        gap: '1rem', 
        justifyContent: 'center',
        marginBottom: '1rem',
        borderBottom: '1px solid var(--card-border)',
        paddingBottom: '0.5rem'
      }}>
        <button 
          onClick={() => setActiveTab('patient')}
          style={{
            background: activeTab === 'patient' ? 'var(--accent)' : 'transparent',
            color: activeTab === 'patient' ? '#020617' : 'var(--text)',
            padding: '0.6rem 1.5rem',
            borderRadius: '0.5rem',
            fontWeight: 500,
            fontSize: '0.95rem'
          }}
        >
          Patient View
        </button>
        <button 
          onClick={() => setActiveTab('doctor')}
          style={{
            background: activeTab === 'doctor' ? 'var(--accent)' : 'transparent',
            color: activeTab === 'doctor' ? '#020617' : 'var(--text)',
            padding: '0.6rem 1.5rem',
            borderRadius: '0.5rem',
            fontWeight: 500,
            fontSize: '0.95rem'
          }}
        >
          Requester View
        </button>
      </div>

      {activeTab === 'patient' ? (
        <>
          <div style={{ marginBottom: '1rem' }}>
            <IdentityPanel account={account} />
          </div>
          <div className="cards-grid-two">
            <DataRegistryPanel account={account} />
            <ConsentPanel account={account} />
          </div>
        </>
      ) : (
        <>
          <div style={{ marginBottom: '1rem' }}>
            <IdentityPanel account={account} />
          </div>
          <div style={{ marginBottom: '1rem' }}>
            <DataAccessPanel account={account} />
          </div>
        </>
      )}

      <div style={{ marginTop: '1rem' }}>
        <AuditLogPanel account={account} />
      </div>
    </div>
  )
}

export default App
