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
// ConnectionPool.swift
//
// Connection pooling for mail services (ported from MailKit patterns).
//

import Foundation

// MARK: - Mail Server Configuration

/// Configuration for connecting to a mail server.
///
/// `MailServerConfiguration` encapsulates the connection parameters needed
/// to establish a connection to an IMAP, POP3, or SMTP server.
///
/// ## Example Usage
///
/// ```swift
/// // IMAP with implicit TLS (port 993)
/// let imapConfig = MailServerConfiguration(
///     host: "imap.example.com",
///     port: 993,
///     useTls: true
/// )
///
/// // SMTP with STARTTLS (port 587)
/// let smtpConfig = MailServerConfiguration(
///     host: "smtp.example.com",
///     port: 587,
///     useTls: false  // Will upgrade via STARTTLS
/// )
/// ```
public struct MailServerConfiguration: Sendable, Equatable {
    /// The mail server hostname or IP address.
    public let host: String

    /// The port number to connect to.
    ///
    /// Common ports:
    /// - IMAP: 143 (plain), 993 (TLS)
    /// - POP3: 110 (plain), 995 (TLS)
    /// - SMTP: 25 (plain), 587 (submission), 465 (TLS)
    public let port: UInt16

    /// Whether to use implicit TLS (connect with TLS from the start).
    ///
    /// When `false`, the connection starts unencrypted and may upgrade
    /// to TLS via STARTTLS. When `true`, TLS is negotiated immediately.
    public let useTls: Bool

    /// Whether to validate the server's TLS certificate.
    ///
    /// Set to `false` only for testing with self-signed certificates.
    ///
    /// - Warning: Disabling certificate validation is insecure.
    public let validateCertificate: Bool

    /// Creates a mail server configuration.
    ///
    /// - Parameters:
    ///   - host: The server hostname or IP address.
    ///   - port: The port number.
    ///   - useTls: Use implicit TLS (default: `false`).
    ///   - validateCertificate: Validate TLS certificates (default: `true`).
    public init(host: String, port: UInt16, useTls: Bool = false, validateCertificate: Bool = true) {
        self.host = host
        self.port = port
        self.useTls = useTls
        self.validateCertificate = validateCertificate
    }
}

// MARK: - Mail Credentials

/// Authentication credentials for a mail server.
///
/// `MailCredentials` holds the username and password used to authenticate
/// with IMAP, POP3, or SMTP servers.
///
/// - Note: For OAuth2 authentication, use the appropriate SASL mechanism
///   directly rather than this credentials type.
public struct MailCredentials: Sendable {
    /// The username for authentication.
    ///
    /// This is typically the user's email address or a specific username
    /// configured by the mail provider.
    public let username: String

    /// The password for authentication.
    ///
    /// - Warning: Store passwords securely using Keychain or similar.
    public let password: String

    /// Creates mail credentials.
    ///
    /// - Parameters:
    ///   - username: The authentication username.
    ///   - password: The authentication password.
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

// MARK: - Connection Pool Error

/// Errors that can occur during connection pool operations.
///
/// These errors indicate problems with acquiring, using, or releasing
/// pooled connections.
public enum ConnectionPoolError: Error, Sendable {
    /// All connections in the pool are in use.
    ///
    /// The pool has reached its maximum capacity and no connections
    /// are available. Either wait for a connection to be released or
    /// increase the pool's ``ConnectionPool/maxConnections``.
    case poolExhausted

    /// Failed to establish a connection.
    ///
    /// - Parameter error: The underlying connection error.
    case connectionFailed(Error)

    /// Authentication failed for the connection.
    ///
    /// - Parameter error: The underlying authentication error.
    case authenticationFailed(Error)

    /// The connection is no longer valid.
    ///
    /// The connection has been disconnected or is in an invalid state.
    case invalidConnection

    /// The connection pool has been closed.
    ///
    /// The pool was closed via ``ConnectionPool/close()`` and can no
    /// longer provide connections.
    case poolClosed
}

// MARK: - Pooled Connection

/// A handle to a connection borrowed from a connection pool.
///
/// `PooledConnection` wraps an active mail service connection and ensures
/// it is returned to the pool when no longer needed. Always call ``release()``
/// when done using the connection.
///
/// ## Usage Pattern
///
/// ```swift
/// let connection = try await pool.acquire()
/// defer { Task { await connection.release() } }
///
/// // Use the connection
/// let folders = try await connection.service.getFolders(...)
/// ```
///
/// ## Important
///
/// Failing to release connections will cause pool exhaustion and prevent
/// other code from acquiring connections.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public final class PooledConnection<Service: AsyncMailService>: Sendable where Service: Sendable {
    /// The connection pool this connection belongs to.
    private let pool: ConnectionPool<Service>

    /// The mail service instance for this connection.
    ///
    /// Use this service to perform mail operations. The service is
    /// already connected and authenticated.
    public let service: Service

    /// The action to perform when releasing the connection.
    private let releaseAction: @Sendable () async -> Void

    /// Creates a pooled connection handle.
    init(pool: ConnectionPool<Service>, service: Service, releaseAction: @escaping @Sendable () async -> Void) {
        self.pool = pool
        self.service = service
        self.releaseAction = releaseAction
    }

    /// Releases the connection back to the pool.
    ///
    /// After calling this method, the ``service`` should not be used
    /// as it may be given to another caller. Always release connections
    /// when done to prevent pool exhaustion.
    public func release() async {
        await releaseAction()
    }
}

// MARK: - Connection Pool

/// A pool of reusable connections to a mail server.
///
/// `ConnectionPool` maintains a set of authenticated mail service connections,
/// allowing multiple concurrent operations without the overhead of creating
/// new connections for each request. This is especially useful for server
/// applications that handle many mail operations.
///
/// ## Features
///
/// - **Connection Reuse**: Connections are returned to the pool after use
/// - **Automatic Retry**: Failed connections are retried using the configured policy
/// - **Health Checking**: Stale connections are detected and replaced
/// - **Backpressure**: Callers wait when the pool is exhausted
///
/// ## Basic Usage
///
/// ```swift
/// // Create a pool for IMAP connections
/// let pool = ConnectionPool<AsyncImapMailStore>(
///     configuration: MailServerConfiguration(host: "imap.example.com", port: 993, useTls: true),
///     credentials: MailCredentials(username: "user", password: "pass"),
///     maxConnections: 5,
///     transportBackend: .network
/// )
///
/// // Acquire a connection
/// let connection = try await pool.acquire()
/// defer { Task { await connection.release() } }
///
/// // Use the connection
/// let folders = try await connection.service.getFolders(reference: "", pattern: "*", subscribedOnly: false)
/// ```
///
/// ## Using withConnection
///
/// For simpler usage, use ``withConnection(_:)`` which handles acquire/release:
///
/// ```swift
/// let folders = try await pool.withConnection { service in
///     try await service.getFolders(reference: "", pattern: "*", subscribedOnly: false)
/// }
/// ```
///
/// ## Custom Factory
///
/// For advanced configuration, provide custom factory and authenticator:
///
/// ```swift
/// let pool = ConnectionPool(
///     configuration: config,
///     credentials: credentials,
///     maxConnections: 10,
///     serviceFactory: {
///         let transport = try AsyncTransportFactory.make(host: config.host, port: config.port, backend: .network)
///         return AsyncImapMailStore(transport: transport)
///     },
///     authenticator: { service, creds in
///         _ = try await service.authenticate(user: creds.username, password: creds.password)
///     }
/// )
/// ```
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public actor ConnectionPool<Service: AsyncMailService> where Service: Sendable {
    /// The server configuration for this pool.
    public let configuration: MailServerConfiguration

    /// The credentials used to authenticate connections.
    public let credentials: MailCredentials

    /// The maximum number of concurrent connections.
    ///
    /// The pool will never have more than this many connections active
    /// at once. When all connections are in use, callers will wait
    /// for one to become available.
    public let maxConnections: Int

    /// The retry policy for connection attempts.
    ///
    /// This policy is used when creating new connections. If a connection
    /// attempt fails with a transient error, it will be retried according
    /// to this policy.
    public let retryPolicy: RetryPolicy

    /// Factory function for creating new service instances.
    private let serviceFactory: @Sendable () async throws -> Service

    /// Function to authenticate a newly created service.
    private let authenticator: @Sendable (Service, MailCredentials) async throws -> Void

    /// Services currently available for use.
    private var availableServices: [Service] = []

    /// Number of services currently in use.
    private var inUseCount: Int = 0

    /// Whether the pool has been closed.
    private var isClosed: Bool = false

    /// Continuations waiting for a connection to become available.
    private var waiters: [CheckedContinuation<Service, Error>] = []

    /// Creates a new connection pool with custom factory and authenticator.
    ///
    /// This initializer provides full control over how connections are
    /// created and authenticated.
    ///
    /// - Parameters:
    ///   - configuration: Server connection configuration.
    ///   - credentials: Authentication credentials.
    ///   - maxConnections: Maximum concurrent connections (default: 5).
    ///   - retryPolicy: Retry policy for connections (default: `.default`).
    ///   - serviceFactory: Factory function to create new service instances.
    ///   - authenticator: Function to authenticate a service.
    public init(
        configuration: MailServerConfiguration,
        credentials: MailCredentials,
        maxConnections: Int = 5,
        retryPolicy: RetryPolicy = .default,
        serviceFactory: @escaping @Sendable () async throws -> Service,
        authenticator: @escaping @Sendable (Service, MailCredentials) async throws -> Void
    ) {
        self.configuration = configuration
        self.credentials = credentials
        self.maxConnections = max(1, maxConnections)
        self.retryPolicy = retryPolicy
        self.serviceFactory = serviceFactory
        self.authenticator = authenticator
    }

    /// The number of connections currently available in the pool.
    public var availableCount: Int {
        availableServices.count
    }

    /// The number of connections currently in use.
    public var inUseConnectionCount: Int {
        inUseCount
    }

    /// The total number of active connections (available + in use).
    public var totalConnections: Int {
        availableServices.count + inUseCount
    }

    /// Acquires a connection from the pool.
    ///
    /// If no connections are available and the pool hasn't reached its maximum,
    /// a new connection will be created. If the pool is at capacity, this method
    /// will wait until a connection becomes available.
    ///
    /// - Returns: A pooled connection handle
    /// - Throws: ConnectionPoolError if the pool is closed or connection fails
    public func acquire() async throws -> PooledConnection<Service> {
        guard !isClosed else {
            throw ConnectionPoolError.poolClosed
        }

        let service = try await acquireService()
        return PooledConnection(pool: self, service: service) { [weak self] in
            await self?.release(service)
        }
    }

    private func acquireService() async throws -> Service {
        // Try to get an available connection
        if let service = availableServices.popLast() {
            // Check if it's still connected
            if await service.isConnected {
                inUseCount += 1
                return service
            }
            // Connection is stale, discard it and try to create a new one
        }

        // If we can create a new connection, do so
        // IMPORTANT: Increment inUseCount BEFORE creating to prevent race conditions
        // where multiple tasks pass the capacity check before any completes creation.
        if totalConnections < maxConnections {
            inUseCount += 1
            do {
                let service = try await createAndConnectService()
                return service
            } catch {
                // Creation failed, release the reserved slot
                inUseCount -= 1
                throw error
            }
        }

        // Pool is at capacity, wait for a connection to become available
        return try await withCheckedThrowingContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func createAndConnectService() async throws -> Service {
        // Capture values for use in @Sendable closure
        let factory = serviceFactory
        let auth = authenticator
        let creds = credentials
        let policy = retryPolicy

        do {
            return try await withRetry(policy: policy) {
                let service = try await factory()
                _ = try await service.connect()

                // Authenticate if not already authenticated
                if await !service.isAuthenticated {
                    try await auth(service, creds)
                }

                return service
            }
        } catch let error as RetryError {
            // Unwrap the retry error to expose the underlying cause
            switch error {
            case .exhausted(let lastError, _):
                throw ConnectionPoolError.connectionFailed(lastError)
            case .permanentFailure(let underlyingError):
                // Check if it was an auth failure
                if underlyingError is ConnectionPoolError {
                    throw underlyingError
                }
                throw ConnectionPoolError.connectionFailed(underlyingError)
            case .cancelled:
                throw ConnectionPoolError.connectionFailed(error)
            }
        } catch {
            throw ConnectionPoolError.connectionFailed(error)
        }
    }

    private func release(_ service: Service) async {
        inUseCount = max(0, inUseCount - 1)

        // If there are waiters, give them the connection directly
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()

            // Check if connection is still valid
            if await service.isConnected {
                inUseCount += 1
                waiter.resume(returning: service)
            } else {
                // Connection is dead, try to create a new one for the waiter
                do {
                    let newService = try await createAndConnectService()
                    inUseCount += 1
                    waiter.resume(returning: newService)
                } catch {
                    waiter.resume(throwing: error)
                }
            }
            return
        }

        // No waiters, return to pool if still connected
        if await service.isConnected && !isClosed {
            availableServices.append(service)
        } else {
            // Disconnect stale connections
            await service.disconnect()
        }
    }

    /// Closes all connections in the pool.
    ///
    /// After calling this method, the pool cannot be used and will throw
    /// `ConnectionPoolError.poolClosed` for any acquire attempts.
    public func close() async {
        isClosed = true

        // Reject all waiters
        for waiter in waiters {
            waiter.resume(throwing: ConnectionPoolError.poolClosed)
        }
        waiters.removeAll()

        // Disconnect all available connections
        for service in availableServices {
            await service.disconnect()
        }
        availableServices.removeAll()
    }

    /// Executes an operation using a pooled connection.
    ///
    /// This is a convenience method that automatically acquires and releases
    /// a connection around the provided operation.
    ///
    /// - Parameter operation: The operation to perform with the connection
    /// - Returns: The result of the operation
    /// - Throws: Any error from acquiring the connection or the operation itself
    public func withConnection<T: Sendable>(_ operation: @Sendable (Service) async throws -> T) async throws -> T {
        let connection = try await acquire()
        do {
            let result = try await operation(connection.service)
            await connection.release()
            return result
        } catch {
            await connection.release()
            throw error
        }
    }

    /// Executes an operation using a pooled connection with automatic retries.
    ///
    /// This method will retry the entire operation (including acquiring a new connection)
    /// on transient failures. Use this for operations that may fail due to temporary
    /// network issues or server unavailability.
    ///
    /// - Parameters:
    ///   - policy: The retry policy to use (defaults to the pool's retry policy)
    ///   - operation: The operation to perform with the connection
    /// - Returns: The result of the operation
    /// - Throws: `RetryError.exhausted` if all retries fail, or the original error if permanent
    public func withRetryingConnection<T: Sendable>(
        policy: RetryPolicy? = nil,
        _ operation: @Sendable @escaping (Service) async throws -> T
    ) async throws -> T {
        let effectivePolicy = policy ?? retryPolicy

        return try await withRetry(policy: effectivePolicy) {
            try await self.withConnection(operation)
        }
    }
}

// MARK: - Convenience Initializers for Specific Service Types

@available(macOS 10.15, iOS 13.0, *)
public extension ConnectionPool where Service == AsyncImapMailStore {
    /// Creates an IMAP connection pool with default factory.
    ///
    /// This convenience initializer creates a pool configured for IMAP
    /// connections using standard authentication.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pool = ConnectionPool<AsyncImapMailStore>(
    ///     configuration: MailServerConfiguration(
    ///         host: "imap.example.com",
    ///         port: 993,
    ///         useTls: true
    ///     ),
    ///     credentials: MailCredentials(username: "user@example.com", password: "secret"),
    ///     maxConnections: 5
    /// )
    ///
    /// let folders = try await pool.withConnection { store in
    ///     try await store.getFolders(reference: "", pattern: "*", subscribedOnly: false)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: Server connection configuration.
    ///   - credentials: Authentication credentials.
    ///   - maxConnections: Maximum concurrent connections (default: 5).
    ///   - retryPolicy: Retry policy for connections (default: `.default`).
    ///   - transportBackend: The transport backend (default: `.network`).
    init(
        configuration: MailServerConfiguration,
        credentials: MailCredentials,
        maxConnections: Int = 5,
        retryPolicy: RetryPolicy = .default,
        transportBackend: AsyncTransportBackend = .network
    ) {
        self.init(
            configuration: configuration,
            credentials: credentials,
            maxConnections: maxConnections,
            retryPolicy: retryPolicy,
            serviceFactory: {
                let transport = try AsyncTransportFactory.make(
                    host: configuration.host,
                    port: configuration.port,
                    backend: transportBackend
                )
                return AsyncImapMailStore(transport: transport)
            },
            authenticator: { service, creds in
                _ = try await service.authenticate(user: creds.username, password: creds.password)
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, *)
public extension ConnectionPool where Service == AsyncSmtpTransport {
    /// Creates an SMTP connection pool with default factory.
    ///
    /// This convenience initializer creates a pool configured for SMTP
    /// connections using PLAIN authentication.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pool = ConnectionPool<AsyncSmtpTransport>(
    ///     configuration: MailServerConfiguration(
    ///         host: "smtp.example.com",
    ///         port: 587
    ///     ),
    ///     credentials: MailCredentials(username: "user@example.com", password: "secret"),
    ///     maxConnections: 3,
    ///     localDomain: "client.example.com"
    /// )
    ///
    /// try await pool.withConnection { transport in
    ///     try await transport.sendMessage(message)
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: Server connection configuration.
    ///   - credentials: Authentication credentials.
    ///   - maxConnections: Maximum concurrent connections (default: 5).
    ///   - retryPolicy: Retry policy for connections (default: `.default`).
    ///   - transportBackend: The transport backend (default: `.network`).
    ///   - localDomain: The domain for EHLO command (default: "localhost").
    init(
        configuration: MailServerConfiguration,
        credentials: MailCredentials,
        maxConnections: Int = 5,
        retryPolicy: RetryPolicy = .default,
        transportBackend: AsyncTransportBackend = .network,
        localDomain: String = "localhost"
    ) {
        self.init(
            configuration: configuration,
            credentials: credentials,
            maxConnections: maxConnections,
            retryPolicy: retryPolicy,
            serviceFactory: {
                try AsyncSmtpTransport.make(
                    host: configuration.host,
                    port: configuration.port,
                    backend: transportBackend
                )
            },
            authenticator: { service, creds in
                _ = try await service.ehlo(domain: localDomain)
                let auth = SmtpSasl.plain(username: creds.username, password: creds.password)
                _ = try await service.authenticate(auth)
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, *)
public extension ConnectionPool where Service == AsyncPop3MailStore {
    /// Creates a POP3 connection pool with default factory.
    ///
    /// This convenience initializer creates a pool configured for POP3
    /// connections using USER/PASS authentication.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let pool = ConnectionPool<AsyncPop3MailStore>(
    ///     configuration: MailServerConfiguration(
    ///         host: "pop.example.com",
    ///         port: 995,
    ///         useTls: true
    ///     ),
    ///     credentials: MailCredentials(username: "user@example.com", password: "secret")
    /// )
    ///
    /// let messages = try await pool.withConnection { store in
    ///     try await store.list()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - configuration: Server connection configuration.
    ///   - credentials: Authentication credentials.
    ///   - maxConnections: Maximum concurrent connections (default: 5).
    ///   - retryPolicy: Retry policy for connections (default: `.default`).
    ///   - transportBackend: The transport backend (default: `.network`).
    init(
        configuration: MailServerConfiguration,
        credentials: MailCredentials,
        maxConnections: Int = 5,
        retryPolicy: RetryPolicy = .default,
        transportBackend: AsyncTransportBackend = .network
    ) {
        self.init(
            configuration: configuration,
            credentials: credentials,
            maxConnections: maxConnections,
            retryPolicy: retryPolicy,
            serviceFactory: {
                let transport = try AsyncTransportFactory.make(
                    host: configuration.host,
                    port: configuration.port,
                    backend: transportBackend
                )
                return AsyncPop3MailStore(transport: transport)
            },
            authenticator: { service, creds in
                _ = try await service.authenticate(user: creds.username, password: creds.password)
            }
        )
    }
}
