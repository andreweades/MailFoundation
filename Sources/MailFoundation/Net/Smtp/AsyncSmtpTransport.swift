//
// AsyncSmtpTransport.swift
//
// Async SMTP transport wrapper.
//

import MimeFoundation

/// An asynchronous SMTP transport for sending email messages using Swift concurrency.
///
/// `AsyncSmtpTransport` provides a high-level API for connecting to an SMTP server,
/// authenticating, and sending messages. It is implemented as an actor to ensure
/// thread-safe access to the connection state.
///
/// ## Connecting and Authenticating
///
/// ```swift
/// // Create and connect
/// let transport = try AsyncSmtpTransport.make(
///     host: "smtp.example.com",
///     port: 587
/// )
/// try await transport.connect()
///
/// // Get capabilities with EHLO
/// let capabilities = try await transport.ehlo(domain: "client.example.com")
///
/// // Upgrade to TLS if available
/// if capabilities?.supports("STARTTLS") == true {
///     try await transport.startTls()
///     // Re-issue EHLO after TLS
///     _ = try await transport.ehlo(domain: "client.example.com")
/// }
///
/// // Authenticate
/// try await transport.authenticate(SmtpPlainAuthentication(
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
/// try await transport.send(message)
///
/// // Disconnect when done
/// await transport.disconnect()
/// ```
///
/// ## Message Sent Notifications
///
/// Register handlers to be notified when messages are sent:
///
/// ```swift
/// await transport.addMessageSentHandler { event in
///     print("Sent message: \(event.message.subject ?? "")")
/// }
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
/// let transport = try await AsyncSmtpTransport.make(
///     host: "smtp.example.com",
///     port: 587,
///     proxy: proxy
/// )
/// ```
///
/// ## Timeouts
///
/// Configure the network operation timeout:
///
/// ```swift
/// let transport = try AsyncSmtpTransport.make(
///     host: "smtp.example.com",
///     port: 587,
///     timeoutMilliseconds: 30000  // 30 seconds
/// )
/// ```
///
/// ## See Also
/// - ``SmtpTransport``
/// - ``SmtpCapabilities``
/// - ``SmtpResponse``
@available(macOS 10.15, iOS 13.0, *)
public actor AsyncSmtpTransport: AsyncMailTransport {
    /// The type of response returned by the connect operation.
    public typealias ConnectResponse = SmtpResponse?

    /// The underlying async SMTP session that manages protocol details.
    private let session: AsyncSmtpSession

    /// Cached server capabilities from the last EHLO response.
    private var storedCapabilities: SmtpCapabilities?

    /// The set of authentication mechanisms supported by the server.
    private var authenticationMechanisms: Set<String> = []

    /// The type of handler called when a message is sent.
    public typealias MessageSentHandler = @Sendable (MessageSentEvent) async -> Void

    /// Registered handlers to notify when messages are sent.
    private var messageSentHandlers: [MessageSentHandler] = []

    /// The timeout for network operations in milliseconds.
    ///
    /// Default is 120000 (2 minutes), matching MailKit's default.
    /// Set to `Int.max` for no timeout.
    public var timeoutMilliseconds: Int {
        get async { await session.timeoutMilliseconds }
    }

    /// Sets the timeout for network operations.
    ///
    /// - Parameter milliseconds: The timeout in milliseconds.
    public func setTimeout(milliseconds: Int) async {
        await session.setTimeoutMilliseconds(milliseconds)
    }

    /// Creates a new async SMTP transport connected to the specified server.
    ///
    /// This factory method creates the underlying network transport and wraps it
    /// in an `AsyncSmtpTransport`. Use this for most common connection scenarios.
    ///
    /// - Parameters:
    ///   - host: The SMTP server hostname or IP address.
    ///   - port: The port number (typically 25, 465, or 587).
    ///   - backend: The async transport backend to use. Defaults to `.network`.
    ///   - timeoutMilliseconds: The timeout for network operations in milliseconds.
    /// - Returns: A configured `AsyncSmtpTransport` ready to connect.
    /// - Throws: An error if the transport cannot be created.
    public static func make(
        host: String,
        port: UInt16,
        backend: AsyncTransportBackend = .network,
        timeoutMilliseconds: Int = defaultSmtpTimeoutMs
    ) throws -> AsyncSmtpTransport {
        let transport = try AsyncTransportFactory.make(host: host, port: port, backend: backend)
        return AsyncSmtpTransport(transport: transport, timeoutMilliseconds: timeoutMilliseconds)
    }

    /// Creates a new async SMTP transport connected through a proxy server.
    ///
    /// - Parameters:
    ///   - host: The SMTP server hostname or IP address.
    ///   - port: The port number (typically 25, 465, or 587).
    ///   - backend: The async transport backend to use. Defaults to `.network`.
    ///   - proxy: The proxy settings for connecting through a proxy server.
    ///   - timeoutMilliseconds: The timeout for network operations in milliseconds.
    /// - Returns: A configured `AsyncSmtpTransport` ready to connect.
    /// - Throws: An error if the transport cannot be created.
    public static func make(
        host: String,
        port: UInt16,
        backend: AsyncTransportBackend = .network,
        proxy: ProxySettings,
        timeoutMilliseconds: Int = defaultSmtpTimeoutMs
    ) async throws -> AsyncSmtpTransport {
        let transport = try await AsyncTransportFactory.make(host: host, port: port, backend: backend, proxy: proxy)
        return AsyncSmtpTransport(transport: transport, timeoutMilliseconds: timeoutMilliseconds)
    }

    /// Creates a new async SMTP transport with an existing network transport.
    ///
    /// Use this initializer when you have a pre-configured transport or need
    /// custom transport configuration.
    ///
    /// - Parameters:
    ///   - transport: The underlying async network transport.
    ///   - timeoutMilliseconds: The timeout for network operations in milliseconds.
    public init(transport: AsyncTransport, timeoutMilliseconds: Int = defaultSmtpTimeoutMs) {
        self.session = AsyncSmtpSession(transport: transport, timeoutMilliseconds: timeoutMilliseconds)
    }

    /// The server capabilities discovered during the last EHLO command.
    ///
    /// This is `nil` until ``ehlo(domain:)`` is called successfully.
    /// Capabilities may change after TLS upgrade or authentication.
    public var capabilities: SmtpCapabilities? { storedCapabilities }

    /// The authentication mechanisms supported by the server.
    ///
    /// This is populated from the AUTH capability after calling ``ehlo(domain:)``.
    public var authMechanisms: Set<String> { authenticationMechanisms }

    /// The current connection and authentication state.
    public var state: MailServiceState {
        get async { await session.state }
    }

    /// Whether the transport is currently connected to the server.
    public var isConnected: Bool {
        get async { await session.isConnected }
    }

    /// Whether the transport has successfully authenticated.
    public var isAuthenticated: Bool {
        get async { await session.isAuthenticated }
    }

    /// Connects to the SMTP server.
    ///
    /// This opens the network connection and waits for the server greeting.
    /// After connecting, you should call ``ehlo(domain:)`` to negotiate capabilities.
    ///
    /// - Returns: The server greeting response, or `nil` if no response was received.
    /// - Throws: An error if the connection fails.
    @discardableResult
    public func connect() async throws -> SmtpResponse? {
        try await session.connect()
    }

    /// Disconnects from the SMTP server.
    ///
    /// This closes the network connection. For a graceful disconnection,
    /// the session sends a QUIT command internally before closing.
    public func disconnect() async {
        await session.disconnect()
    }

    /// Registers a handler to be notified when messages are sent.
    ///
    /// The handler is called after each successful message send with details
    /// about the message and the server response.
    ///
    /// - Parameter handler: The handler to call when a message is sent.
    public func addMessageSentHandler(_ handler: @escaping MessageSentHandler) async {
        messageSentHandlers.append(handler)
    }

    /// Removes all registered message sent handlers.
    public func removeAllMessageSentHandlers() async {
        messageSentHandlers.removeAll()
    }

    /// Sends an EHLO command and retrieves server capabilities.
    ///
    /// The EHLO command identifies the client to the server and retrieves the list
    /// of supported extensions. This should be called after connecting and again
    /// after upgrading to TLS.
    ///
    /// - Parameter domain: The client's domain name or IP address.
    /// - Returns: The server's advertised capabilities, or `nil` if the command failed.
    /// - Throws: An error if the command fails.
    public func ehlo(domain: String) async throws -> SmtpCapabilities? {
        let capabilities = try await session.ehlo(domain: domain)
        if let capabilities {
            storedCapabilities = capabilities
            updateAuthenticationMechanisms(from: capabilities)
        }
        return capabilities
    }

    /// Sends a HELO command for basic SMTP greeting.
    ///
    /// HELO is the original SMTP greeting command. Use ``ehlo(domain:)`` instead
    /// for servers that support ESMTP extensions.
    ///
    /// - Parameter domain: The client's domain name or IP address.
    /// - Returns: The server response, or `nil` if no response was received.
    /// - Throws: An error if the command fails.
    public func helo(domain: String) async throws -> SmtpResponse? {
        try await session.helo(domain: domain)
    }

    /// Sends a NOOP command to keep the connection alive.
    ///
    /// The NOOP command does nothing but can be used to prevent connection
    /// timeouts or to verify the connection is still active.
    ///
    /// - Returns: The server response, or `nil` if no response was received.
    /// - Throws: An error if the command fails.
    public func noop() async throws -> SmtpResponse? {
        try await session.noop()
    }

    /// Sends an RSET command to reset the mail transaction.
    ///
    /// This aborts any mail transaction in progress and clears all buffers
    /// and state tables. The connection remains open.
    ///
    /// - Returns: The server response, or `nil` if no response was received.
    /// - Throws: An error if the command fails.
    public func rset() async throws -> SmtpResponse? {
        try await session.rset()
    }

    /// Sends a VRFY command to verify a mailbox exists.
    ///
    /// Note: Many servers disable this command for security reasons.
    ///
    /// - Parameter argument: The mailbox or username to verify.
    /// - Returns: The raw server response, or `nil` if no response was received.
    /// - Throws: An error if the command fails.
    public func vrfy(_ argument: String) async throws -> SmtpResponse? {
        try await session.vrfy(argument)
    }

    /// Sends a VRFY command and returns a structured result.
    ///
    /// - Parameter argument: The mailbox or username to verify.
    /// - Returns: A structured result containing verification information.
    /// - Throws: An error if the command fails.
    public func vrfyResult(_ argument: String) async throws -> SmtpVrfyResult {
        try await session.vrfyResult(argument)
    }

    /// Sends an EXPN command to expand a mailing list.
    ///
    /// Note: Many servers disable this command for security reasons.
    ///
    /// - Parameter argument: The mailing list to expand.
    /// - Returns: The raw server response, or `nil` if no response was received.
    /// - Throws: An error if the command fails.
    public func expn(_ argument: String) async throws -> SmtpResponse? {
        try await session.expn(argument)
    }

    /// Sends an EXPN command and returns a structured result.
    ///
    /// - Parameter argument: The mailing list to expand.
    /// - Returns: A structured result containing the expanded addresses.
    /// - Throws: An error if the command fails.
    public func expnResult(_ argument: String) async throws -> SmtpExpnResult {
        try await session.expnResult(argument)
    }

    /// Sends a HELP command to request server help.
    ///
    /// - Parameter argument: Optional command name to get help for.
    /// - Returns: The raw server response, or `nil` if no response was received.
    /// - Throws: An error if the command fails.
    public func help(_ argument: String? = nil) async throws -> SmtpResponse? {
        try await session.help(argument)
    }

    /// Sends a HELP command and returns a structured result.
    ///
    /// - Parameter argument: Optional command name to get help for.
    /// - Returns: A structured result containing help information.
    /// - Throws: An error if the command fails.
    public func helpResult(_ argument: String? = nil) async throws -> SmtpHelpResult {
        try await session.helpResult(argument)
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
    public func startTls(validateCertificate: Bool = true) async throws -> SmtpResponse {
        let response = try await session.startTls(validateCertificate: validateCertificate)
        storedCapabilities = nil
        authenticationMechanisms.removeAll()
        return response
    }

    /// Authenticates with the server using a SASL mechanism.
    ///
    /// - Parameters:
    ///   - mechanism: The SASL mechanism name (e.g., "PLAIN", "LOGIN").
    ///   - initialResponse: Optional initial response data (base64-encoded).
    /// - Returns: The server response, or `nil` if no response was received.
    /// - Throws: An error if authentication fails.
    public func authenticate(mechanism: String, initialResponse: String? = nil) async throws -> SmtpResponse? {
        try await session.authenticate(mechanism: mechanism, initialResponse: initialResponse)
    }

    /// Authenticates with the server using an authentication provider.
    ///
    /// This method handles the complete SASL authentication exchange,
    /// including any challenge-response rounds.
    ///
    /// - Parameter authentication: The authentication provider.
    /// - Returns: The final server response, or `nil` if no response was received.
    /// - Throws: An error if authentication fails.
    public func authenticate(_ authentication: SmtpAuthentication) async throws -> SmtpResponse? {
        try await session.authenticate(authentication)
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
    ) async throws -> SmtpResponse {
        try await ensureConnected()
        try await ensureInternationalSupport(options)
        let envelope = try MailTransportEnvelopeBuilder.build(for: message, options: options, progress: progress)
        let mailParameters = resolveMailParameters(nil, data: envelope.data, options: options)
        let response = try await session.sendMail(
            from: envelope.sender.address,
            to: envelope.recipients.map { $0.address },
            data: envelope.data,
            mailParameters: mailParameters,
            rcptParameters: nil
        )
        await notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
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
    ) async throws -> SmtpResponse {
        try await ensureConnected()
        try await ensureInternationalSupport(options)
        let data = try MailTransportEnvelopeBuilder.encodeMessage(message, options: options, progress: progress)
        let mailParameters = resolveMailParameters(nil, data: data, options: options)
        let response = try await session.sendMail(
            from: sender.address,
            to: recipients.map { $0.address },
            data: data,
            mailParameters: mailParameters,
            rcptParameters: nil
        )
        await notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
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
    ) async throws -> SmtpResponse {
        try await ensureConnected()
        try await ensureInternationalSupport(options)
        let envelope = try MailTransportEnvelopeBuilder.build(for: message, options: options, progress: progress)
        let resolvedMailParameters = resolveMailParameters(mailParameters, data: envelope.data, options: options)
        if supportsCapability("CHUNKING") {
            let response = try await session.sendMailChunked(
                from: envelope.sender.address,
                to: envelope.recipients.map { $0.address },
                data: envelope.data,
                chunkSize: chunkSize,
                mailParameters: resolvedMailParameters,
                rcptParameters: rcptParameters
            )
            await notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
            return response
        }
        let response = try await session.sendMail(
            from: envelope.sender.address,
            to: envelope.recipients.map { $0.address },
            data: envelope.data,
            mailParameters: resolvedMailParameters,
            rcptParameters: rcptParameters
        )
        await notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
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
    ) async throws -> SmtpResponse {
        try await ensureConnected()
        try await ensureInternationalSupport(options)
        let envelope = try MailTransportEnvelopeBuilder.build(for: message, options: options, progress: progress)
        let resolvedMailParameters = resolveMailParameters(mailParameters, data: envelope.data, options: options)
        if supportsCapability("PIPELINING") {
            let response = try await session.sendMailPipelined(
                from: envelope.sender.address,
                to: envelope.recipients.map { $0.address },
                data: envelope.data,
                mailParameters: resolvedMailParameters,
                rcptParameters: rcptParameters
            )
            await notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
            return response
        }
        let response = try await session.sendMail(
            from: envelope.sender.address,
            to: envelope.recipients.map { $0.address },
            data: envelope.data,
            mailParameters: resolvedMailParameters,
            rcptParameters: rcptParameters
        )
        await notifyMessageSent(message: message, response: response.lines.joined(separator: " "))
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
    public func sendMessage(from: String, to recipients: [String], data: [UInt8]) async throws {
        try await ensureConnected()
        let mailParameters = resolveMailParameters(nil, data: data, options: MailTransportFormatOptions.default)
        _ = try await session.sendMail(
            from: from,
            to: recipients,
            data: data,
            mailParameters: mailParameters,
            rcptParameters: nil
        )
    }

    /// Sends a message without returning the response.
    ///
    /// Convenience method that wraps ``send(_:options:progress:)-3gg05``.
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
    ) async throws {
        _ = try await send(message, options: options, progress: progress)
    }

    /// Sends a message with explicit sender and recipients without returning the response.
    ///
    /// Convenience method that wraps ``send(_:sender:recipients:options:progress:)-74s48``.
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
    ) async throws {
        _ = try await send(message, sender: sender, recipients: recipients, options: options, progress: progress)
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

        authenticationMechanisms = Set(mechanisms.map { $0.uppercased() })
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

    private func ensureConnected() async throws {
        guard await session.isConnected else {
            throw MailTransportError.notConnected
        }
    }

    private func ensureInternationalSupport(_ options: FormatOptions) async throws {
        if options.international, !supportsCapability("SMTPUTF8") {
            throw MailTransportError.internationalNotSupported
        }
    }

    private func notifyMessageSent(message: MimeMessage, response: String) async {
        guard !messageSentHandlers.isEmpty else { return }
        let event = MessageSentEvent(message: message, response: response)
        for handler in messageSentHandlers {
            await handler(event)
        }
    }
}
