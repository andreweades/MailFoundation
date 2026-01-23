//
// AsyncImapClient.swift
//
// Async IMAP client backed by AsyncTransport.
//

@available(macOS 10.15, iOS 13.0, *)
public actor AsyncImapClient {
    private let transport: AsyncTransport
    private let queue = AsyncQueue<[UInt8]>()
    private var readerTask: Task<Void, Never>?
    private var literalDecoder = ImapLiteralDecoder()
    private var tagGenerator = ImapTagGenerator()

    public enum State: Sendable {
        case disconnected
        case connected
        case authenticating
        case authenticated
        case selected
    }

    public private(set) var state: State = .disconnected
    public private(set) var capabilities: ImapCapabilities?
    public var protocolLogger: ProtocolLoggerType

    public init(transport: AsyncTransport, protocolLogger: ProtocolLoggerType = NullProtocolLogger()) {
        self.transport = transport
        self.protocolLogger = protocolLogger
    }

    public func start() async throws {
        try await transport.start()
        state = .connected
        readerTask = Task {
            for await chunk in transport.incoming {
                await queue.enqueue(chunk)
            }
            await queue.finish()
        }
    }

    public func stop() async {
        readerTask?.cancel()
        readerTask = nil
        await transport.stop()
        await queue.finish()
        state = .disconnected
    }

    public func makeCommand(_ kind: ImapCommandKind) -> ImapCommand {
        let tag = tagGenerator.nextTag()
        return kind.command(tag: tag)
    }

    @discardableResult
    public func send(_ kind: ImapCommandKind) async throws -> ImapCommand {
        let command = makeCommand(kind)
        if case .login = kind {
            state = .authenticating
        } else if case .authenticate = kind {
            state = .authenticating
        }
        _ = try await send(command)
        return command
    }

    @discardableResult
    public func send(_ command: ImapCommand) async throws -> [UInt8] {
        let bytes = Array(command.serialized.utf8)
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        try await transport.send(bytes)
        return bytes
    }

    public func sendLiteral(_ bytes: [UInt8]) async throws {
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        try await transport.send(bytes)
    }

    public func nextMessages() async -> [ImapLiteralMessage] {
        let chunk = await queue.dequeue()
        guard let chunk else {
            return []
        }
        protocolLogger.logServer(chunk, offset: 0, count: chunk.count)
        let messages = literalDecoder.append(chunk)
        for message in messages {
            if let response = message.response {
                handleResponse(response)
            }
            if let parsed = ImapCapabilities.parse(from: message.line) {
                capabilities = parsed
            }
        }
        return messages
    }

    public func waitForContinuation() async -> ImapResponse? {
        while true {
            let messages = await nextMessages()
            if messages.isEmpty {
                return nil
            }
            for message in messages {
                if let response = message.response, case .continuation = response.kind {
                    return response
                }
            }
        }
    }

    public func waitForTagged(_ tag: String) async -> ImapResponse? {
        while true {
            let messages = await nextMessages()
            if messages.isEmpty {
                return nil
            }
            for message in messages {
                if let response = message.response {
                    if case let .tagged(foundTag) = response.kind, foundTag == tag {
                        return response
                    }
                }
            }
        }
    }

    public func capability() async throws -> ImapResponse? {
        let command = makeCommand(.capability)
        _ = try await send(command)
        return await waitForTagged(command.tag)
    }

    public func login(user: String, password: String) async throws -> ImapResponse? {
        state = .authenticating
        let command = makeCommand(.login(user, password))
        _ = try await send(command)
        let response = await waitForTagged(command.tag)
        if response?.status == .ok {
            state = .authenticated
        } else if response != nil {
            state = .connected
        }
        return response
    }

    public func select(mailbox: String) async throws -> ImapResponse? {
        let command = makeCommand(.select(mailbox))
        _ = try await send(command)
        let response = await waitForTagged(command.tag)
        if response?.status == .ok {
            state = .selected
        }
        return response
    }

    public func close() async throws -> ImapResponse? {
        let command = makeCommand(.close)
        _ = try await send(command)
        let response = await waitForTagged(command.tag)
        if response?.status == .ok {
            state = .authenticated
        }
        return response
    }

    public func logout() async throws -> ImapResponse? {
        let command = makeCommand(.logout)
        _ = try await send(command)
        let response = await waitForTagged(command.tag)
        if response?.status == .ok || response?.status == .bye {
            state = .disconnected
        }
        return response
    }

    private func handleResponse(_ response: ImapResponse) {
        if case .untagged = response.kind {
            if response.status == .preauth {
                state = .authenticated
            } else if response.status == .bye {
                state = .disconnected
            }
            return
        }

        if state == .authenticating, response.status == .ok {
            state = .authenticated
        }
    }
}
