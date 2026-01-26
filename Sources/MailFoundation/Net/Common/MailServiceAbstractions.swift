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
// MailServiceAbstractions.swift
//
// Base mail service/transport protocols (ported from MailKit abstractions).
//

// MARK: - MailServiceState

/// Represents the current connection and authentication state of a mail service.
///
/// Mail services progress through these states as they connect to and authenticate
/// with a mail server. The state determines which operations are valid to perform.
///
/// ## State Transitions
///
/// ```
/// disconnected -> connected -> authenticated
///       ^              |             |
///       |______________|_____________|
/// ```
///
/// - Note: Ported from MailKit's connection state management pattern.
public enum MailServiceState: Sendable, Equatable {
    /// The service is not connected to any server.
    ///
    /// This is the initial state and the state after calling ``MailService/disconnect()``.
    case disconnected

    /// The service is connected to a server but not yet authenticated.
    ///
    /// In this state, the service has established a network connection and may have
    /// received server capabilities, but the user has not yet been authenticated.
    case connected

    /// The service is connected and the user has been authenticated.
    ///
    /// All mail operations (sending, receiving, folder management) are available
    /// in this state.
    case authenticated
}

// MARK: - MailService Protocol

/// A protocol defining the core interface for mail services such as SMTP, POP3, or IMAP.
///
/// `MailService` provides the fundamental connection lifecycle management for all mail
/// protocols. It defines how services connect to servers, track their connection state,
/// and disconnect when finished.
///
/// ## Conforming Types
///
/// This protocol is implemented by:
/// - ``SmtpTransport`` for sending mail via SMTP
/// - ``Pop3MailStore`` for retrieving mail via POP3
/// - ``ImapMailStore`` for full mailbox access via IMAP
///
/// ## Example Usage
///
/// ```swift
/// let transport = SmtpTransport(host: "smtp.example.com", port: 587)
/// try transport.connect()
/// defer { transport.disconnect() }
///
/// if transport.isAuthenticated {
///     // Perform mail operations
/// }
/// ```
///
/// - Note: Ported from MailKit's `IMailService` interface.
public protocol MailService: AnyObject {
    /// The type returned when establishing a connection.
    ///
    /// Different protocols return different information upon connection.
    /// For example, SMTP returns server capabilities, while IMAP returns
    /// greeting information.
    associatedtype ConnectResponse

    /// The current connection and authentication state of the service.
    ///
    /// Use this property to determine what operations are currently valid.
    /// The state progresses from ``MailServiceState/disconnected`` to
    /// ``MailServiceState/connected`` to ``MailServiceState/authenticated``.
    var state: MailServiceState { get }

    /// Indicates whether the service is currently connected to a server.
    ///
    /// This property returns `true` when the state is either
    /// ``MailServiceState/connected`` or ``MailServiceState/authenticated``.
    ///
    /// - Note: A connected service may not yet be authenticated.
    var isConnected: Bool { get }

    /// Indicates whether the service is connected and authenticated.
    ///
    /// This property returns `true` only when the state is
    /// ``MailServiceState/authenticated``. Most mail operations require
    /// the service to be authenticated before they can be performed.
    var isAuthenticated: Bool { get }

    /// Establishes a connection to the mail server.
    ///
    /// This method initiates a connection to the configured mail server.
    /// Upon successful connection, the ``state`` property will be updated
    /// to ``MailServiceState/connected``.
    ///
    /// - Returns: Protocol-specific connection response containing server
    ///   capabilities or greeting information.
    /// - Throws: Connection errors if the server is unreachable or rejects
    ///   the connection.
    ///
    /// - Note: After connecting, you typically need to authenticate before
    ///   performing mail operations.
    @discardableResult
    func connect() throws -> ConnectResponse

    /// Disconnects from the mail server.
    ///
    /// This method closes the connection to the mail server and resets
    /// the ``state`` to ``MailServiceState/disconnected``.
    ///
    /// - Note: This method is safe to call even if not connected.
    func disconnect()
}

// MARK: - AsyncMailService Protocol

/// An asynchronous version of ``MailService`` for use with Swift concurrency.
///
/// `AsyncMailService` provides the same functionality as ``MailService`` but
/// with `async` methods suitable for use in concurrent Swift code.
///
/// ## Example Usage
///
/// ```swift
/// let store = AsyncImapMailStore(transport: transport)
/// _ = try await store.connect()
/// defer { Task { await store.disconnect() } }
///
/// if await store.isAuthenticated {
///     // Perform async mail operations
/// }
/// ```
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncMailService: AnyObject {
    /// The type returned when establishing a connection.
    associatedtype ConnectResponse

    /// The current connection and authentication state of the service.
    var state: MailServiceState { get async }

    /// Indicates whether the service is currently connected to a server.
    var isConnected: Bool { get async }

    /// Indicates whether the service is connected and authenticated.
    var isAuthenticated: Bool { get async }

    /// Asynchronously establishes a connection to the mail server.
    ///
    /// - Returns: Protocol-specific connection response.
    /// - Throws: Connection errors if the server is unreachable.
    @discardableResult
    func connect() async throws -> ConnectResponse

    /// Asynchronously disconnects from the mail server.
    func disconnect() async
}

// MARK: - MessageTransport Protocol

/// A protocol for services capable of sending email messages.
///
/// `MessageTransport` defines the basic interface for sending raw email data
/// to recipients. It is used by SMTP-based services.
///
/// - Note: This protocol handles the low-level sending of message data.
///   Higher-level APIs may provide convenience methods for sending
///   ``MimeMessage`` objects directly.
public protocol MessageTransport: AnyObject {
    /// Sends a message with the specified envelope information.
    ///
    /// This method transmits raw message data to the specified recipients.
    /// The message data should be a complete RFC 5322 formatted email.
    ///
    /// - Parameters:
    ///   - from: The envelope sender address (MAIL FROM).
    ///   - recipients: The envelope recipient addresses (RCPT TO).
    ///   - data: The raw message data as UTF-8 encoded bytes.
    /// - Throws: Transport errors if the message cannot be sent.
    func sendMessage(from: String, to recipients: [String], data: [UInt8]) throws
}

/// A handler called when a message has been successfully sent.
///
/// - Parameter event: Information about the sent message and server response.
public typealias MessageSentHandler = @Sendable (MessageSentEvent) -> Void

// MARK: - MailTransport Protocol

/// A protocol combining mail service lifecycle with message sending capabilities.
///
/// `MailTransport` represents a complete SMTP client that can connect to a server,
/// authenticate, and send messages. It also supports notification handlers for
/// tracking sent messages.
///
/// ## Example Usage
///
/// ```swift
/// let transport = SmtpTransport(host: "smtp.example.com", port: 587)
/// transport.addMessageSentHandler { event in
///     print("Message sent: \(event.response)")
/// }
///
/// try transport.connect()
/// try transport.authenticate(user: "user", password: "pass")
/// try transport.sendMessage(message)
/// transport.disconnect()
/// ```
public protocol MailTransport: MailService, MessageTransport {
    /// Adds a handler to be called when a message is successfully sent.
    ///
    /// Multiple handlers can be added and will all be called in the order
    /// they were registered.
    ///
    /// - Parameter handler: The handler to call when a message is sent.
    func addMessageSentHandler(_ handler: @escaping MessageSentHandler)

    /// Removes all registered message sent handlers.
    func removeAllMessageSentHandlers()
}

// MARK: - Async Message Transport

/// An asynchronous version of ``MessageTransport``.
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncMessageTransport: AnyObject {
    /// Asynchronously sends a message with the specified envelope information.
    ///
    /// - Parameters:
    ///   - from: The envelope sender address (MAIL FROM).
    ///   - recipients: The envelope recipient addresses (RCPT TO).
    ///   - data: The raw message data as UTF-8 encoded bytes.
    /// - Throws: Transport errors if the message cannot be sent.
    func sendMessage(from: String, to recipients: [String], data: [UInt8]) async throws
}

/// An asynchronous handler called when a message has been successfully sent.
@available(macOS 10.15, iOS 13.0, *)
public typealias AsyncMessageSentHandler = @Sendable (MessageSentEvent) async -> Void

// MARK: - AsyncMailTransport Protocol

/// An asynchronous version of ``MailTransport`` for use with Swift concurrency.
///
/// `AsyncMailTransport` provides the same functionality as ``MailTransport``
/// but with `async` methods suitable for concurrent Swift code.
///
/// ## Example Usage
///
/// ```swift
/// let transport = try AsyncSmtpTransport.make(host: "smtp.example.com", port: 587)
/// await transport.addMessageSentHandler { event in
///     print("Message sent: \(event.response)")
/// }
///
/// _ = try await transport.connect()
/// try await transport.authenticate(mechanism: .plain(user: "user", password: "pass"))
/// try await transport.sendMessage(message)
/// await transport.disconnect()
/// ```
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncMailTransport: AsyncMailService, AsyncMessageTransport {
    /// Asynchronously adds a handler to be called when a message is sent.
    ///
    /// - Parameter handler: The handler to call when a message is sent.
    func addMessageSentHandler(_ handler: @escaping AsyncMessageSentHandler) async

    /// Asynchronously removes all registered message sent handlers.
    func removeAllMessageSentHandlers() async
}
