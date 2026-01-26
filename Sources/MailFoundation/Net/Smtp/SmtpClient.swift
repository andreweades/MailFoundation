//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//
// SmtpClient.swift
//
// Minimal scaffolding for SMTP client.
//

import Foundation

/// A low-level synchronous SMTP client for sending commands and receiving responses.
///
/// `SmtpClient` provides direct access to the SMTP protocol, allowing you to send
/// individual commands and handle responses. For most use cases, consider using
/// ``SmtpTransport`` which provides a higher-level API with automatic handling
/// of common operations.
///
/// ## Basic Usage
///
/// ```swift
/// let client = SmtpClient()
/// let transport = try TcpTransport(host: "smtp.example.com", port: 25)
/// client.connect(transport: transport)
///
/// // Read the greeting
/// let greeting = client.waitForResponse()
///
/// // Send EHLO
/// client.send(.ehlo("client.example.com"))
/// if let response = client.waitForResponse() {
///     client.handleEhloResponse(response)
/// }
///
/// // Check capabilities
/// if client.capabilities?.supports("STARTTLS") == true {
///     // Upgrade to TLS...
/// }
/// ```
///
/// ## Protocol Logging
///
/// You can capture the SMTP conversation for debugging by providing a protocol logger:
///
/// ```swift
/// let logger = StreamProtocolLogger(stream: FileHandle.standardError)
/// let client = SmtpClient(protocolLogger: logger)
/// ```
///
/// ## See Also
/// - ``SmtpTransport``
/// - ``AsyncSmtpClient``
/// - ``SmtpCommand``
/// - ``SmtpResponse``
public final class SmtpClient {
    /// Detects authentication secrets in protocol logs.
    private let detector = SmtpAuthenticationSecretDetector()

    /// Decodes incoming bytes into SMTP responses.
    private var decoder = SmtpResponseDecoder()

    /// The underlying transport for network I/O.
    private var transport: Transport?

    /// Represents the connection and authentication state of the SMTP client.
    public enum State: Sendable {
        /// The client is not connected to any server.
        case disconnected

        /// The client is connected but not authenticated.
        case connected

        /// The client is in the process of authenticating.
        case authenticating
    }

    /// The current state of the client.
    ///
    /// This reflects the connection and authentication status.
    public private(set) var state: State = .disconnected

    /// The server capabilities discovered during EHLO.
    ///
    /// This is populated after calling ``handleEhloResponse(_:)`` with a
    /// successful EHLO response. Use this to check for supported extensions
    /// before using them.
    public private(set) var capabilities: SmtpCapabilities?

    /// Whether the last write operation succeeded.
    ///
    /// Check this after sending commands to verify the data was written successfully.
    public private(set) var lastWriteSucceeded: Bool = true

    /// Whether the client has successfully authenticated.
    ///
    /// This is set to `true` after a successful authentication response.
    public private(set) var isAuthenticated: Bool = false

    /// The protocol logger for recording the SMTP conversation.
    ///
    /// Set this to capture the protocol exchange for debugging. Authentication
    /// secrets are automatically redacted from the log output.
    public var protocolLogger: ProtocolLoggerType {
        didSet {
            protocolLogger.authenticationSecretDetector = detector
        }
    }

    /// Whether the client is currently connected to a server.
    public private(set) var isConnected: Bool = false

    /// Creates a new SMTP client.
    ///
    /// - Parameter protocolLogger: The logger for recording protocol exchanges.
    ///   Defaults to ``NullProtocolLogger`` which discards all output.
    public init(protocolLogger: ProtocolLoggerType = NullProtocolLogger()) {
        self.protocolLogger = protocolLogger
        self.protocolLogger.authenticationSecretDetector = detector
    }

    /// Marks the client as connected to the specified URI.
    ///
    /// This method only updates the client state and logs the connection.
    /// It does not actually establish a network connection.
    ///
    /// - Parameter uri: The URI of the SMTP server for logging purposes.
    public func connect(to uri: URL) {
        protocolLogger.logConnect(uri)
        isConnected = true
        state = .connected
        isAuthenticated = false
    }

    /// Connects to an SMTP server using the provided transport.
    ///
    /// This opens the transport and updates the client state.
    ///
    /// - Parameter transport: The transport to use for network I/O.
    public func connect(transport: Transport) {
        self.transport = transport
        transport.open()
        isConnected = true
        state = .connected
        isAuthenticated = false
    }

    /// Disconnects from the server.
    ///
    /// This updates the client state but does not send a QUIT command or
    /// close the underlying transport. Call ``send(_:)-7v9gq`` with `.quit` first
    /// for a graceful disconnection.
    public func disconnect() {
        isConnected = false
        state = .disconnected
        isAuthenticated = false
    }

    /// Begins an authentication sequence.
    ///
    /// Call this before sending an AUTH command to enable authentication
    /// secret redaction in protocol logs and update the client state.
    public func beginAuthentication() {
        guard isConnected else { return }
        detector.isAuthenticating = true
        state = .authenticating
        isAuthenticated = false
    }

    /// Ends an authentication sequence.
    ///
    /// Call this after authentication completes (successfully or not) to
    /// restore normal logging behavior.
    public func endAuthentication() {
        detector.isAuthenticating = false
        state = isConnected ? .connected : .disconnected
    }

    /// Handles an authentication response from the server.
    ///
    /// Updates the client state based on the response code. A 2xx response
    /// indicates successful authentication; a 4xx or 5xx response indicates failure.
    ///
    /// - Parameter response: The server response to an AUTH command.
    public func handleAuthenticationResponse(_ response: SmtpResponse) {
        guard state == .authenticating else { return }
        detector.isAuthenticating = false
        if response.code >= 200 && response.code < 300 {
            state = .connected
            isAuthenticated = true
        } else if response.code >= 400 {
            state = .connected
            isAuthenticated = false
        }
    }

    /// Creates an SMTP command from a keyword and optional arguments.
    ///
    /// - Parameters:
    ///   - keyword: The command keyword (e.g., "EHLO", "MAIL").
    ///   - arguments: Optional arguments for the command.
    /// - Returns: A new ``SmtpCommand`` instance.
    public func makeCommand(_ keyword: String, arguments: String? = nil) -> SmtpCommand {
        SmtpCommand(keyword: keyword, arguments: arguments)
    }

    /// Creates an SMTP command from a command kind.
    ///
    /// - Parameter kind: The type of command to create.
    /// - Returns: A new ``SmtpCommand`` instance.
    public func makeCommand(_ kind: SmtpCommandKind) -> SmtpCommand {
        kind.command()
    }

    /// Sends an SMTP command by kind.
    ///
    /// If the command is an AUTH command, this automatically calls
    /// ``beginAuthentication()`` first.
    ///
    /// - Parameter kind: The type of command to send.
    /// - Returns: The bytes that were sent.
    @discardableResult
    public func send(_ kind: SmtpCommandKind) -> [UInt8] {
        if case .auth = kind {
            beginAuthentication()
        }
        return send(makeCommand(kind))
    }

    /// Sends an SMTP command.
    ///
    /// The command is serialized and written to the transport. Check
    /// ``lastWriteSucceeded`` after calling to verify the write completed.
    ///
    /// - Parameter command: The command to send.
    /// - Returns: The bytes that were sent.
    @discardableResult
    public func send(_ command: SmtpCommand) -> [UInt8] {
        let bytes = Array(command.serialized.utf8)
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        let written = transport?.write(bytes) ?? 0
        lastWriteSucceeded = written == bytes.count
        return bytes
    }

    /// Sends raw bytes to the server.
    ///
    /// Use this for sending data that is not a standard SMTP command,
    /// such as message content after a DATA command.
    ///
    /// - Parameter bytes: The bytes to send.
    /// - Returns: The bytes that were sent.
    @discardableResult
    public func sendRaw(_ bytes: [UInt8]) -> [UInt8] {
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        let written = transport?.write(bytes) ?? 0
        lastWriteSucceeded = written == bytes.count
        return bytes
    }

    /// Sends a line of text to the server.
    ///
    /// Automatically appends CRLF if not already present.
    ///
    /// - Parameter line: The line to send.
    /// - Returns: The bytes that were sent.
    @discardableResult
    public func sendLine(_ line: String) -> [UInt8] {
        let serialized: String
        if line.hasSuffix("\r\n") {
            serialized = line
        } else {
            serialized = "\(line)\r\n"
        }
        let bytes = Array(serialized.utf8)
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        let written = transport?.write(bytes) ?? 0
        lastWriteSucceeded = written == bytes.count
        return bytes
    }

    /// Parses and stores capabilities from an EHLO response.
    ///
    /// After receiving a successful EHLO response, call this method to
    /// parse the server capabilities. The capabilities are stored in
    /// the ``capabilities`` property.
    ///
    /// - Parameter response: The EHLO response from the server.
    /// - Returns: The parsed capabilities, or `nil` if parsing failed.
    @discardableResult
    public func handleEhloResponse(_ response: SmtpResponse) -> SmtpCapabilities? {
        let parsed = SmtpCapabilities.parseEhlo(response)
        if let parsed {
            capabilities = parsed
        }
        return parsed
    }

    /// Handles incoming bytes from the server.
    ///
    /// Decodes the bytes into SMTP responses and updates the client state
    /// for any authentication-related responses.
    ///
    /// - Parameter bytes: The bytes received from the server.
    /// - Returns: Any complete responses decoded from the input.
    public func handleIncoming(_ bytes: [UInt8]) -> [SmtpResponse] {
        protocolLogger.logServer(bytes, offset: 0, count: bytes.count)
        let responses = decoder.append(bytes)
        handleResponses(responses)
        return responses
    }

    /// Waits for a response from the server.
    ///
    /// Reads from the transport until a complete response is received
    /// or the maximum number of read attempts is reached.
    ///
    /// - Parameter maxReads: The maximum number of read attempts.
    /// - Returns: The first complete response, or `nil` if none was received.
    public func waitForResponse(maxReads: Int = 10) -> SmtpResponse? {
        var reads = 0
        while reads < maxReads {
            let responses = receive()
            if let first = responses.first {
                return first
            }
            reads += 1
        }
        return nil
    }

    /// Sends message data using the DATA command.
    ///
    /// This sends the DATA command, waits for the 354 intermediate response,
    /// then sends the message content with proper dot-stuffing and termination.
    ///
    /// - Parameters:
    ///   - message: The message content to send.
    ///   - maxReads: The maximum number of read attempts for responses.
    /// - Returns: The final server response, or `nil` if a response was not received.
    public func sendData(_ message: [UInt8], maxReads: Int = 10) -> SmtpResponse? {
        _ = send(.data)
        guard let intermediate = waitForResponse(maxReads: maxReads) else {
            return nil
        }
        guard intermediate.code == 354 else {
            return intermediate
        }

        let payload = SmtpDataWriter.prepare(message)
        protocolLogger.logClient(payload, offset: 0, count: payload.count)
        let written = transport?.write(payload) ?? 0
        lastWriteSucceeded = written == payload.count
        return waitForResponse(maxReads: maxReads)
    }

    /// Processes a batch of responses.
    ///
    /// Updates client state based on any authentication responses.
    ///
    /// - Parameter responses: The responses to process.
    public func handleResponses(_ responses: [SmtpResponse]) {
        guard !responses.isEmpty else { return }
        for response in responses where state == .authenticating {
            handleAuthenticationResponse(response)
        }
    }

    /// Reads and decodes available data from the transport.
    ///
    /// - Returns: Any complete responses decoded from the available data.
    public func receive() -> [SmtpResponse] {
        guard let transport else { return [] }
        let bytes = transport.readAvailable(maxLength: 4096)
        guard !bytes.isEmpty else { return [] }
        return handleIncoming(bytes)
    }
}
