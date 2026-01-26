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
// Pop3Client.swift
//
// Minimal scaffolding for POP3 client.
//

import Foundation

/// A low-level POP3 client for direct protocol interaction.
///
/// The `Pop3Client` class provides direct access to the POP3 protocol, allowing you to
/// send commands and process responses manually. For most use cases, prefer the higher-level
/// ``Pop3MailStore`` or ``AsyncPop3MailStore`` classes.
///
/// ## Overview
///
/// This class is primarily intended for:
/// - Implementing custom POP3 extensions
/// - Debugging protocol issues
/// - Building custom mail clients with specific requirements
///
/// The client manages:
/// - Connection state tracking
/// - Authentication state machine
/// - Protocol logging with secret detection
/// - Response decoding (single-line and multiline)
///
/// ## Usage
///
/// ```swift
/// let client = Pop3Client()
///
/// // Connect to a server
/// client.connect(transport: myTransport)
///
/// // Send authentication commands
/// client.send(.user("username"))
/// if let response = client.waitForResponse() {
///     client.handleAuthenticationResponse(response)
/// }
///
/// client.send(.pass("password"))
/// if let response = client.waitForResponse() {
///     client.handleAuthenticationResponse(response)
/// }
///
/// // Query capabilities
/// client.beginCapabilityQuery()
/// while let events = client.receiveMultiline() {
///     // Process capability events
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3MailStore`` for high-level synchronous operations
/// - ``AsyncPop3Client`` for async/await support
/// - ``Pop3Command`` for command construction
public final class Pop3Client {
    private enum AuthStep {
        case none
        case user
        case pass
    }

    private let detector = Pop3AuthenticationSecretDetector()
    private var decoder = Pop3ResponseDecoder()
    private var multilineDecoder = Pop3MultilineDecoder()
    private var transport: Transport?
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
    ///
    /// This property is populated after calling ``beginCapabilityQuery()`` and
    /// processing the response with ``handleCapabilitiesEvent(_:)``.
    public private(set) var capabilities: Pop3Capabilities?

    /// Whether the last write operation succeeded.
    ///
    /// This can be used to detect transport failures during command sending.
    public private(set) var lastWriteSucceeded: Bool = true

    /// The protocol logger for debugging.
    ///
    /// The logger records all data sent and received, with automatic detection
    /// and masking of authentication secrets.
    public var protocolLogger: ProtocolLoggerType {
        didSet {
            protocolLogger.authenticationSecretDetector = detector
        }
    }

    /// Whether the client is currently connected.
    public private(set) var isConnected: Bool = false

    /// Initializes a new POP3 client.
    ///
    /// - Parameter protocolLogger: An optional logger for protocol-level debugging.
    public init(protocolLogger: ProtocolLoggerType = NullProtocolLogger()) {
        self.protocolLogger = protocolLogger
        self.protocolLogger.authenticationSecretDetector = detector
    }

    /// Connects to a POP3 server using a URL.
    ///
    /// This method logs the connection attempt but does not establish a network connection.
    /// Use ``connect(transport:)`` to provide an actual transport.
    ///
    /// - Parameter uri: The URL of the POP3 server.
    public func connect(to uri: URL) {
        protocolLogger.logConnect(uri)
        isConnected = true
        state = .connected
    }

    /// Connects to a POP3 server using an existing transport.
    ///
    /// - Parameter transport: The transport to use for communication.
    public func connect(transport: Transport) {
        self.transport = transport
        transport.open()
        isConnected = true
        state = .connected
    }

    /// Disconnects from the server.
    ///
    /// This method updates the internal state but does not close the transport.
    public func disconnect() {
        isConnected = false
        state = .disconnected
    }

    /// Begins an authentication sequence.
    ///
    /// Call this before sending authentication commands to enable secret detection
    /// in the protocol logger.
    public func beginAuthentication() {
        guard isConnected else { return }
        detector.isAuthenticating = true
        state = .authenticating
    }

    /// Ends an authentication sequence.
    ///
    /// Call this after authentication completes (successfully or not) to disable
    /// secret detection in the protocol logger.
    public func endAuthentication() {
        detector.isAuthenticating = false
        state = isConnected ? .authenticated : .disconnected
        authStep = .none
    }

    /// Handles an authentication response from the server.
    ///
    /// This method updates the client state based on the response and manages
    /// the USER/PASS authentication flow.
    ///
    /// - Parameter response: The server's response.
    public func handleAuthenticationResponse(_ response: Pop3Response) {
        if response.isContinuation {
            detector.isAuthenticating = true
            state = .authenticating
            return
        }
        detector.isAuthenticating = false
        switch authStep {
        case .none:
            state = response.isSuccess ? .authenticated : .connected
        case .user:
            if response.isSuccess {
                detector.isAuthenticating = true
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

    /// Creates a POP3 command from a keyword and optional arguments.
    ///
    /// - Parameters:
    ///   - keyword: The POP3 command keyword (e.g., "USER", "PASS", "STAT").
    ///   - arguments: Optional arguments for the command.
    /// - Returns: A ``Pop3Command`` ready to send.
    public func makeCommand(_ keyword: String, arguments: String? = nil) -> Pop3Command {
        Pop3Command(keyword: keyword, arguments: arguments)
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
    @discardableResult
    public func send(_ kind: Pop3CommandKind) -> [UInt8] {
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
        return send(makeCommand(kind))
    }

    /// Sends a POP3 command to the server.
    ///
    /// - Parameter command: The command to send.
    /// - Returns: The serialized command bytes.
    @discardableResult
    public func send(_ command: Pop3Command) -> [UInt8] {
        let bytes = Array(command.serialized.utf8)
        protocolLogger.logClient(bytes, offset: 0, count: bytes.count)
        let written = transport?.write(bytes) ?? 0
        lastWriteSucceeded = written == bytes.count
        return bytes
    }

    /// Sends a raw line to the server.
    ///
    /// The line will be terminated with CRLF if not already present.
    ///
    /// - Parameter line: The line to send.
    /// - Returns: The serialized bytes.
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

    /// Prepares the decoder to expect a multiline response.
    ///
    /// Call this before sending a command that returns a multiline response
    /// (e.g., LIST, UIDL, RETR, TOP, CAPA).
    public func expectMultilineResponse() {
        multilineDecoder.expectMultiline()
    }

    /// Begins a capability query.
    ///
    /// This method sends the CAPA command and prepares to receive a multiline response.
    public func beginCapabilityQuery() {
        expectMultilineResponse()
        _ = send(makeCommand(.capa))
    }

    /// Handles incoming data from the server.
    ///
    /// - Parameter bytes: The received bytes.
    /// - Returns: Any complete responses that were decoded.
    public func handleIncoming(_ bytes: [UInt8]) -> [Pop3Response] {
        protocolLogger.logServer(bytes, offset: 0, count: bytes.count)
        let responses = decoder.append(bytes)
        handleResponses(responses)
        return responses
    }

    /// Handles incoming multiline data from the server.
    ///
    /// - Parameter bytes: The received bytes.
    /// - Returns: Any complete response events that were decoded.
    public func handleIncomingMultiline(_ bytes: [UInt8]) -> [Pop3ResponseEvent] {
        protocolLogger.logServer(bytes, offset: 0, count: bytes.count)
        return multilineDecoder.append(bytes)
    }

    /// Handles a capabilities event from the server.
    ///
    /// - Parameter event: The response event containing capabilities.
    /// - Returns: The parsed capabilities, or nil if parsing failed.
    public func handleCapabilitiesEvent(_ event: Pop3ResponseEvent) -> Pop3Capabilities? {
        let parsed = Pop3Capabilities.parse(event)
        if let parsed {
            capabilities = parsed
        }
        return parsed
    }

    /// Handles multiple responses from the server.
    ///
    /// This method updates authentication state for any authentication responses.
    ///
    /// - Parameter responses: The responses to handle.
    public func handleResponses(_ responses: [Pop3Response]) {
        guard !responses.isEmpty else { return }
        for response in responses where state == .authenticating {
            handleAuthenticationResponse(response)
        }
    }

    /// Waits for a response from the server.
    ///
    /// - Parameter maxReads: Maximum number of read attempts before giving up.
    /// - Returns: The first complete response, or nil if no response was received.
    public func waitForResponse(maxReads: Int = 10) -> Pop3Response? {
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

    /// Receives and processes data from the server.
    ///
    /// - Returns: Any complete responses that were decoded.
    public func receive() -> [Pop3Response] {
        guard let transport else { return [] }
        let bytes = transport.readAvailable(maxLength: 4096)
        guard !bytes.isEmpty else { return [] }
        return handleIncoming(bytes)
    }

    /// Receives and processes multiline data from the server.
    ///
    /// - Returns: Any complete response events that were decoded.
    public func receiveMultiline() -> [Pop3ResponseEvent] {
        guard let transport else { return [] }
        let bytes = transport.readAvailable(maxLength: 4096)
        guard !bytes.isEmpty else { return [] }
        return handleIncomingMultiline(bytes)
    }
}
