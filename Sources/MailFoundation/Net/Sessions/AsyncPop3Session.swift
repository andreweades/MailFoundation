//
// AsyncPop3Session.swift
//
// Higher-level async POP3 session helpers.
//

@available(macOS 10.15, iOS 13.0, *)
public actor AsyncPop3Session {
    private let client: AsyncPop3Client

    public init(transport: AsyncTransport) {
        self.client = AsyncPop3Client(transport: transport)
    }

    public static func make(host: String, port: UInt16, backend: AsyncTransportBackend = .network) throws -> AsyncPop3Session {
        let transport = try AsyncTransportFactory.make(host: host, port: port, backend: backend)
        return AsyncPop3Session(transport: transport)
    }

    @discardableResult
    public func connect() async throws -> Pop3Response? {
        try await client.start()
        return await client.waitForResponse()
    }

    public func disconnect() async {
        _ = try? await client.send(.quit)
        await client.stop()
    }

    public func capability() async throws -> Pop3Capabilities? {
        try await client.capa()
    }

    public func authenticate(user: String, password: String) async throws -> (user: Pop3Response?, pass: Pop3Response?) {
        try await client.authenticate(user: user, password: password)
    }

    public func state() async -> AsyncPop3Client.State {
        await client.state
    }

    public func capabilities() async -> Pop3Capabilities? {
        await client.capabilities
    }
}
