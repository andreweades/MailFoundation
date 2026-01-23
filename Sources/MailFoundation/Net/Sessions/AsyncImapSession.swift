//
// AsyncImapSession.swift
//
// Higher-level async IMAP session helpers.
//

@available(macOS 10.15, iOS 13.0, *)
public actor AsyncImapSession {
    private let client: AsyncImapClient

    public init(transport: AsyncTransport) {
        self.client = AsyncImapClient(transport: transport)
    }

    public static func make(host: String, port: UInt16, backend: AsyncTransportBackend = .network) throws -> AsyncImapSession {
        let transport = try AsyncTransportFactory.make(host: host, port: port, backend: backend)
        return AsyncImapSession(transport: transport)
    }

    @discardableResult
    public func connect() async throws -> ImapResponse? {
        try await client.start()
        return await waitForGreeting()
    }

    public func disconnect() async {
        _ = try? await client.logout()
        await client.stop()
    }

    public func capability() async throws -> ImapResponse? {
        try await client.capability()
    }

    public func login(user: String, password: String) async throws -> ImapResponse? {
        try await client.login(user: user, password: password)
    }

    public func select(mailbox: String) async throws -> ImapResponse? {
        try await client.select(mailbox: mailbox)
    }

    public func close() async throws -> ImapResponse? {
        try await client.close()
    }

    public func state() async -> AsyncImapClient.State {
        await client.state
    }

    public func capabilities() async -> ImapCapabilities? {
        await client.capabilities
    }

    private func waitForGreeting() async -> ImapResponse? {
        while true {
            let messages = await client.nextMessages()
            if messages.isEmpty {
                return nil
            }
            for message in messages {
                if let response = message.response {
                    return response
                }
            }
        }
    }
}
