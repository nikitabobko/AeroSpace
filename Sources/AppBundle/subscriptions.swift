import Common
import Foundation
import Network

struct Subscriber {
    let connection: NWConnection
    let events: Set<ServerEventType>
}

@MainActor private var subscribers: [ObjectIdentifier: Subscriber] = [:]

@MainActor func addSubscriber(_ connection: NWConnection, events: Set<ServerEventType>) {
    let id = ObjectIdentifier(connection)
    subscribers[id] = Subscriber(connection: connection, events: events)
}

@MainActor func removeSubscriber(_ connection: NWConnection) {
    let id = ObjectIdentifier(connection)
    subscribers.removeValue(forKey: id)
}

@MainActor func broadcastEvent(_ event: ServerEvent) {
    for (id, subscriber) in subscribers {
        guard subscriber.events.contains(event.event) else { continue }
        Task { @MainActor in
            if await subscriber.connection.write(event) != nil {
                _ = subscribers.removeValue(forKey: id)
            }
        }
    }
}
