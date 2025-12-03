// src/components/AuditLogPanel.tsx
import { useEffect, useState } from 'react'
import { publicClient } from '../lib/viemClient'
import { ACCESS_CONTROLLER_ADDRESS } from '../lib/contracts'
import { parseAbiItem } from 'viem'

type Props = { account: `0x${string}` }

type LogEntry = {
  requester: `0x${string}`
  patient: `0x${string}`
  dataType: number
  dataVersion: number
  success: boolean
  timestamp: bigint
}

const accessLoggedEvent = parseAbiItem(
  'event AccessLogged(address indexed requester, address indexed patient, uint8 dataType, uint32 dataVersion, bool success, uint256 timestamp)'
)

export default function AuditLogPanel({ account }: Props) {
  const [logs, setLogs] = useState<LogEntry[]>([])

  useEffect(() => {
    const loadLogs = async () => {
      const raw = await publicClient.getLogs({
        address: ACCESS_CONTROLLER_ADDRESS,
        event: accessLoggedEvent,
        args: { patient: account },
        fromBlock: 0n,
        toBlock: 'latest',
      })

      setLogs(raw.map((l) => ({
        requester: l.args.requester as `0x${string}`,
        patient: l.args.patient as `0x${string}`,
        dataType: Number(l.args.dataType),
        dataVersion: Number(l.args.dataVersion),
        success: l.args.success as boolean,
        timestamp: l.args.timestamp as bigint,
      })))
    }
    loadLogs().catch(console.error)
  }, [account])
  return (
    <section>
      <h2>Audit Log</h2>
      <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '-0.5rem' }}>
        Access history for your medical data
      </p>
      {logs.length === 0 ? (
        <p style={{ padding: '1rem', textAlign: 'center', color: 'var(--text-muted)' }}>
          No access events yet.
        </p>
      ) : (
        <div style={{ overflowX: 'auto' }}>
          <table>
            <thead>
              <tr>
                <th>Requester</th>
                <th>Type</th>
                <th>Version</th>
                <th>Status</th>
                <th>Time</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((l, i) => (
                <tr key={i}>
                  <td>
                    <code style={{ fontSize: '0.75rem' }}>
                      {l.requester.slice(0, 6)}...{l.requester.slice(-4)}
                    </code>
                  </td>
                  <td>{l.dataType}</td>
                  <td>v{l.dataVersion}</td>
                  <td>
                    <span style={{ 
                      color: l.success ? 'var(--accent)' : '#ef4444',
                      fontWeight: 500 
                    }}>
                      {l.success ? '✅' : '❌'}
                    </span>
                  </td>
                  <td style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                    {new Date(Number(l.timestamp) * 1000).toLocaleString()}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  )
}
