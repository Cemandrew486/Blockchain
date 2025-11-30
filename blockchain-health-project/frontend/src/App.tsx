import { useEffect, useState } from 'react'
import { walletClient } from './lib/viemClient'
import IdentityPanel from './components/IdentityPanel'
import ConsentPanel from './components/ConsentPanel'
import AuditLogPanel from './components/AuditLogPanel'
import './App.css'

function App() {
  const [account, setAccount] = useState<`0x${string}` | null>(null)
  const [error, setError] = useState<string | null>(null)

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
        <h1>Health Data Sharing dApp</h1>
        <p style={{ color: 'red' }}>{error}</p>
      </div>
    )
  }

  if (!account) {
    return (
      <div style={{ padding: '1rem', fontFamily: 'sans-serif' }}>
        <h1>Health Data Sharing dApp</h1>
        <p>Connecting to wallet…</p>
      </div>
    )
  }

  return (
    <div className="app-container">
      <h1>Health Data Sharing dApp</h1>
      <p>
        Connected as: <code>{account}</code>
      </p>

      <div className="cards-grid">
        <section>
          <IdentityPanel account={account} />
        </section>

        <section>
          <ConsentPanel account={account} />
        </section>

        <section>
          <AuditLogPanel account={account} />
        </section>
      </div>
    </div>
  )


}

export default App
