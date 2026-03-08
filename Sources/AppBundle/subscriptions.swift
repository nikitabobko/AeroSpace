import Common
import Foundation
import Network

private struct Subscriber {
    let connection: NWConnection
    let events: Set<ServerEventType>
}

@MainActor private var subscribers: [UniqueToken: Subscriber] = [:]

@MainActor
func handleSubscribeAndWaitTillError(_ connection: NWConnection, _ args: SubscribeCmdArgs) async {
    let id = UniqueToken()
    subscribers[id] = Subscriber(connection: connection, events: args.events)
    defer { subscribers.removeValue(forKey: id) }
    if args.sendInitial {
        let f = focus
        for eventType in args.events {
            let event: ServerEvent
            switch eventType {
                case .focusChanged:
                    event = .focusChanged(windowId: f.windowOrNil?.windowId, workspace: f.workspace.name)
                case .workspaceChanged:
                    event = .workspaceChanged(workspace: f.workspace.name, prevWorkspace: f.workspace.name)
                case .modeChanged:
                    event = .modeChanged(mode: activeMode)
                case .focusedMonitorChanged:
                    event = .focusedMonitorChanged(
                        workspace: f.workspace.name,
                        monitorId_oneBased: f.workspace.workspaceMonitor.monitorId_oneBased ?? 0,
                    )
                case .windowDetected, .bindingTriggered: continue
            }
            _ = await connection.writeAtomic(event, jsonEncoder)
        }
    }

    // Keep connection alive - wait for client to disconnect
    await connection.readTillError()
}

private let jsonEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
    return e
}()

func broadcastEvent(_ event: ServerEvent) {
    Task { @MainActor in
        for (id, subscriber) in subscribers {
            guard subscriber.events.contains(event.eventType) else { continue }
            if await subscriber.connection.writeAtomic(event, jsonEncoder) != nil {
                _ = subscribers.removeValue(forKey: id)
            }
        }
    }
}
