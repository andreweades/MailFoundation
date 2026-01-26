//
// Pop3Session.swift
//
// Higher-level synchronous POP3 session helpers.
//

/// A higher-level synchronous POP3 session that manages protocol interactions.
///
/// `Pop3Session` wraps the low-level ``Pop3Client`` to provide a convenient
/// synchronous API for POP3 operations. It handles response waiting, error
/// conversion, and multiline response parsing.
///
/// ## Overview
///
/// This class provides methods for all standard POP3 operations:
/// - Connection and authentication
/// - Message listing (STAT, LIST, UIDL)
/// - Message retrieval (RETR, TOP)
/// - Message management (DELE, RSET, NOOP)
/// - Capabilities query (CAPA)
/// - TLS upgrade (STLS)
///
/// ## Usage
///
/// For most use cases, prefer ``Pop3MailStore`` which provides a higher-level
/// abstraction. Use `Pop3Session` directly when you need more control over
/// the protocol interactions.
///
/// ```swift
/// let session = Pop3Session(transport: myTransport)
///
/// // Connect and authenticate
/// let greeting = try session.connect()
/// try session.authenticate(user: "user@example.com", password: "secret")
///
/// // Get mailbox status
/// let stat = try session.stat()
/// print("Messages: \(stat.count)")
///
/// // Retrieve a message
/// let messageData = try session.retrData(1)
/// let message = try messageData.message()
///
/// // Clean up
/// session.disconnect()
/// ```
///
/// ## Threading
///
/// This class is not thread-safe. If you need concurrent access, use
/// ``AsyncPop3Session`` or synchronize access externally.
///
/// ## See Also
///
/// - ``Pop3MailStore`` for high-level mail store operations
/// - ``AsyncPop3Session`` for async/await support
/// - ``Pop3Client`` for low-level protocol access
public final class Pop3Session {
    private let client: Pop3Client
    private let transport: Transport
    private let maxReads: Int
    private var lastGreeting: Pop3Response?

    /// Initializes a new POP3 session.
    ///
    /// - Parameters:
    ///   - transport: The transport to use for communication.
    ///   - protocolLogger: An optional logger for protocol-level debugging.
    ///   - maxReads: Maximum read attempts when waiting for responses.
    public init(transport: Transport, protocolLogger: ProtocolLoggerType = NullProtocolLogger(), maxReads: Int = 10) {
        self.transport = transport
        self.client = Pop3Client(protocolLogger: protocolLogger)
        self.maxReads = maxReads
    }

    /// Connects to the POP3 server and waits for the greeting.
    ///
    /// - Returns: The server's greeting response.
    /// - Throws: ``SessionError/timeout`` if no response is received,
    ///           or ``Pop3CommandError`` if the server rejects the connection.
    @discardableResult
    public func connect() throws -> Pop3Response {
        client.connect(transport: transport)
        guard let greeting = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard greeting.isSuccess else {
            throw pop3CommandError(from: greeting)
        }
        lastGreeting = greeting
        return greeting
    }

    /// Disconnects from the POP3 server.
    ///
    /// This method sends the QUIT command, causing any messages marked for
    /// deletion to be permanently removed, then closes the transport.
    public func disconnect() {
        _ = client.send(.quit)
        transport.close()
        lastGreeting = nil
    }

    /// Authenticates using the USER and PASS commands.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password.
    /// - Returns: A tuple containing the responses to both commands.
    /// - Throws: An error if authentication fails.
    public func authenticate(user: String, password: String) throws -> (user: Pop3Response, pass: Pop3Response) {
        _ = client.send(.user(user))
        try ensureWrite()
        guard let userResponse = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard userResponse.isSuccess else {
            throw pop3CommandError(from: userResponse)
        }

        _ = client.send(.pass(password))
        try ensureWrite()
        guard let passResponse = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard passResponse.isSuccess else {
            throw pop3CommandError(from: passResponse)
        }

        return (user: userResponse, pass: passResponse)
    }

    /// Queries the server's capabilities.
    ///
    /// - Returns: The parsed capabilities.
    /// - Throws: An error if the CAPA command fails.
    public func capability() throws -> Pop3Capabilities {
        client.expectMultilineResponse()
        _ = client.send(.capa)
        try ensureWrite()

        let event = try waitForMultilineEvent()
        if case let .multiline(response, lines) = event {
            guard response.isSuccess else {
                throw pop3CommandError(from: response)
            }
            return Pop3Capabilities(rawLines: lines)
        }
        if case let .single(response) = event {
            throw pop3CommandError(from: response)
        }
        throw SessionError.timeout
    }

    /// Authenticates using APOP with a pre-computed digest.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - digest: The pre-computed MD5 digest.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails.
    public func apop(user: String, digest: String) throws -> Pop3Response {
        _ = client.send(.apop(user, digest))
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        return response
    }

    /// Authenticates using APOP with automatic digest computation.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - password: The password (used to compute the digest).
    ///   - greeting: Optional greeting response containing the challenge. If nil, uses the stored greeting.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails or APOP is not available.
    public func authenticateApop(
        user: String,
        password: String,
        greeting: Pop3Response? = nil
    ) throws -> Pop3Response {
        let challenge = (greeting ?? lastGreeting)?.apopChallenge
        guard let challenge else {
            throw SessionError.pop3Error(message: "APOP challenge is not available.")
        }
        guard let digest = Pop3Apop.digest(challenge: challenge, password: password) else {
            throw SessionError.pop3Error(message: "APOP digest is not available.")
        }
        return try apop(user: user, digest: digest)
    }

    /// Performs SASL authentication with a simple mechanism (no challenge-response).
    ///
    /// - Parameters:
    ///   - mechanism: The SASL mechanism name.
    ///   - initialResponse: Optional initial response data.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails.
    public func auth(mechanism: String, initialResponse: String? = nil) throws -> Pop3Response {
        _ = client.send(.auth(mechanism, initialResponse: initialResponse))
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        return response
    }

    /// Performs SASL authentication with challenge-response.
    ///
    /// - Parameters:
    ///   - mechanism: The SASL mechanism name.
    ///   - initialResponse: Optional initial response data.
    ///   - responder: A closure that generates responses to server challenges.
    /// - Returns: The server's final response.
    /// - Throws: An error if authentication fails.
    public func auth(
        mechanism: String,
        initialResponse: String? = nil,
        responder: (String) throws -> String
    ) throws -> Pop3Response {
        _ = client.send(.auth(mechanism, initialResponse: initialResponse))
        try ensureWrite()
        guard var response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }

        while response.isContinuation {
            let reply = try responder(response.message)
            _ = client.sendLine(reply)
            try ensureWrite()
            guard let next = client.waitForResponse(maxReads: maxReads) else {
                throw SessionError.timeout
            }
            response = next
        }

        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        return response
    }

    /// Performs SASL authentication using a ``Pop3Authentication`` configuration.
    ///
    /// - Parameter authentication: The authentication configuration.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails.
    public func authenticate(_ authentication: Pop3Authentication) throws -> Pop3Response {
        if let responder = authentication.responder {
            return try auth(
                mechanism: authentication.mechanism,
                initialResponse: authentication.initialResponse,
                responder: responder
            )
        }
        return try auth(
            mechanism: authentication.mechanism,
            initialResponse: authentication.initialResponse
        )
    }

    /// Authenticates using CRAM-MD5.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - password: The password.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails or CRAM-MD5 is unavailable.
    public func authenticateCramMd5(user: String, password: String) throws -> Pop3Response {
        guard let authentication = Pop3Sasl.cramMd5(username: user, password: password) else {
            throw SessionError.pop3Error(message: "CRAM-MD5 is not available.")
        }
        return try authenticate(authentication)
    }

    /// Authenticates using XOAUTH2.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - accessToken: The OAuth 2.0 access token.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails.
    public func authenticateXoauth2(user: String, accessToken: String) throws -> Pop3Response {
        let authentication = Pop3Sasl.xoauth2(username: user, accessToken: accessToken)
        return try authenticate(authentication)
    }

    /// Authenticates using SASL with automatic mechanism selection.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - password: The password.
    ///   - capabilities: Optional capabilities. If nil, queries the server.
    ///   - mechanisms: Optional list of allowed mechanisms.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails or no mechanism is supported.
    public func authenticateSasl(
        user: String,
        password: String,
        capabilities: Pop3Capabilities? = nil,
        mechanisms: [String]? = nil
    ) throws -> Pop3Response {
        let availableMechanisms: [String]
        if let mechanisms {
            availableMechanisms = mechanisms
        } else if let capabilities {
            availableMechanisms = capabilities.saslMechanisms()
        } else {
            availableMechanisms = try capability().saslMechanisms()
        }

        guard let authentication = Pop3Sasl.chooseAuthentication(
            username: user,
            password: password,
            mechanisms: availableMechanisms
        ) else {
            throw SessionError.pop3Error(message: "No supported SASL mechanisms.")
        }
        return try authenticate(authentication)
    }

    /// Authenticates using SASL with an OAuth access token.
    ///
    /// - Parameters:
    ///   - user: The username.
    ///   - accessToken: The OAuth 2.0 access token.
    ///   - capabilities: Optional capabilities. If nil, queries the server.
    ///   - mechanisms: Optional list of allowed mechanisms.
    /// - Returns: The server's response.
    /// - Throws: An error if authentication fails or XOAUTH2 is not supported.
    public func authenticateSasl(
        user: String,
        accessToken: String,
        capabilities: Pop3Capabilities? = nil,
        mechanisms: [String]? = nil
    ) throws -> Pop3Response {
        let availableMechanisms: [String]
        if let mechanisms {
            availableMechanisms = mechanisms
        } else if let capabilities {
            availableMechanisms = capabilities.saslMechanisms()
        } else {
            availableMechanisms = try capability().saslMechanisms()
        }

        guard availableMechanisms.contains(where: { $0.caseInsensitiveCompare("XOAUTH2") == .orderedSame }) else {
            throw SessionError.pop3Error(message: "XOAUTH2 is not supported.")
        }
        return try authenticateXoauth2(user: user, accessToken: accessToken)
    }

    /// Sends a NOOP command.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if not authenticated or the command fails.
    public func noop() throws -> Pop3Response {
        try ensureAuthenticated()
        _ = client.send(.noop)
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        return response
    }

    /// Resets the session, unmarking messages marked for deletion.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if not authenticated or the command fails.
    public func rset() throws -> Pop3Response {
        try ensureAuthenticated()
        _ = client.send(.rset)
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        return response
    }

    /// Marks a message for deletion.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The server's response.
    /// - Throws: An error if not authenticated or the command fails.
    public func dele(_ index: Int) throws -> Pop3Response {
        try ensureAuthenticated()
        _ = client.send(.dele(index))
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        return response
    }

    /// Gets the size of a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The list item containing the message size.
    /// - Throws: An error if not authenticated or the command fails.
    public func list(_ index: Int) throws -> Pop3ListItem {
        try ensureAuthenticated()
        _ = client.send(.list(index))
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        if let item = Pop3ListItem.parseLine(response.message) {
            return item
        }
        throw pop3CommandError(from: response)
    }

    /// Gets the unique identifier for a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The UIDL item containing the unique identifier.
    /// - Throws: An error if not authenticated or the command fails.
    public func uidl(_ index: Int) throws -> Pop3UidlItem {
        try ensureAuthenticated()
        _ = client.send(.uidl(index))
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        if let item = Pop3UidlItem.parseLine(response.message) {
            return item
        }
        throw pop3CommandError(from: response)
    }

    /// Retrieves a message as an array of lines.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as lines.
    /// - Throws: An error if not authenticated or the command fails.
    public func retr(_ index: Int) throws -> [String] {
        try ensureAuthenticated()
        client.expectMultilineResponse()
        _ = client.send(.retr(index))
        try ensureWrite()
        let event = try waitForMultilineEvent()
        if case let .multiline(response, lines) = event {
            guard response.isSuccess else {
                throw pop3CommandError(from: response)
            }
            return lines
        }
        if case let .single(response) = event {
            throw pop3CommandError(from: response)
        }
        throw SessionError.timeout
    }

    /// Retrieves a message as structured data.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message data.
    /// - Throws: An error if not authenticated or the command fails.
    public func retrData(_ index: Int) throws -> Pop3MessageData {
        try ensureAuthenticated()
        _ = client.send(.retr(index))
        try ensureWrite()
        let (response, data) = try waitForMultilineDataResponse()
        return Pop3MessageData(response: response, data: data)
    }

    /// Retrieves a message as raw bytes.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as bytes.
    /// - Throws: An error if not authenticated or the command fails.
    public func retrRaw(_ index: Int) throws -> [UInt8] {
        try ensureAuthenticated()
        _ = client.send(.retr(index))
        try ensureWrite()
        return try waitForMultilineData()
    }

    /// Retrieves a message in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - sink: A closure called with each chunk of data.
    /// - Throws: An error if not authenticated or the command fails.
    public func retrStream(_ index: Int, sink: ([UInt8]) throws -> Void) throws {
        try ensureAuthenticated()
        _ = client.send(.retr(index))
        try ensureWrite()
        try streamMultilineData(into: sink)
    }

    /// Retrieves message headers and partial body.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The headers and body lines.
    /// - Throws: An error if not authenticated or the command fails.
    public func top(_ index: Int, lines: Int) throws -> [String] {
        try ensureAuthenticated()
        client.expectMultilineResponse()
        _ = client.send(.top(index, lines: lines))
        try ensureWrite()
        let event = try waitForMultilineEvent()
        if case let .multiline(response, lines) = event {
            guard response.isSuccess else {
                throw pop3CommandError(from: response)
            }
            return lines
        }
        if case let .single(response) = event {
            throw pop3CommandError(from: response)
        }
        throw SessionError.timeout
    }

    /// Retrieves message headers and partial body as structured data.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The message data.
    /// - Throws: An error if not authenticated or the command fails.
    public func topData(_ index: Int, lines: Int) throws -> Pop3MessageData {
        try ensureAuthenticated()
        _ = client.send(.top(index, lines: lines))
        try ensureWrite()
        let (response, data) = try waitForMultilineDataResponse()
        return Pop3MessageData(response: response, data: data)
    }

    /// Retrieves message headers and partial body as raw bytes.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The data as bytes.
    /// - Throws: An error if not authenticated or the command fails.
    public func topRaw(_ index: Int, lines: Int) throws -> [UInt8] {
        try ensureAuthenticated()
        _ = client.send(.top(index, lines: lines))
        try ensureWrite()
        return try waitForMultilineData()
    }

    /// Retrieves message headers and partial body in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    ///   - sink: A closure called with each chunk of data.
    /// - Throws: An error if not authenticated or the command fails.
    public func topStream(_ index: Int, lines: Int, sink: ([UInt8]) throws -> Void) throws {
        try ensureAuthenticated()
        _ = client.send(.top(index, lines: lines))
        try ensureWrite()
        try streamMultilineData(into: sink)
    }

    /// Lists all messages with their sizes.
    ///
    /// - Returns: An array of list items.
    /// - Throws: An error if not authenticated or the command fails.
    public func list() throws -> [Pop3ListItem] {
        try ensureAuthenticated()
        client.expectMultilineResponse()
        _ = client.send(.list(nil))
        try ensureWrite()
        let event = try waitForMultilineEvent()
        if case let .multiline(response, lines) = event {
            guard response.isSuccess else {
                throw pop3CommandError(from: response)
            }
            return Pop3ListParser.parse(lines)
        }
        if case let .single(response) = event {
            throw pop3CommandError(from: response)
        }
        throw SessionError.timeout
    }

    /// Lists unique identifiers for all messages.
    ///
    /// - Returns: An array of UIDL items.
    /// - Throws: An error if not authenticated or the command fails.
    public func uidl() throws -> [Pop3UidlItem] {
        try ensureAuthenticated()
        client.expectMultilineResponse()
        _ = client.send(.uidl(nil))
        try ensureWrite()
        let event = try waitForMultilineEvent()
        if case let .multiline(response, lines) = event {
            guard response.isSuccess else {
                throw pop3CommandError(from: response)
            }
            return Pop3UidlParser.parse(lines)
        }
        if case let .single(response) = event {
            throw pop3CommandError(from: response)
        }
        throw SessionError.timeout
    }

    /// Gets mailbox statistics.
    ///
    /// - Returns: The message count and total size.
    /// - Throws: An error if not authenticated or the command fails.
    public func stat() throws -> Pop3StatResponse {
        try ensureAuthenticated()
        _ = client.send(.stat)
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        if let stat = Pop3StatResponse.parse(response) {
            return stat
        }
        throw pop3CommandError(from: response)
    }

    /// Gets the highest accessed message number.
    ///
    /// - Returns: The highest accessed message number.
    /// - Throws: An error if not authenticated or the command fails.
    public func last() throws -> Int {
        try ensureAuthenticated()
        _ = client.send(.last)
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess, let value = Int(response.message) else {
            throw pop3CommandError(from: response)
        }
        return value
    }

    /// Retrieves a message and assembles it as bytes.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message as bytes.
    /// - Throws: An error if not authenticated or the command fails.
    public func retrBytes(_ index: Int) throws -> [UInt8] {
        let lines = try retr(index)
        return assembleBytes(from: lines)
    }

    /// Retrieves message headers and partial body and assembles as bytes.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The data as bytes.
    /// - Throws: An error if not authenticated or the command fails.
    public func topBytes(_ index: Int, lines: Int) throws -> [UInt8] {
        let result = try top(index, lines: lines)
        return assembleBytes(from: result)
    }

    /// Upgrades the connection to TLS using STARTTLS.
    ///
    /// - Parameter validateCertificate: Whether to validate the server's certificate.
    /// - Returns: The server's response.
    /// - Throws: An error if the transport doesn't support STARTTLS or the command fails.
    public func startTls(validateCertificate: Bool = true) throws -> Pop3Response {
        guard let tlsTransport = transport as? StartTlsTransport else {
            throw SessionError.startTlsNotSupported
        }
        _ = client.send(.stls)
        try ensureWrite()
        guard let response = client.waitForResponse(maxReads: maxReads) else {
            throw SessionError.timeout
        }
        guard response.isSuccess else {
            throw pop3CommandError(from: response)
        }
        tlsTransport.startTLS(validateCertificate: validateCertificate)
        return response
    }

    private func waitForMultilineEvent() throws -> Pop3ResponseEvent {
        var reads = 0
        while reads < maxReads {
            let events = client.receiveMultiline()
            if let event = events.first {
                return event
            }
            reads += 1
        }
        throw SessionError.timeout
    }

    private func waitForMultilineDataResponse() throws -> (Pop3Response, [UInt8]) {
        var decoder = Pop3MultilineByteDecoder()
        decoder.expectMultiline()
        var reads = 0
        while reads < maxReads {
            let bytes = transport.readAvailable(maxLength: 4096)
            if bytes.isEmpty {
                reads += 1
                continue
            }
            client.protocolLogger.logServer(bytes, offset: 0, count: bytes.count)
            let events = decoder.append(bytes)
            for event in events {
                switch event {
                case let .single(response):
                    throw pop3CommandError(from: response)
                case let .multiline(response, data):
                    guard response.isSuccess else {
                        throw pop3CommandError(from: response)
                    }
                    return (response, data)
                }
            }
        }
        throw SessionError.timeout
    }

    private func waitForMultilineData() throws -> [UInt8] {
        let (_, data) = try waitForMultilineDataResponse()
        return data
    }

    private func streamMultilineData(into sink: ([UInt8]) throws -> Void) throws {
        var lineBuffer = ByteLineBuffer()
        var reads = 0
        var awaitingStatus = true
        var isFirstLine = true

        while reads < maxReads {
            let bytes = transport.readAvailable(maxLength: 4096)
            if bytes.isEmpty {
                reads += 1
                continue
            }
            client.protocolLogger.logServer(bytes, offset: 0, count: bytes.count)
            let lines = lineBuffer.append(bytes)
            for line in lines {
                if awaitingStatus {
                    let text = String(decoding: line, as: UTF8.self)
                    if let response = Pop3Response.parse(text) {
                        if response.isSuccess {
                            awaitingStatus = false
                            continue
                        }
                        throw pop3CommandError(from: response)
                    }
                    continue
                }

                if line == [0x2e] {
                    return
                }

                let dataLine: [UInt8]
                if line.count >= 2, line[0] == 0x2e, line[1] == 0x2e {
                    dataLine = Array(line.dropFirst())
                } else {
                    dataLine = line
                }

                if isFirstLine {
                    try sink(dataLine)
                    isFirstLine = false
                } else {
                    var chunk: [UInt8] = [0x0D, 0x0A]
                    chunk.append(contentsOf: dataLine)
                    try sink(chunk)
                }
            }
        }

        throw SessionError.timeout
    }

    private func ensureWrite() throws {
        if !client.lastWriteSucceeded {
            throw SessionError.transportWriteFailed
        }
    }

    private func pop3CommandError(from response: Pop3Response) -> Pop3CommandError {
        Pop3CommandError(statusText: response.message)
    }

    private func ensureAuthenticated() throws {
        guard client.state == .authenticated else {
            throw SessionError.invalidState(expected: .authenticated, actual: state)
        }
    }

    private func assembleBytes(from lines: [String]) -> [UInt8] {
        guard !lines.isEmpty else { return [] }
        let joined = lines.joined(separator: "\r\n")
        return Array(joined.utf8)
    }
}

extension Pop3Session: MailService {
    public typealias ConnectResponse = Pop3Response

    public var state: MailServiceState {
        switch client.state {
        case .disconnected:
            return .disconnected
        case .connected, .authenticating:
            return .connected
        case .authenticated:
            return .authenticated
        }
    }

    public var isConnected: Bool { client.isConnected }

    public var isAuthenticated: Bool { client.state == .authenticated }
}
