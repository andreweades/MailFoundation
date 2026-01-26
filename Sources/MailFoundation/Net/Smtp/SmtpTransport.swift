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
// SmtpTransport.swift
//
// MailTransport-based SMTP wrapper.
//

import MimeFoundation

/// A synchronous SMTP transport for sending email messages.
///
/// `SmtpTransport` provides a high-level API for connecting to an SMTP server,
/// authenticating, and sending messages. It handles the SMTP protocol details
/// internally, including capability negotiation, TLS upgrade, and various
/// sending modes (standard, pipelined, chunked).
///
/// ## Connecting and Authenticating
///
/// ```swift
/// // Create and connect
/// let transport = try SmtpTransport.make(
///     host: "smtp.example.com",
///     port: 587
/// )
/// try transport.connect()
///
/// // Get capabilities with EHLO
/// let capabilities = try transport.ehlo(domain: "client.example.com")
///
/// // Upgrade to TLS if available
/// if capabilities.supports("STARTTLS") {
///     try transport.startTls()
///     // Re-issue EHLO after TLS
///     _ = try transport.ehlo(domain: "client.example.com")
/// }
///
/// // Authenticate
/// try transport.authenticate(SmtpPlainAuthentication(
///     username: "user@example.com",
///     password: "secret"
/// ))
/// ```
///
/// ## Sending Messages
///
/// ```swift
/// // Simple send
/// let message = MimeMessage()
/// message.from = [MailboxAddress("sender@example.com")]
/// message.to = [MailboxAddress("recipient@example.com")]
/// message.subject = "Hello"
/// message.textBody = "Hello, World!"
///
/// try transport.send(message)
///
/// // Disconnect when done
/// transport.disconnect()
/// ```
///
/// ## Protocol Logging
///
/// You can capture the SMTP conversation for debugging:
///
/// ```swift
/// let logger = StreamProtocolLogger(stream: FileHandle.standardError)
/// let transport = try SmtpTransport.make(
///     host: "smtp.example.com",
///     port: 587,
///     protocolLogger: logger
/// )
/// ```
///
/// ## Proxy Support
///
/// Connect through a SOCKS or HTTP proxy:
///
/// ```swift
/// let proxy = ProxySettings(
///     type: .socks5,
///     host: "proxy.example.com",
///     port: 1080
/// )
/// let transport = try SmtpTransport.make(
///     host: "smtp.example.com",
///     port: 587,
///     proxy: proxy
/// )
/// ```
///
/// ## See Also
/// - ``AsyncSmtpTransport``
/// - ``SmtpCapabilities``
/// - ``SmtpResponse``
public final class SmtpTransport: MailTransportBase<SmtpResponse>, MailTransport {
    /// The underlying SMTP session that manages protocol details.
    private let session: SmtpSession

    /// Cached server capabilities from the last EHLO response.
    private var storedCapabilities: SmtpCapabilities?

    /// Creates a new SMTP transport connected to the specified server.
    ///
    /// This factory method creates the underlying network transport and wraps it
    /// in an `SmtpTransport`. Use this for most common connection scenarios.
    ///
    /// - Parameters:
    ///   - host: The SMTP server hostname or IP address.
    ///   - port: The port number (typically 25, 465, or 587).
    ///   - backend: The transport backend to use. Defaults to `.tcp`.
    ///   - proxy: Optional proxy settings for connecting through a proxy server.
    ///   - protocolLogger: Logger for recording the protocol exchange.
    ///   - maxReads: Maximum read attempts when waiting for responses.
    /// - Returns: A configured `SmtpTransport` ready to connect.
    /// - Throws: An error if the transport cannot be created.
    public static func make(
        host: String,
        port: Int,
        backend: TransportBackend = .tcp,
        proxy: ProxySettings? = nil,
        protocolLogger: ProtocolLoggerType = NullProtocolLogger(),
        maxReads: Int = 10
    ) throws -> SmtpTransport {
        let transport = try TransportFactory.make(host: host, port: port, backend: backend, proxy: proxy)
        return SmtpTransport(transport: transport, protocolLogger: protocolLogger, maxReads: maxReads)
    }

    /// Creates a new SMTP transport with an existing network transport.
    ///
    /// Use this initializer when you have a pre-configured transport or need
    /// custom transport configuration.
    ///
    /// - Parameters:
    ///   - transport: The underlying network transport.
    ///   - protocolLogger: Logger for recording the protocol exchange.
    ///   - maxReads: Maximum read attempts when waiting for responses.
    public init(
        transport: Transport,
        protocolLogger: ProtocolLoggerType = NullProtocolLogger(),
        maxReads: Int = 10
    ) {
        self.session = SmtpSession(transport: transport, protocolLogger: protocolLogger, maxReads: maxReads)
        super.init(protocolLogger: protocolLogger)
    }

    /// The protocol logger for recording the SMTP conversation.
    ///
    /// Set this to capture the protocol exchange for debugging. Authentication
    /// secrets are automatically redacted from the log output.
    public override var protocolLogger: ProtocolLoggerType {
        didSet {
            session.protocolLogger = protocolLogger
        }
    }

    /// The name of the protocol ("SMTP").
    public override var protocolName: String { "SMTP" }

    /// The server capabilities discovered during the last EHLO command.
    ///
    /// This is `nil` until ``ehlo(domain:)`` is called successfully.
    /// Capabilities may change after TLS upgrade or authentication.
    public var capabilities: SmtpCapabilities? { storedCapabilities }

    /// Connects to the SMTP server.
    ///
    /// This opens the network connection and waits for the server greeting.
    /// After connecting, you should call ``ehlo(domain:)`` to negotiate capabilities.
    ///
    /// - Returns: The server greeting response.
    /// - Throws: An error if the connection fails.
    @discardableResult
    public override func connect() throws -> SmtpResponse {
        let response = try session.connect()
        updateState(.connected)
        return response
    }

    /// Disconnects from the SMTP server.
    ///
    /// This closes the network connection. For a graceful disconnection,
    /// you should send a QUIT command first (which the session handles internally).
    public override func disconnect() {
        session.disconnect()
        updateState(.disconnected)
    }

    /// Sends an EHLO command and retrieves server capabilities.
    ///
    /// The EHLO command identifies the client to the server and retrieves the list
    /// of supported extensions. This should be called after connecting and again
    /// after upgrading to TLS.
    ///
    /// - Parameter domain: The client's domain name or IP address.
    /// - Returns: The server's advertised capabilities.
    /// - Throws: An error if the command fails.
    public func ehlo(domain: String) throws -> SmtpCapabilities {
        let capabilities = try session.ehlo(domain: domain)
        storedCapabilities = capabilities
        updateAuthenticationMechanisms(from: capabilities)
        return capabilities
    }

    /// Sends a HELO command for basic SMTP greeting.
    ///
    /// HELO is the original SMTP greeting command. Use ``ehlo(domain:)`` instead
    /// for servers that support ESMTP extensions.
    ///
    /// - Parameter domain: The client's domain name or IP address.
    /// - Returns: The server response.
    /// - Throws: An error if the command fails.
    public func helo(domain: String) throws -> SmtpResponse {
        try session.helo(domain: domain)
    }

    /// Sends a NOOP command to keep the connection alive.
    ///
    /// The NOOP command does nothing but can be used to prevent connection
    /// timeouts or to verify the connection is still active.
    ///
    /// - Returns: The server response.
    /// - Throws: An error if the command fails.
    public func noop() throws -> SmtpResponse {
        try session.noop()
    }

    /// Sends an RSET command to reset the mail transaction.
    ///
    /// This aborts any mail transaction in progress and clears all buffers
    /// and state tables. The connection remains open.
    ///
    /// - Returns: The server response.
    /// - Throws: An error if the command fails.
    public func rset() throws -> SmtpResponse {
        try session.rset()
    }

    /// Sends a VRFY command to verify a mailbox exists.
    ///
    /// Note: Many servers disable this command for security reasons.
    ///
    /// - Parameter argument: The mailbox or username to verify.
    /// - Returns: The raw server response.
    /// - Throws: An error if the command fails.
    public func vrfy(_ argument: String) throws -> SmtpResponse {
        try session.vrfy(argument)
    }

    /// Sends a VRFY command and returns a structured result.
    ///
    /// - Parameter argument: The mailbox or username to verify.
    /// - Returns: A structured result containing verification information.
    /// - Throws: An error if the command fails.
    public func vrfyResult(_ argument: String) throws -> SmtpVrfyResult {
        try session.vrfyResult(argument)
    }

    /// Sends an EXPN command to expand a mailing list.
    ///
    /// Note: Many servers disable this command for security reasons.
    ///
    /// - Parameter argument: The mailing list to expand.
    /// - Returns: The raw server response.
    /// - Throws: An error if the command fails.
    public func expn(_ argument: String) throws -> SmtpResponse {
        try session.expn(argument)
    }

    /// Sends an EXPN command and returns a structured result.
    ///
    /// - Parameter argument: The mailing list to expand.
    /// - Returns: A structured result containing the expanded addresses.
    /// - Throws: An error if the command fails.
    public func expnResult(_ argument: String) throws -> SmtpExpnResult {
        try session.expnResult(argument)
    }

    /// Sends a HELP command to request server help.
    ///
    /// - Parameter argument: Optional command name to get help for.
    /// - Returns: The raw server response.
    /// - Throws: An error if the command fails.
    public func help(_ argument: String? = nil) throws -> SmtpResponse {
        try session.help(argument)
    }

    /// Sends a HELP command and returns a structured result.
    ///
    /// - Parameter argument: Optional command name to get help for.
    /// - Returns: A structured result containing help information.
    /// - Throws: An error if the command fails.
    public func helpResult(_ argument: String? = nil) throws -> SmtpHelpResult {
        try session.helpResult(argument)
    }

    /// Upgrades the connection to TLS using STARTTLS.
    ///
    /// After a successful TLS upgrade, you must call ``ehlo(domain:)`` again
    /// to renegotiate capabilities, as the server may advertise different
    /// capabilities over a secure connection.
    ///
    /// - Parameter validateCertificate: Whether to validate the server certificate.
    /// - Returns: The server response to the STARTTLS command.
    /// - Throws: An error if the TLS upgrade fails.
    public func startTls(validateCertificate: Bool = true) throws -> SmtpResponse {
        let response = try session.startTls(validateCertificate: validateCertificate)
        storedCapabilities = nil
        updateAuthenticationMechanisms([])
        updateState(.connected)
        return response
    }

    /// Authenticates with the server using a SASL mechanism.
    ///
    /// - Parameters:
    ///   - mechanism: The SASL mechanism name (e.g., "PLAIN", "LOGIN").
    ///   - initialResponse: Optional initial response data (base64-encoded).
    /// - Returns: The server response.
    /// - Throws: An error if authentication fails.
    public func authenticate(mechanism: String, initialResponse: String? = nil) throws -> SmtpResponse {
        let response = try session.authenticate(mechanism: mechanism, initialResponse: initialResponse)
        updateState(.authenticated)
        return response
    }

    /// Authenticates with the server using an authentication provider.
    ///
    /// This method handles the complete SASL authentication exchange,
    /// including any challenge-response rounds.
    ///
    /// - Parameter authentication: The authentication provider.
    /// - Returns: The final server response.
    /// - Throws: An error if authentication fails.
    public func authenticate(_ authentication: SmtpAuthentication) throws -> SmtpResponse {
        let response = try session.authenticate(authentication)
        updateState(.authenticated)
        return response
    }

    /// Sends a message using the addresses from the message headers.
    ///
    /// The sender is extracted from the `Sender` or `From` header, and recipients
    /// are extracted from the `To`, `Cc`, and `Bcc` headers.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - options: Formatting options for the message.
    ///   - progress: Optional progress callback for tracking transfer.
    /// - Returns: The server response.
    /// - Throws: An error if sending fails.
    public func send(
        _ message: MimeMessage,
        options: FormatOptions = MailTransportFormatOptions.default,
        progress: TransferProgress? = nil
    ) throws -> SmtpResponse {
        try ensureConnected()
        try ensureInternationalSupport(options)
        let envelope = try MailTransportEnvelopeBuilder.build(for: message, options: options, progress: progress)
        let mailParameters = resolveMailParameters(nil, data: envelope.data, options: options)
        let response = try session.sendMail(
            from: envelope.sender.address,
            to: envelope.recipients.map { $0.address },
            data: envelope.data,
            mailParameters: mailParameters,
            rcptParameters: nil
        )
        notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
        return response
    }

    /// Sends a message with explicit sender and recipients.
    ///
    /// Use this method when you need to specify envelope addresses that differ
    /// from the message headers (e.g., for BCC handling or address rewriting).
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - sender: The envelope sender address.
    ///   - recipients: The envelope recipient addresses.
    ///   - options: Formatting options for the message.
    ///   - progress: Optional progress callback for tracking transfer.
    /// - Returns: The server response.
    /// - Throws: An error if sending fails.
    public func send(
        _ message: MimeMessage,
        sender: MailboxAddress,
        recipients: [MailboxAddress],
        options: FormatOptions = MailTransportFormatOptions.default,
        progress: TransferProgress? = nil
    ) throws -> SmtpResponse {
        try ensureConnected()
        try ensureInternationalSupport(options)
        let data = try MailTransportEnvelopeBuilder.encodeMessage(message, options: options, progress: progress)
        let mailParameters = resolveMailParameters(nil, data: data, options: options)
        let response = try session.sendMail(
            from: sender.address,
            to: recipients.map { $0.address },
            data: data,
            mailParameters: mailParameters,
            rcptParameters: nil
        )
        notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
        return response
    }

    /// Sends a message using chunked transfer if supported.
    ///
    /// Chunked transfer (BDAT command) allows sending messages without dot-stuffing,
    /// which is more efficient for binary content. Falls back to standard DATA
    /// command if the server does not support CHUNKING.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - chunkSize: The size of each chunk in bytes.
    ///   - options: Formatting options for the message.
    ///   - progress: Optional progress callback for tracking transfer.
    ///   - mailParameters: Additional MAIL FROM parameters.
    ///   - rcptParameters: Additional RCPT TO parameters.
    /// - Returns: The server response.
    /// - Throws: An error if sending fails.
    public func sendChunked(
        _ message: MimeMessage,
        chunkSize: Int = 4096,
        options: FormatOptions = MailTransportFormatOptions.default,
        progress: TransferProgress? = nil,
        mailParameters: SmtpMailFromParameters? = nil,
        rcptParameters: SmtpRcptToParameters? = nil
    ) throws -> SmtpResponse {
        try ensureConnected()
        try ensureInternationalSupport(options)
        let envelope = try MailTransportEnvelopeBuilder.build(for: message, options: options, progress: progress)
        let resolvedMailParameters = resolveMailParameters(mailParameters, data: envelope.data, options: options)
        let response: SmtpResponse
        if supportsCapability("CHUNKING") {
            response = try session.sendMailChunked(
                from: envelope.sender.address,
                to: envelope.recipients.map { $0.address },
                data: envelope.data,
                chunkSize: chunkSize,
                mailParameters: resolvedMailParameters,
                rcptParameters: rcptParameters
            )
        } else {
            response = try session.sendMail(
                from: envelope.sender.address,
                to: envelope.recipients.map { $0.address },
                data: envelope.data,
                mailParameters: resolvedMailParameters,
                rcptParameters: rcptParameters
            )
        }
        notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
        return response
    }

    /// Sends a message using pipelined commands if supported.
    ///
    /// Pipelining allows sending multiple commands without waiting for responses,
    /// reducing round-trip latency. Falls back to standard command-response
    /// mode if the server does not support PIPELINING.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - options: Formatting options for the message.
    ///   - progress: Optional progress callback for tracking transfer.
    ///   - mailParameters: Additional MAIL FROM parameters.
    ///   - rcptParameters: Additional RCPT TO parameters.
    /// - Returns: The server response.
    /// - Throws: An error if sending fails.
    public func sendPipelined(
        _ message: MimeMessage,
        options: FormatOptions = MailTransportFormatOptions.default,
        progress: TransferProgress? = nil,
        mailParameters: SmtpMailFromParameters? = nil,
        rcptParameters: SmtpRcptToParameters? = nil
    ) throws -> SmtpResponse {
        try ensureConnected()
        try ensureInternationalSupport(options)
        let envelope = try MailTransportEnvelopeBuilder.build(for: message, options: options, progress: progress)
        let resolvedMailParameters = resolveMailParameters(mailParameters, data: envelope.data, options: options)
        let response: SmtpResponse
        if supportsCapability("PIPELINING") {
            response = try session.sendMailPipelined(
                from: envelope.sender.address,
                to: envelope.recipients.map { $0.address },
                data: envelope.data,
                mailParameters: resolvedMailParameters,
                rcptParameters: rcptParameters
            )
        } else {
            response = try session.sendMail(
                from: envelope.sender.address,
                to: envelope.recipients.map { $0.address },
                data: envelope.data,
                mailParameters: resolvedMailParameters,
                rcptParameters: rcptParameters
            )
        }
        notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
        return response
    }

    /// Sends raw message data with explicit sender and recipients.
    ///
    /// Use this method when you have pre-encoded message data.
    ///
    /// - Parameters:
    ///   - from: The envelope sender address.
    ///   - recipients: The envelope recipient addresses.
    ///   - data: The raw message data.
    /// - Throws: An error if sending fails.
    public func sendMessage(from: String, to recipients: [String], data: [UInt8]) throws {
        try ensureConnected()
        let mailParameters = resolveMailParameters(nil, data: data, options: MailTransportFormatOptions.default)
        _ = try session.sendMail(
            from: from,
            to: recipients,
            data: data,
            mailParameters: mailParameters,
            rcptParameters: nil
        )
    }

    /// Sends a message without returning the response.
    ///
    /// Convenience method that wraps ``send(_:options:progress:)-4dscz``.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - options: Formatting options for the message.
    ///   - progress: Optional progress callback for tracking transfer.
    /// - Throws: An error if sending fails.
    public func sendMessage(
        _ message: MimeMessage,
        options: FormatOptions = MailTransportFormatOptions.default,
        progress: TransferProgress? = nil
    ) throws {
        _ = try send(message, options: options, progress: progress)
    }

    /// Sends a message with explicit sender and recipients without returning the response.
    ///
    /// Convenience method that wraps ``send(_:sender:recipients:options:progress:)-9ffda``.
    ///
    /// - Parameters:
    ///   - message: The message to send.
    ///   - sender: The envelope sender address.
    ///   - recipients: The envelope recipient addresses.
    ///   - options: Formatting options for the message.
    ///   - progress: Optional progress callback for tracking transfer.
    /// - Throws: An error if sending fails.
    public func sendMessage(
        _ message: MimeMessage,
        sender: MailboxAddress,
        recipients: [MailboxAddress],
        options: FormatOptions = MailTransportFormatOptions.default,
        progress: TransferProgress? = nil
    ) throws {
        _ = try send(message, sender: sender, recipients: recipients, options: options, progress: progress)
    }

    private func updateAuthenticationMechanisms(from capabilities: SmtpCapabilities) {
        var mechanisms: [String] = []

        if let authValue = capabilities.value(for: "AUTH") {
            mechanisms.append(contentsOf: authValue.split(whereSeparator: { $0 == " " }).map(String.init))
        }

        for flag in capabilities.flags where flag.hasPrefix("AUTH=") {
            let value = String(flag.dropFirst("AUTH=".count))
            if !value.isEmpty {
                mechanisms.append(contentsOf: value.split(whereSeparator: { $0 == " " }).map(String.init))
            }
        }

        if mechanisms.isEmpty {
            updateAuthenticationMechanisms([])
        } else {
            updateAuthenticationMechanisms(mechanisms)
        }
    }

    private func supportsCapability(_ name: String) -> Bool {
        storedCapabilities?.supports(name) ?? false
    }

    private func resolveMailParameters(
        _ base: SmtpMailFromParameters?,
        data: [UInt8],
        options: FormatOptions
    ) -> SmtpMailFromParameters? {
        var parameters = base ?? SmtpMailFromParameters()
        var hasParameters = base != nil

        if options.international {
            parameters.smtpUtf8 = true
            hasParameters = true
        }

        if supportsCapability("SIZE"), parameters.size == nil {
            parameters.size = data.count
            hasParameters = true
        }

        if supportsCapability("8BITMIME"), parameters.body == nil, dataContainsNonAscii(data) {
            parameters.body = .eightBitMime
            hasParameters = true
        }

        return hasParameters ? parameters : nil
    }

    private func dataContainsNonAscii(_ data: [UInt8]) -> Bool {
        data.contains { $0 > 0x7f }
    }

    private func ensureConnected() throws {
        guard isConnected else {
            throw MailTransportError.notConnected
        }
    }

    private func ensureInternationalSupport(_ options: FormatOptions) throws {
        if options.international, !supportsCapability("SMTPUTF8") {
            throw MailTransportError.internationalNotSupported
        }
    }
}
