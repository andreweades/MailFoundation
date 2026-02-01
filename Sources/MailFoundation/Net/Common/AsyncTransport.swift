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
// AsyncTransport.swift
//
// Async transport abstraction.
//

// MARK: - AsyncTransport Protocol

/// An asynchronous protocol for network transport operations.
///
/// `AsyncTransport` provides an async/await interface for network communication,
/// designed for use with Swift concurrency. Data is received through an
/// ``AsyncStream`` and sent using async methods.
///
/// ## Implementations
///
/// - ``NetworkTransport``: Built on Apple's Network framework
/// - ``SocketTransport``: POSIX socket-based implementation
/// - ``AsyncStreamTransport``: In-memory transport for testing
/// - ``OpenSSLTransport``: OpenSSL-based implementation
///
/// ## Usage Pattern
///
/// ```swift
/// let transport = try AsyncTransportFactory.make(
///     host: "mail.example.com",
///     port: 587,
///     backend: .network
/// )
///
/// try await transport.start()
/// defer { Task { await transport.stop() } }
///
/// try await transport.send(Array("EHLO example.com\r\n".utf8))
///
/// for await chunk in transport.incoming {
///     print(String(decoding: chunk, as: UTF8.self))
///     break
/// }
/// ```
///
/// ## Thread Safety
///
/// Conforming types must be `Sendable` to support safe concurrent access.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncTransport: AnyObject, Sendable {
    /// An async stream of incoming data chunks.
    ///
    /// Iterate over this stream to receive data from the transport.
    /// The stream terminates when the transport is stopped or the
    /// connection is closed by the remote end.
    ///
    /// ```swift
    /// for await chunk in transport.incoming {
    ///     process(chunk)
    /// }
    /// ```
    var incoming: AsyncStream<[UInt8]> { get }

    /// Starts the transport and establishes the connection.
    ///
    /// Call this method before sending or receiving data. The
    /// ``incoming`` stream becomes active after this method completes.
    ///
    /// - Throws: ``AsyncTransportError/connectionFailed`` if the connection
    ///   cannot be established.
    func start() async throws

    /// Stops the transport and closes the connection.
    ///
    /// After calling this method, the ``incoming`` stream terminates
    /// and no further data can be sent.
    func stop() async

    /// Sends data through the transport.
    ///
    /// This method queues the data for transmission and returns when
    /// the data has been sent or buffered by the underlying transport.
    ///
    /// - Parameter bytes: The data to send.
    /// - Throws: ``AsyncTransportError/sendFailed`` if the data cannot be sent,
    ///   or ``AsyncTransportError/notStarted`` if the transport is not started.
    func send(_ bytes: [UInt8]) async throws
}

// MARK: - AsyncStartTlsTransport Protocol

/// An async transport that supports upgrading to TLS encryption.
///
/// `AsyncStartTlsTransport` extends ``AsyncTransport`` with the ability
/// to upgrade an unencrypted connection to TLS, as required by the
/// STARTTLS command in mail protocols.
///
/// ## STARTTLS Flow
///
/// ```swift
/// let transport: AsyncStartTlsTransport = ...
/// try await transport.start()
///
/// // Perform initial protocol handshake
/// try await transport.send(Array("EHLO example.com\r\n".utf8))
/// // ... receive response ...
///
/// // Upgrade to TLS
/// try await transport.send(Array("STARTTLS\r\n".utf8))
/// // ... receive 220 response ...
/// try await transport.startTLS(validateCertificate: true)
///
/// // Continue with encrypted communication
/// try await transport.send(Array("EHLO example.com\r\n".utf8))
/// ```
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncStartTlsTransport: AsyncTransport {
    /// Optional channel binding data for SCRAM-PLUS authentication.
    ///
    /// Transports that can access TLS session details should expose a
    /// ``ScramChannelBinding`` (typically `tls-server-end-point`).
    /// Access this asynchronously after STARTTLS completes.
    var scramChannelBinding: ScramChannelBinding? { get async }

    /// Upgrades the connection to use TLS encryption.
    ///
    /// This method performs the TLS handshake asynchronously.
    /// After successful completion, all subsequent communication
    /// is encrypted.
    ///
    /// - Parameter validateCertificate: If `true`, validates the server's
    ///   certificate. Set to `false` only for testing.
    /// - Throws: An error if the TLS handshake fails.
    ///
    /// - Warning: Disabling certificate validation is insecure.
    func startTLS(validateCertificate: Bool) async throws
}

// MARK: - AsyncCompressionTransport Protocol

/// An async transport that supports enabling IMAP COMPRESS.
///
/// After a successful COMPRESS command, the transport should begin compressing
/// subsequent reads and writes.
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncCompressionTransport: AsyncTransport {
    /// Enables compression for subsequent reads and writes.
    ///
    /// - Parameter algorithm: The negotiated compression algorithm (e.g., "DEFLATE").
    func startCompression(algorithm: String) async throws
}

// MARK: - AsyncTransportError

/// Errors that can occur during async transport operations.
///
/// These errors indicate failures in the transport layer, such as
/// connection problems or send/receive failures.
public enum AsyncTransportError: Error, Sendable {
    /// The transport has not been started.
    ///
    /// Call ``AsyncTransport/start()`` before attempting to send data.
    case notStarted

    /// Failed to send data through the transport.
    ///
    /// This may indicate a connection problem or that the transport
    /// has been stopped.
    case sendFailed

    /// Failed to receive data from the transport.
    ///
    /// This may indicate a connection problem or that the remote
    /// end has closed the connection.
    case receiveFailed

    /// Failed to establish the connection.
    ///
    /// This occurs when ``AsyncTransport/start()`` cannot connect
    /// to the remote host.
    case connectionFailed
}
