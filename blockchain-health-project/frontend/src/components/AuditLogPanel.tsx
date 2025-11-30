// src/components/AuditLogPanel.tsx
import { useEffect, useState } from 'react'
import { publicClient } from '../lib/viemClient'
import { ACCESS_CONTROLLER_ADDRESS, accessControllerAbi } from '../lib/contracts'
import { parseAbiItem } from 'viem'

type Props = { account: `0x${string}` }

type LogEntry = {
  requester: `0x${string}`
  patient: `0x${string}`
  dataType: number
  success: boolean
  timestamp: bigint
}

const accessLoggedEvent = parseAbiItem(
  'event AccessLogged(address indexed requester, address indexed patient, uint8 dataType, bool success, uint256 timestamp)'
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
        success: l.args.success as boolean,
        timestamp: l.args.timestamp as bigint,
      })))
    }
    loadLogs().catch(console.error)
  }, [account])

  return (
    <section>
      <h2>3. Audit Log</h2>
      {logs.length === 0 ? (
        <p>No access events yet.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>Requester</th>
              <th>Data type</th>
              <th>Success</th>
              <th>Timestamp (unix)</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((l, i) => (
              <tr key={i}>
                <td><code>{l.requester}</code></td>
                <td>{l.dataType}</td>
                <td>{l.success ? '✔' : '✘'}</td>
                <td>{l.timestamp.toString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  )
}
