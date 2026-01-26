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
// MailServiceBase.swift
//
// Base mail service abstractions and configuration (ported from MailKit).
//

import Foundation
import MimeFoundation
#if canImport(Security)
@preconcurrency import Security
#endif

// MARK: - TLS Protocol Version

/// Represents supported TLS protocol versions for secure mail connections.
///
/// When configuring TLS for mail services, you can specify which protocol
/// versions are acceptable. Modern deployments should prefer TLS 1.2 or
/// TLS 1.3 for security.
///
/// ## Security Recommendations
///
/// - TLS 1.3 is the most secure and should be preferred when available
/// - TLS 1.2 is widely supported and considered secure
/// - TLS 1.0 and 1.1 are deprecated and should be avoided if possible
///
/// - Note: Ported from MailKit's `SslProtocols` configuration.
public enum TlsProtocolVersion: String, Sendable, CaseIterable {
    /// TLS 1.0 (deprecated, avoid if possible)
    case tls10 = "TLS1.0"

    /// TLS 1.1 (deprecated, avoid if possible)
    case tls11 = "TLS1.1"

    /// TLS 1.2 (recommended minimum)
    case tls12 = "TLS1.2"

    /// TLS 1.3 (most secure, preferred when available)
    case tls13 = "TLS1.3"
}

// MARK: - TLS Configuration

/// Configuration options for TLS/SSL connections to mail servers.
///
/// `TlsConfiguration` controls how secure connections are established,
/// including which protocol versions are allowed, certificate validation
/// behavior, and client certificate authentication.
///
/// ## Default Configuration
///
/// The default configuration uses secure defaults:
/// - Allows the operating system to choose the best protocol
/// - Validates server certificates
/// - Checks certificate revocation
///
/// ## Custom Configuration Example
///
/// ```swift
/// var config = TlsConfiguration()
/// config.allowedProtocols = [.tls12, .tls13]
/// config.validateServerCertificate = true
/// config.checkCertificateRevocation = true
///
/// let transport = SmtpTransport(
///     host: "smtp.example.com",
///     port: 465,
///     tlsConfiguration: config
/// )
/// ```
///
/// - Note: Ported from MailKit's SSL/TLS configuration properties.
public struct TlsConfiguration: Sendable, Equatable {
    /// The default TLS configuration with secure settings.
    public static let `default` = TlsConfiguration()

    /// The set of allowed TLS protocol versions.
    ///
    /// When empty, the operating system chooses the best available protocol.
    /// Specify versions explicitly to restrict which protocols can be negotiated.
    ///
    /// - Note: For maximum security, prefer TLS 1.2 and TLS 1.3.
    public var allowedProtocols: Set<TlsProtocolVersion>

    /// Specific cipher suites to allow for the TLS connection.
    ///
    /// When `nil`, the operating system default cipher suites are used.
    /// Use extreme caution when setting this value explicitly.
    public var cipherSuites: [String]?

    /// Client certificates for mutual TLS authentication.
    ///
    /// Some mail servers require client certificate authentication.
    /// Provide the certificate data in DER format.
    public var clientCertificates: [Data]

    /// Whether to validate the server's SSL/TLS certificate.
    ///
    /// Setting this to `false` disables certificate validation, which
    /// is insecure and should only be used for testing or when connecting
    /// to servers with self-signed certificates.
    ///
    /// - Warning: Disabling certificate validation exposes the connection
    ///   to man-in-the-middle attacks.
    public var validateServerCertificate: Bool

    /// Whether to check certificate revocation status.
    ///
    /// When `true`, the system checks if the server's certificate has been
    /// revoked using CRL or OCSP. This adds security but may fail if the
    /// Certificate Authority's servers are unreachable.
    ///
    /// - Note: Ported from MailKit's `CheckCertificateRevocation` property.
    public var checkCertificateRevocation: Bool

    /// Creates a new TLS configuration with the specified options.
    ///
    /// - Parameters:
    ///   - allowedProtocols: The allowed TLS versions (empty = system default).
    ///   - cipherSuites: Specific cipher suites to allow (`nil` = system default).
    ///   - clientCertificates: Client certificates for mutual TLS.
    ///   - validateServerCertificate: Whether to validate server certificates.
    ///   - checkCertificateRevocation: Whether to check revocation status.
    public init(
        allowedProtocols: Set<TlsProtocolVersion> = [],
        cipherSuites: [String]? = nil,
        clientCertificates: [Data] = [],
        validateServerCertificate: Bool = true,
        checkCertificateRevocation: Bool = true
    ) {
        self.allowedProtocols = allowedProtocols
        self.cipherSuites = cipherSuites
        self.clientCertificates = clientCertificates
        self.validateServerCertificate = validateServerCertificate
        self.checkCertificateRevocation = checkCertificateRevocation
    }
}

// MARK: - Certificate Validation

/// Context information provided to custom certificate validation handlers.
///
/// When a custom ``CertificateValidationHandler`` is registered, it receives
/// this context containing details about the connection and the server's
/// certificate trust chain.
///
/// ## Example Usage
///
/// ```swift
/// transport.serverCertificateValidation = { context in
///     print("Validating certificate for \(context.host):\(context.port)")
///     // Perform custom validation...
///     return true // Accept the certificate
/// }
/// ```
///
/// - Note: Ported from MailKit's `ServerCertificateValidationCallback`.
public struct CertificateValidationContext: @unchecked Sendable {
    /// The hostname of the server being connected to.
    public let host: String

    /// The port number of the connection.
    public let port: Int

#if canImport(Security)
    /// The certificate trust object for validation.
    ///
    /// Use Security framework functions to evaluate this trust object
    /// and make validation decisions.
    public let trust: SecTrust?
#else
    /// The certificate trust object for validation (platform-specific).
    public let trust: Any?
#endif

#if canImport(Security)
    /// Creates a certificate validation context.
    ///
    /// - Parameters:
    ///   - host: The server hostname.
    ///   - port: The connection port.
    ///   - trust: The certificate trust chain to validate.
    public init(host: String, port: Int, trust: SecTrust?) {
        self.host = host
        self.port = port
        self.trust = trust
    }
#else
    /// Creates a certificate validation context.
    ///
    /// - Parameters:
    ///   - host: The server hostname.
    ///   - port: The connection port.
    ///   - trust: The certificate trust chain to validate.
    public init(host: String, port: Int, trust: Any?) {
        self.host = host
        self.port = port
        self.trust = trust
    }
#endif
}

/// A callback function for custom server certificate validation.
///
/// Return `true` to accept the certificate, or `false` to reject it
/// and terminate the connection.
///
/// - Parameter context: Information about the connection and certificate.
/// - Returns: `true` if the certificate should be accepted.
///
/// - Note: Ported from MailKit's `RemoteCertificateValidationCallback`.
public typealias CertificateValidationHandler = @Sendable (CertificateValidationContext) -> Bool

// MARK: - Socket Endpoint

/// Represents a network endpoint with host and port.
///
/// `SocketEndpoint` is used to specify local binding addresses or
/// to represent connection targets throughout the mail service APIs.
public struct SocketEndpoint: Sendable, Equatable {
    /// The hostname or IP address.
    public let host: String

    /// The port number.
    public let port: Int

    /// Creates a socket endpoint.
    ///
    /// - Parameters:
    ///   - host: The hostname or IP address.
    ///   - port: The port number.
    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}

// MARK: - Proxy Client Protocol

/// A protocol for proxy clients that establish tunneled connections.
///
/// Proxy clients handle the protocol-specific handshake to establish
/// a connection through a proxy server to the target mail server.
///
/// - Note: See ``ProxySettings`` for configuring proxy connections.
public protocol ProxyClient: AnyObject {
    /// Establishes a connection to the target host through the proxy.
    ///
    /// - Parameters:
    ///   - host: The target hostname to connect to.
    ///   - port: The target port to connect to.
    /// - Throws: ``ProxyError`` if the proxy connection fails.
    func connect(to host: String, port: Int) throws
}

// MARK: - Message Sent Event

/// Event data provided when a message has been successfully sent.
///
/// This event is passed to ``MessageSentHandler`` callbacks after
/// a message has been accepted by the SMTP server.
///
/// ## Example Usage
///
/// ```swift
/// transport.addMessageSentHandler { event in
///     print("Sent message: \(event.message.subject ?? "No subject")")
///     print("Server response: \(event.response)")
/// }
/// ```
public struct MessageSentEvent: Sendable {
    /// The message that was sent.
    public let message: MimeMessage

    /// The server's response confirming message acceptance.
    ///
    /// For SMTP, this is typically the response to the DATA command,
    /// containing a queue ID or confirmation message.
    public let response: String

    /// Creates a message sent event.
    ///
    /// - Parameters:
    ///   - message: The message that was sent.
    ///   - response: The server's response string.
    public init(message: MimeMessage, response: String) {
        self.message = message
        self.response = response
    }
}

// MARK: - Mail Service Base Class

/// An abstract base class for mail service implementations.
///
/// `MailServiceBase` provides common functionality for all mail services,
/// including connection state management, TLS configuration, protocol logging,
/// and authentication mechanism tracking.
///
/// ## Subclassing
///
/// Concrete mail service implementations (SMTP, POP3, IMAP) should inherit
/// from this class and override:
/// - ``protocolName`` to return the protocol identifier
/// - ``connect()`` to implement connection logic
/// - ``disconnect()`` to implement disconnection logic (call `super`)
///
/// ## Thread Safety
///
/// The ``syncRoot`` property can be used to synchronize access to the
/// service when accessed from multiple threads.
///
/// - Note: Ported from MailKit's `MailService` abstract class.
open class MailServiceBase<Response>: MailService {
    /// The response type returned by ``connect()``.
    public typealias ConnectResponse = Response

    /// An object that can be used to synchronize access to the service.
    ///
    /// Use this property when accessing the service from multiple threads
    /// to ensure thread-safe operations.
    ///
    /// - Note: Ported from MailKit's `SyncRoot` property.
    public let syncRoot = NSObject()

    /// The protocol logger for recording client-server communication.
    ///
    /// Set this property to log all protocol-level communication for
    /// debugging purposes. The default is ``NullProtocolLogger`` which
    /// discards all log messages.
    ///
    /// - Note: Ported from MailKit's `ProtocolLogger` property.
    open var protocolLogger: ProtocolLoggerType

    /// The TLS configuration for secure connections.
    ///
    /// Configure this property before calling ``connect()`` to control
    /// TLS behavior including allowed protocol versions and certificate
    /// validation.
    open var tlsConfiguration: TlsConfiguration

    /// A custom callback for server certificate validation.
    ///
    /// Set this property to implement custom certificate validation logic.
    /// When `nil`, the default system validation is used.
    ///
    /// - Note: Ported from MailKit's `ServerCertificateValidationCallback`.
    open var serverCertificateValidation: CertificateValidationHandler?

    /// The local endpoint to bind to when connecting.
    ///
    /// Set this property to specify a local IP address and port for
    /// outgoing connections. When `nil`, the system chooses automatically.
    ///
    /// - Note: Ported from MailKit's `LocalEndPoint` property.
    open var localEndpoint: SocketEndpoint?

    /// A proxy client for connecting through a proxy server.
    ///
    /// Set this property to route connections through an HTTP CONNECT,
    /// SOCKS4, or SOCKS5 proxy. The proxy client is held weakly.
    ///
    /// - Note: Ported from MailKit's `ProxyClient` property.
    open weak var proxyClient: (any ProxyClient)?

    /// The set of authentication mechanisms supported by the server.
    ///
    /// This property is populated after a successful connection when
    /// the server advertises its capabilities. Use this to determine
    /// which authentication methods are available.
    ///
    /// - Note: Mechanism names are stored in uppercase.
    public private(set) var authenticationMechanisms: Set<String> = []

    /// The current connection and authentication state.
    public private(set) var state: MailServiceState = .disconnected

    /// Indicates whether the service is currently connected.
    public var isConnected: Bool { state != .disconnected }

    /// Indicates whether the service is authenticated.
    public var isAuthenticated: Bool { state == .authenticated }

    /// Creates a new mail service base instance.
    ///
    /// - Parameters:
    ///   - protocolLogger: The logger for protocol traffic (default: null logger).
    ///   - tlsConfiguration: The TLS configuration (default: secure defaults).
    public init(
        protocolLogger: ProtocolLoggerType = NullProtocolLogger(),
        tlsConfiguration: TlsConfiguration = .default
    ) {
        self.protocolLogger = protocolLogger
        self.tlsConfiguration = tlsConfiguration
    }

    /// The name of the protocol implemented by this service.
    ///
    /// Subclasses must override this property to return the protocol
    /// name (e.g., "SMTP", "POP3", "IMAP").
    open var protocolName: String {
        fatalError("Subclasses must override protocolName.")
    }

    /// Establishes a connection to the mail server.
    ///
    /// Subclasses must override this method to implement protocol-specific
    /// connection logic.
    ///
    /// - Returns: Protocol-specific connection response.
    /// - Throws: Connection errors if the server is unreachable.
    @discardableResult
    open func connect() throws -> Response {
        fatalError("Subclasses must override connect().")
    }

    /// Disconnects from the mail server.
    ///
    /// The default implementation resets the state to disconnected.
    /// Subclasses should call `super.disconnect()` after closing
    /// the connection.
    open func disconnect() {
        updateState(.disconnected)
    }

    /// Updates the set of supported authentication mechanisms.
    ///
    /// Call this method after receiving server capabilities to update
    /// the list of available authentication mechanisms.
    ///
    /// - Parameter mechanisms: The mechanism names (case-insensitive).
    public func updateAuthenticationMechanisms(_ mechanisms: [String]) {
        authenticationMechanisms = Set(mechanisms.map { $0.uppercased() })
    }

    /// Adds an authentication mechanism to the supported set.
    ///
    /// - Parameter mechanism: The mechanism name (case-insensitive).
    public func addAuthenticationMechanism(_ mechanism: String) {
        authenticationMechanisms.insert(mechanism.uppercased())
    }

    /// Removes an authentication mechanism from the supported set.
    ///
    /// Call this method to prevent the use of specific authentication
    /// mechanisms, even if the server advertises support for them.
    ///
    /// - Parameter mechanism: The mechanism name (case-insensitive).
    public func removeAuthenticationMechanism(_ mechanism: String) {
        authenticationMechanisms.remove(mechanism.uppercased())
    }

    /// Checks if a specific authentication mechanism is supported.
    ///
    /// - Parameter mechanism: The mechanism name (case-insensitive).
    /// - Returns: `true` if the mechanism is supported.
    public func supportsAuthenticationMechanism(_ mechanism: String) -> Bool {
        authenticationMechanisms.contains(mechanism.uppercased())
    }

    /// Updates the connection state.
    ///
    /// Call this method from subclasses to update the service state
    /// as the connection progresses through its lifecycle.
    ///
    /// - Parameter newState: The new state to set.
    public func updateState(_ newState: MailServiceState) {
        state = newState
    }
}

// MARK: - Mail Transport Base Class

/// An abstract base class for mail transport (sending) implementations.
///
/// `MailTransportBase` extends ``MailServiceBase`` with message sending
/// capabilities and event notification for sent messages. It is the base
/// class for SMTP transport implementations.
///
/// ## Message Sent Notifications
///
/// Register handlers to be notified when messages are successfully sent:
///
/// ```swift
/// let transport = SmtpTransport(host: "smtp.example.com", port: 587)
/// transport.addMessageSentHandler { event in
///     print("Sent: \(event.message.subject ?? "No subject")")
///     print("Response: \(event.response)")
/// }
/// ```
///
/// - Note: Ported from MailKit's `MailTransport` class.
open class MailTransportBase<Response>: MailServiceBase<Response> {
    /// The handler type for message sent events.
    public typealias MessageSentHandler = @Sendable (MessageSentEvent) -> Void

    /// The registered message sent handlers.
    private var messageSentHandlers: [MessageSentHandler] = []

    /// Registers a handler to be called when a message is sent.
    ///
    /// Multiple handlers can be registered and will all be called
    /// in the order they were added.
    ///
    /// - Parameter handler: The handler to call when a message is sent.
    public func addMessageSentHandler(_ handler: @escaping MessageSentHandler) {
        messageSentHandlers.append(handler)
    }

    /// Removes all registered message sent handlers.
    public func removeAllMessageSentHandlers() {
        messageSentHandlers.removeAll()
    }

    /// Notifies all registered handlers that a message was sent.
    ///
    /// Call this method from subclasses after a message has been
    /// successfully accepted by the server.
    ///
    /// - Parameters:
    ///   - message: The message that was sent.
    ///   - response: The server's response string.
    public func notifyMessageSent(message: MimeMessage, response: String) {
        let event = MessageSentEvent(message: message, response: response)
        for handler in messageSentHandlers {
            handler(event)
        }
    }
}
