//
// AsyncPop3Client.swift
//
// Async POP3 client backed by AsyncTransport.
//

/// An asynchronous low-level POP3 client for direct protocol interaction.
///
/// The `AsyncPop3Client` actor provides direct async access to the POP3 protocol,
/// allowing you to send commands and process responses manually. For most use cases,
/// prefer the higher-level ``AsyncPop3MailStore`` class.
///
/// ## Overview
///
/// This actor is primarily intended for:
/// - Implementing custom POP3 extensions
/// - Debugging protocol issues
/// - Building custom mail clients with specific requirements
///
/// The client manages:
/// - Connection state tracking
/// - Authentication state machine
/// - Protocol logging
/// - Response decoding (single-line and multiline)
/// - Async data streaming via an internal queue
///
/// ## Usage
///
/// ```swift
/// let client = AsyncPop3Client(transport: myTransport)
///
/// // Start the client
/// try await client.start()
///
/// // Authenticate
/// let (userResponse, passResponse) = try await client.authenticate(
///     user: "username",
///     password: "password"
/// )
///
/// // Query capabilities
/// if let caps = try await client.capa() {
///     print("Server supports: \(caps.rawLines)")
/// }
///
/// // Stop the client
/// await client.stop()
/// ```
///
/// ## Thread Safety
///
/// This class is implemented as an actor, providing inherent thread safety
/// for concurrent access within Swift's structured concurrency model.
///
/// ## See Also
///
/// - ``AsyncPop3MailStore`` for high-level async operations
/// - ``Pop3Client`` for synchronous operations
/// - ``Pop3Command`` for command construction
@available(macOS 10.15, iOS 13.0, *)
public actor AsyncPop3Client {
    private enum AuthStep {
        case none
        case user
        case pass
    }

    private let transport: AsyncTransport
    private let queue = AsyncQueue<[UInt8]>()
    private var readerTask: Task<Void, Never>?
    private var decoder = Pop3ResponseDecoder()
    private var multilineDecoder = Pop3MultilineDecoder()
    private var authStep: AuthStep = .none

    /// The connection and authentication state of the client.
    public enum State: Sendable {
        /// The client is not connected to any server.
        case disconnected
        /// The client is connected but not yet authenticated.
        case connected
        /// The client is in the process of authenticating.
        case authenticating
        /// The client is connected and authenticated.
        case authenticated
    }

    /// The current state of the client.
    public private(set) var state: State = .disconnected

    /// The server's capabilities, if known.
    public private(set) var capabilities: Pop3Capabilities?

    /// The protocol logger for debugging.
    public var protocolLogger: ProtocolLoggerType

    /// Initializes a new async POP3 client.
    ///
    /// - Parameters:
    ///   - transport: The async transport to use for communication.
    ///   - protocolLogger: An optional logger for protocol-level debugging.
    public init(transport: AsyncTransport, protocolLogger: ProtocolLoggerType = NullProtocolLogger()) {
        self.transport = transport
        self.protocolLogger = protocolLogger
    }

    /// Starts the client and begins reading from the transport.
    ///
    /// This method starts the transport and spawns a background task to read
    /// incoming data into an internal queue.
    ///
    /// - Throws: An error if the transport fails to start.
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

    /// Stops the client and disconnects from the server.
    ///
    /// This method cancels the reader task, stops the transport, and resets state.
    public func stop() async {
        readerTask?.cancel()
        readerTask = nil
        await transport.stop()
        await queue.finish()
        state = .disconnected
    }

    /// Begins an authentication sequence.
    public func beginAuthentication() {
        guard state == .connected else { return }
        state = .authenticating
    }

    /// Ends an authentication sequence.
    public func endAuthentication() {
        if state == .authenticating {
            state = .authenticated
        }
    }

    /// Handles an authentication response from the server.
    ///
    /// - Parameter response: The server's response.
    public func handleAuthenticationResponse(_ response: Pop3Response) {
        guard state == .authenticating else { return }
        if response.isContinuation {
            state = .authenticating
            return
        }
        switch authStep {
        case .none:
            state = response.isSuccess ? .authenticated : .connected
        case .user:
            if response.isSuccess {
                state = .authenticating
                authStep = .pass
            } else {
                state = .connected
                authStep = .none
            }
        case .pass:
            state = response.isSuccess ? .authenticated : .connected
            authStep = .none
        }
    }

    /// Creates a POP3 command from a command kind.
    ///
    /// - Parameter kind: The command kind.
    /// - Returns: A ``Pop3Command`` ready to send.
    public func makeCommand(_ kind: Pop3CommandKind) -> Pop3Command {
        kind.command()
    }

    /// Sends a POP3 command to the server.
    ///
    /// This method automatically manages authentication state for USER, PASS,
    /// AUTH, and APOP commands.
    ///
    /// - Parameter kind: The command kind to send.
    /// - Returns: The serialized command bytes.
    /// - Throws: An error if the send fails.
    @discardableResult
    public func send(_ kind: Pop3CommandKind) async throws -> [UInt8] {
        switch kind {
        case .user:
            beginAuthentication()
            authStep = .user
        case .pass:
            beginAuthentication()
            authStep = .pass
        case .auth(_, _), .apop(_, _):
            beginAuthentication()
            authStep = .none
        default:
            break
        }
        let command = makeCommand(kind)
        return try await send(command)
    }

    /// Sends a POP3 command to the server.
    ///
    /// - Parameter command: The command to send.
    /// - Returns: The serialized command bytes.
    /// - Throws: An error if the send fails.
    @discardableResult
    public func send(_ command: Pop3Command) async throws -> [UInt8] {
        let bytes = Array(command.serialized.utf8)
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        try await transport.send(bytes)
        return bytes
    }

    /// Sends a raw line to the server.
    ///
    /// The line will be terminated with CRLF if not already present.
    ///
    /// - Parameter line: The line to send.
    /// - Returns: The serialized bytes.
    /// - Throws: An error if the send fails.
    @discardableResult
    public func sendLine(_ line: String) async throws -> [UInt8] {
        let serialized: String
        if line.hasSuffix("\r\n") {
            serialized = line
        } else {
            serialized = "\(line)\r\n"
        }
        let bytes = Array(serialized.utf8)
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        try await transport.send(bytes)
        return bytes
    }

    /// Prepares the decoder to expect a multiline response.
    public func expectMultilineResponse() {
        multilineDecoder.expectMultiline()
    }

    /// Gets the next batch of responses from the server.
    ///
    /// - Returns: The decoded responses, or nil if the connection closed.
    public func nextResponses() async -> [Pop3Response]? {
        guard let chunk = await queue.dequeue() else {
            return nil
        }
        protocolLogger.logServer(chunk, offset: 0, count: chunk.count)
        let responses = decoder.append(chunk)
        for response in responses where state == .authenticating {
            handleAuthenticationResponse(response)
        }
        return responses
    }

    /// Waits for a response from the server.
    ///
    /// - Returns: The first complete response, or nil if the connection closed.
    public func waitForResponse() async -> Pop3Response? {
        while let responses = await nextResponses() {
            if let first = responses.first {
                return first
            }
        }
        return nil
    }

    /// Gets the next batch of multiline response events.
    ///
    /// - Returns: The decoded events, or an empty array if the connection closed.
    public func nextEvents() async -> [Pop3ResponseEvent] {
        guard let chunk = await queue.dequeue() else {
            return []
        }
        protocolLogger.logServer(chunk, offset: 0, count: chunk.count)
        return multilineDecoder.append(chunk)
    }

    /// Gets the next raw chunk of data from the server.
    ///
    /// - Returns: The raw bytes, or an empty array if the connection closed.
    public func nextChunk() async -> [UInt8] {
        guard let chunk = await queue.dequeue() else {
            return []
        }
        protocolLogger.logServer(chunk, offset: 0, count: chunk.count)
        return chunk
    }

    /// Authenticates using the USER and PASS commands.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password.
    /// - Returns: A tuple containing the server responses.
    /// - Throws: An error if the send fails.
    public func authenticate(user: String, password: String) async throws -> (user: Pop3Response?, pass: Pop3Response?) {
        beginAuthentication()
        authStep = .user
        let userCommand = makeCommand(.user(user))
        _ = try await send(userCommand)
        let userResponse = await waitForResponse()
        if let userResponse, !userResponse.isSuccess {
            handleAuthenticationResponse(userResponse)
            return (user: userResponse, pass: nil)
        }

        authStep = .pass
        let passCommand = makeCommand(.pass(password))
        _ = try await send(passCommand)
        let passResponse = await waitForResponse()
        if let passResponse {
            handleAuthenticationResponse(passResponse)
        }
        return (user: userResponse, pass: passResponse)
    }

    /// Queries the server's capabilities.
    ///
    /// - Returns: The parsed capabilities, or nil if the query failed.
    /// - Throws: An error if the send fails.
    public func capa() async throws -> Pop3Capabilities? {
        expectMultilineResponse()
        let command = makeCommand(.capa)
        _ = try await send(command)

        while true {
            let events = await nextEvents()
            if events.isEmpty {
                return nil
            }
            for event in events {
                switch event {
                case let .single(response):
                    if !response.isSuccess {
                        return nil
                    }
                case .multiline:
                    if let parsed = Pop3Capabilities.parse(event) {
                        capabilities = parsed
                        return parsed
                    }
                }
            }
        }
    }
}
