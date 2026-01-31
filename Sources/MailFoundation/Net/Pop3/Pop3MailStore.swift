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
// Pop3MailStore.swift
//
// POP3 mail store and inbox folder wrapper.
//

import MimeFoundation

/// Errors that can occur when working with POP3 folders.
///
/// POP3 protocol only supports a single folder (INBOX), so operations
/// on other folders will fail with these errors.
public enum Pop3FolderError: Error, Sendable {
    /// The specified folder is not supported by POP3.
    ///
    /// POP3 only supports the INBOX folder. Attempting to access any other
    /// folder will result in this error.
    case unsupportedFolder

    /// The requested folder access mode is not supported.
    ///
    /// POP3 folders can only be opened in read-only mode. Attempting to open
    /// a folder with read-write access will result in this error.
    case unsupportedAccess
}

/// A synchronous POP3 mail store for retrieving messages from a POP3 server.
///
/// The `Pop3MailStore` class provides a high-level interface for connecting to a POP3 server,
/// authenticating, and retrieving email messages. Unlike IMAP, POP3 only supports a single
/// folder (INBOX) and provides limited message management capabilities.
///
/// ## Overview
///
/// POP3 (Post Office Protocol version 3) is a simple protocol for retrieving email from a
/// remote server. The protocol supports:
/// - Basic authentication (USER/PASS commands)
/// - APOP authentication for secure password transmission
/// - SASL authentication mechanisms (PLAIN, LOGIN, CRAM-MD5, XOAUTH2)
/// - Message retrieval and deletion
/// - Unique message identifiers (UIDL)
///
/// ## Usage
///
/// To connect and retrieve messages:
///
/// ```swift
/// // Create a mail store using the factory method
/// let store = try Pop3MailStore.make(
///     host: "pop.example.com",
///     port: 995,
///     backend: .tls
/// )
///
/// // Connect to the server
/// try store.connect()
///
/// // Authenticate with credentials
/// try store.authenticate(user: "user@example.com", password: "secret")
///
/// // Get message count and sizes
/// let stat = try store.stat()
/// print("Messages: \(stat.count), Total size: \(stat.size) bytes")
///
/// // Retrieve a message
/// let message = try store.message(1)
/// print("Subject: \(message.subject ?? "No subject")")
///
/// // Disconnect when done
/// store.disconnect()
/// ```
///
/// ## Thread Safety
///
/// This class is not thread-safe. If you need to access the POP3 server from multiple
/// threads, use the async variant ``AsyncPop3MailStore`` or synchronize access externally.
///
/// ## See Also
///
/// - ``AsyncPop3MailStore`` for async/await support
/// - ``Pop3Folder`` for folder-level operations
/// - ``Pop3Session`` for low-level protocol access
public final class Pop3MailStore: MailServiceBase<Pop3Response>, MailStore {
    /// The folder type used by this mail store.
    public typealias FolderType = Pop3Folder

    private let session: Pop3Session

    /// The INBOX folder.
    ///
    /// In POP3, this is the only folder available. All messages are stored in the INBOX.
    public private(set) var inbox: Pop3Folder

    /// The currently selected folder, if any.
    ///
    /// For POP3, this will always be either `nil` or the INBOX folder.
    public private(set) var selectedFolder: Pop3Folder?

    /// The access mode of the currently selected folder.
    ///
    /// POP3 folders can only be opened in read-only mode.
    public private(set) var selectedAccess: FolderAccess?

    /// The protocol name for logging purposes.
    public override var protocolName: String { "POP3" }

    /// Creates a new POP3 mail store with the specified connection parameters.
    ///
    /// This factory method creates a transport connection and initializes the mail store.
    ///
    /// - Parameters:
    ///   - host: The hostname of the POP3 server.
    ///   - port: The port number to connect to (typically 110 for POP3 or 995 for POP3S).
    ///   - backend: The transport backend to use (TCP, TLS, or custom).
    ///   - proxy: Optional proxy settings for the connection.
    ///   - protocolLogger: A logger for protocol-level debugging.
    ///   - maxReads: Maximum number of read attempts for receiving responses.
    /// - Returns: A configured `Pop3MailStore` ready for connection.
    /// - Throws: An error if the transport cannot be created.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Connect over TLS (port 995)
    /// let secureStore = try Pop3MailStore.make(
    ///     host: "pop.example.com",
    ///     port: 995,
    ///     backend: .tls
    /// )
    ///
    /// // Connect with a proxy
    /// let proxyStore = try Pop3MailStore.make(
    ///     host: "pop.example.com",
    ///     port: 110,
    ///     proxy: ProxySettings(type: .socks5, host: "proxy.local", port: 1080)
    /// )
    /// ```
    public static func make(
        host: String,
        port: Int,
        backend: TransportBackend = .tcp,
        proxy: ProxySettings? = nil,
        protocolLogger: ProtocolLoggerType = NullProtocolLogger(),
        maxReads: Int = 10
    ) throws -> Pop3MailStore {
        let transport = try TransportFactory.make(host: host, port: port, backend: backend, proxy: proxy)
        return Pop3MailStore(transport: transport, protocolLogger: protocolLogger, maxReads: maxReads)
    }

    /// Initializes a new POP3 mail store with an existing transport.
    ///
    /// Use this initializer when you have already created a transport connection
    /// or need custom transport configuration.
    ///
    /// - Parameters:
    ///   - transport: The transport connection to use.
    ///   - protocolLogger: A logger for protocol-level debugging.
    ///   - maxReads: Maximum number of read attempts for receiving responses.
    public init(transport: Transport, protocolLogger: ProtocolLoggerType = NullProtocolLogger(), maxReads: Int = 10) {
        self.session = Pop3Session(transport: transport, protocolLogger: protocolLogger, maxReads: maxReads)
        self.inbox = Pop3Folder(session: self.session, store: nil)
        super.init(protocolLogger: protocolLogger)
        self.inbox.store = self
    }

    /// Connects to the POP3 server.
    ///
    /// This method establishes a connection to the POP3 server and waits for the
    /// greeting response. After connecting, you must authenticate before accessing
    /// messages.
    ///
    /// - Returns: The server's greeting response.
    /// - Throws: An error if the connection fails or the server rejects the connection.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let store = try Pop3MailStore.make(host: "pop.example.com", port: 995, backend: .tls)
    /// let greeting = try store.connect()
    /// print("Server says: \(greeting.message)")
    /// ```
    @discardableResult
    public override func connect() throws -> Pop3Response {
        let response = try session.connect()
        updateState(.connected)
        return response
    }

    /// Authenticates using the USER and PASS commands.
    ///
    /// This is the most basic form of POP3 authentication. The password is sent
    /// in clear text, so this method should only be used over a secure (TLS) connection.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password.
    /// - Returns: A tuple containing the server responses to the USER and PASS commands.
    /// - Throws: An error if authentication fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let (userResponse, passResponse) = try store.authenticate(
    ///     user: "user@example.com",
    ///     password: "secret"
    /// )
    /// ```
    public func authenticate(user: String, password: String) throws -> (user: Pop3Response, pass: Pop3Response) {
        let responses = try session.authenticate(user: user, password: password)
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return responses
    }

    /// Authenticates using the APOP command with a pre-computed digest.
    ///
    /// APOP provides a more secure authentication method where the password is never
    /// sent over the network. Instead, an MD5 digest of the server's timestamp and
    /// the password is sent.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - digest: The pre-computed MD5 digest of the timestamp and password.
    /// - Returns: The server's response to the APOP command.
    /// - Throws: An error if authentication fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Get the challenge from the greeting response
    /// let greeting = try store.connect()
    /// if let challenge = greeting.apopChallenge {
    ///     let digest = Pop3Apop.digest(challenge: challenge, password: "secret")!
    ///     try store.authenticateApop(user: "user", digest: digest)
    /// }
    /// ```
    ///
    /// - Note: Use ``authenticateApop(user:password:)`` to automatically compute the digest.
    public func authenticateApop(user: String, digest: String) throws -> Pop3Response {
        let response = try session.apop(user: user, digest: digest)
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return response
    }

    /// Authenticates using the APOP command with automatic digest computation.
    ///
    /// This method extracts the server's timestamp from the greeting response and
    /// computes the MD5 digest automatically.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password (used to compute the digest).
    /// - Returns: The server's response to the APOP command.
    /// - Throws: An error if authentication fails or APOP is not available.
    ///
    /// ## Example
    ///
    /// ```swift
    /// try store.connect()
    /// try store.authenticateApop(user: "user@example.com", password: "secret")
    /// ```
    public func authenticateApop(user: String, password: String) throws -> Pop3Response {
        let response = try session.authenticateApop(user: user, password: password)
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return response
    }

    /// Authenticates using SASL with automatic mechanism selection.
    ///
    /// This method selects the most secure SASL mechanism supported by both
    /// the client and server. The selection order is: CRAM-MD5, PLAIN, LOGIN.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password.
    ///   - capabilities: Optional server capabilities. If nil, capabilities will be queried.
    ///   - mechanisms: Optional list of allowed mechanisms. If nil, all supported mechanisms are tried.
    ///   - channelBinding: Optional SCRAM channel binding data. If `nil`, the store uses
    ///     the transport's TLS channel binding when available.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails or no suitable mechanism is available.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Use automatic mechanism selection
    /// try store.authenticateSasl(user: "user@example.com", password: "secret")
    ///
    /// // Restrict to specific mechanisms
    /// try store.authenticateSasl(
    ///     user: "user@example.com",
    ///     password: "secret",
    ///     mechanisms: ["PLAIN", "LOGIN"]
    /// )
    /// ```
    public func authenticateSasl(
        user: String,
        password: String,
        capabilities: Pop3Capabilities? = nil,
        mechanisms: [String]? = nil,
        channelBinding: ScramChannelBinding? = nil
    ) throws -> Pop3Response {
        let response = try session.authenticateSasl(
            user: user,
            password: password,
            capabilities: capabilities,
            mechanisms: mechanisms,
            channelBinding: channelBinding
        )
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return response
    }

    /// Authenticates using the CRAM-MD5 SASL mechanism.
    ///
    /// CRAM-MD5 provides challenge-response authentication where the password
    /// is never sent over the network in any form.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails or CRAM-MD5 is not supported.
    public func authenticateCramMd5(user: String, password: String) throws -> Pop3Response {
        let response = try session.authenticateCramMd5(user: user, password: password)
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return response
    }

    /// Authenticates using XOAUTH2 for OAuth 2.0 authentication.
    ///
    /// This method is used for OAuth 2.0 authentication with services like Gmail
    /// and Outlook.com. You must obtain an access token from the OAuth provider
    /// before calling this method.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - accessToken: The OAuth 2.0 access token.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // After obtaining an OAuth access token
    /// try store.authenticateXoauth2(
    ///     user: "user@gmail.com",
    ///     accessToken: oauthAccessToken
    /// )
    /// ```
    public func authenticateXoauth2(user: String, accessToken: String) throws -> Pop3Response {
        let response = try session.authenticateXoauth2(user: user, accessToken: accessToken)
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return response
    }

    /// Authenticates using SASL with an OAuth access token.
    ///
    /// This method allows OAuth authentication with automatic mechanism selection.
    /// It will prefer XOAUTH2 if available in the mechanisms list.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - accessToken: The OAuth 2.0 access token.
    ///   - capabilities: Optional server capabilities. If nil, capabilities will be queried.
    ///   - mechanisms: Optional list of allowed mechanisms.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails.
    public func authenticateSasl(
        user: String,
        accessToken: String,
        capabilities: Pop3Capabilities? = nil,
        mechanisms: [String]? = nil
    ) throws -> Pop3Response {
        let response = try session.authenticateSasl(
            user: user,
            accessToken: accessToken,
            capabilities: capabilities,
            mechanisms: mechanisms
        )
        updateState(.authenticated)
        _ = try inbox.open(.readOnly)
        return response
    }

    /// Disconnects from the POP3 server.
    ///
    /// This method sends the QUIT command to the server, which causes any messages
    /// marked for deletion to be permanently removed. After disconnecting, you must
    /// call ``connect()`` again before performing any operations.
    ///
    /// ## Important
    ///
    /// Messages marked for deletion with ``dele(_:)`` are only permanently deleted
    /// when the connection is closed properly with this method. If the connection
    /// is dropped unexpectedly, deleted messages will be restored.
    public override func disconnect() {
        inbox.close()
        session.disconnect()
        updateSelectedFolder(nil, access: nil)
        super.disconnect()
    }

    /// Gets a folder by its path.
    ///
    /// Since POP3 only supports the INBOX folder, this method only succeeds
    /// when the path is "INBOX" (case-insensitive).
    ///
    /// - Parameter path: The folder path (must be "INBOX").
    /// - Returns: The INBOX folder.
    /// - Throws: ``Pop3FolderError/unsupportedFolder`` if the path is not "INBOX".
    public func getFolder(_ path: String) throws -> Pop3Folder {
        guard path.caseInsensitiveCompare("INBOX") == .orderedSame else {
            throw Pop3FolderError.unsupportedFolder
        }
        return inbox
    }

    /// Gets folders matching a pattern.
    ///
    /// Since POP3 only supports the INBOX folder, this method returns the INBOX
    /// when the pattern matches, or an empty array otherwise.
    ///
    /// - Parameters:
    ///   - reference: The reference path (ignored for POP3).
    ///   - pattern: The folder pattern to match.
    ///   - subscribedOnly: Whether to return only subscribed folders (ignored for POP3).
    /// - Returns: An array containing the INBOX if the pattern matches, otherwise empty.
    public func getFolders(reference: String, pattern: String, subscribedOnly: Bool = false) throws -> [Pop3Folder] {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "*" || trimmed == "%" || trimmed.caseInsensitiveCompare("INBOX") == .orderedSame {
            return [inbox]
        }
        return []
    }

    /// Opens the INBOX folder.
    ///
    /// This is a convenience method that opens the INBOX with the specified access mode.
    ///
    /// - Parameter access: The access mode (must be `.readOnly` for POP3).
    /// - Returns: The opened INBOX folder.
    /// - Throws: ``Pop3FolderError/unsupportedAccess`` if access is not `.readOnly`.
    public func openInbox(access: FolderAccess = .readOnly) throws -> Pop3Folder {
        _ = try inbox.open(access)
        return inbox
    }

    /// Sends a NOOP command to keep the connection alive.
    ///
    /// The NOOP command does nothing but can be used to reset inactivity timers
    /// on the server side, preventing the connection from being dropped.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func noop() throws -> Pop3Response {
        try session.noop()
    }

    /// Resets the session state, undeleting any messages marked for deletion.
    ///
    /// This command unmarks any messages that have been marked for deletion
    /// during this session. It is useful if you want to cancel deletion operations
    /// before disconnecting.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func rset() throws -> Pop3Response {
        try session.rset()
    }

    /// Marks a message for deletion.
    ///
    /// The message is not actually deleted until the session ends with a proper
    /// QUIT command (via ``disconnect()``). Use ``rset()`` to unmark all messages
    /// marked for deletion.
    ///
    /// - Parameter index: The 1-based message index to delete.
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    ///
    /// ## Important
    ///
    /// POP3 message indices are 1-based, not 0-based. The first message is index 1.
    public func dele(_ index: Int) throws -> Pop3Response {
        try session.dele(index)
    }

    /// Gets the highest message number accessed in this session.
    ///
    /// This is an optional POP3 extension command (LAST) that returns the highest
    /// message number that has been accessed during this session.
    ///
    /// - Returns: The highest accessed message number.
    /// - Throws: An error if the command fails or is not supported.
    public func last() throws -> Int {
        try session.last()
    }

    private func requireSelectedFolder() throws -> Pop3Folder {
        guard let folder = selectedFolder else {
            throw Pop3MailStoreError.noSelectedFolder
        }
        return folder
    }

    /// Gets the message count and total size of the mailbox.
    ///
    /// This method sends the STAT command to retrieve the number of messages
    /// and their total size in bytes.
    ///
    /// - Returns: A ``Pop3StatResponse`` containing the count and size.
    /// - Throws: An error if no folder is selected or the command fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let stat = try store.stat()
    /// print("You have \(stat.count) messages totaling \(stat.size) bytes")
    /// ```
    public func stat() throws -> Pop3StatResponse {
        try requireSelectedFolder().stat()
    }

    /// Gets a list of all messages with their sizes.
    ///
    /// This method sends the LIST command to retrieve the index and size
    /// of every message in the mailbox.
    ///
    /// - Returns: An array of ``Pop3ListItem`` containing message indices and sizes.
    /// - Throws: An error if no folder is selected or the command fails.
    public func list() throws -> [Pop3ListItem] {
        try requireSelectedFolder().list()
    }

    /// Gets the size of a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3ListItem`` containing the message index and size.
    /// - Throws: An error if no folder is selected or the command fails.
    public func list(_ index: Int) throws -> Pop3ListItem {
        try requireSelectedFolder().list(index)
    }

    /// Gets the unique identifiers for all messages.
    ///
    /// The UIDL command returns unique identifiers that persist across sessions.
    /// Unlike message indices which can change when messages are deleted, UIDs
    /// remain constant and can be used to track messages.
    ///
    /// - Returns: An array of ``Pop3UidlItem`` containing message indices and UIDs.
    /// - Throws: An error if no folder is selected or the command fails.
    public func uidl() throws -> [Pop3UidlItem] {
        try requireSelectedFolder().uidl()
    }

    /// Gets the unique identifier for a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3UidlItem`` containing the message index and UID.
    /// - Throws: An error if no folder is selected or the command fails.
    public func uidl(_ index: Int) throws -> Pop3UidlItem {
        try requireSelectedFolder().uidl(index)
    }

    /// Retrieves a message as an array of lines.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as an array of strings (one per line).
    /// - Throws: An error if no folder is selected or the command fails.
    public func retr(_ index: Int) throws -> [String] {
        try requireSelectedFolder().retr(index)
    }

    /// Retrieves a message as structured data.
    ///
    /// This method provides access to the raw message bytes along with
    /// helper methods for parsing headers and body.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3MessageData`` containing the response and message bytes.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retrData(_ index: Int) throws -> Pop3MessageData {
        try requireSelectedFolder().retrData(index)
    }

    /// Retrieves and parses a message as a MIME message.
    ///
    /// This is the highest-level method for retrieving messages. It downloads
    /// the complete message and parses it into a ``MimeMessage`` object.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - options: Parser options for controlling MIME parsing behavior.
    /// - Returns: The parsed ``MimeMessage``.
    /// - Throws: An error if no folder is selected, the command fails, or parsing fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let message = try store.message(1)
    /// print("From: \(message.from)")
    /// print("Subject: \(message.subject ?? "No subject")")
    /// print("Body: \(message.textBody ?? "No body")")
    /// ```
    public func message(_ index: Int, options: ParserOptions = .default) throws -> MimeMessage {
        try requireSelectedFolder().message(index, options: options)
    }

    /// Retrieves a message as raw bytes.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as a byte array.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retrRaw(_ index: Int) throws -> [UInt8] {
        try requireSelectedFolder().retrRaw(index)
    }

    /// Retrieves a message in streaming fashion.
    ///
    /// This method is useful for large messages where you want to process
    /// the data incrementally without loading the entire message into memory.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - sink: A closure called with each chunk of message data.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retrStream(_ index: Int, sink: ([UInt8]) throws -> Void) throws {
        try requireSelectedFolder().retrStream(index, sink: sink)
    }

    /// Retrieves message headers and the first few lines of the body.
    ///
    /// The TOP command retrieves the message headers plus a specified number
    /// of lines from the message body. This is useful for previewing messages
    /// without downloading the entire content.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The message headers and body lines as an array of strings.
    /// - Throws: An error if no folder is selected or the command fails.
    public func top(_ index: Int, lines: Int) throws -> [String] {
        try requireSelectedFolder().top(index, lines: lines)
    }

    /// Retrieves message headers and body preview as structured data.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: A ``Pop3MessageData`` containing the response and data.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topData(_ index: Int, lines: Int) throws -> Pop3MessageData {
        try requireSelectedFolder().topData(index, lines: lines)
    }

    /// Retrieves and parses message headers.
    ///
    /// This method uses the TOP command with 0 lines to retrieve just the
    /// message headers, then parses them into a ``HeaderList``.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve (typically 0 for headers only).
    /// - Returns: The parsed ``HeaderList``.
    /// - Throws: An error if no folder is selected or the command fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let headers = try store.topHeaders(1, lines: 0)
    /// if let subject = headers["Subject"]?.value {
    ///     print("Subject: \(subject)")
    /// }
    /// ```
    public func topHeaders(_ index: Int, lines: Int) throws -> HeaderList {
        try requireSelectedFolder().topHeaders(index, lines: lines)
    }

    /// Retrieves message headers and body preview as raw bytes.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The data as a byte array.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topRaw(_ index: Int, lines: Int) throws -> [UInt8] {
        try requireSelectedFolder().topRaw(index, lines: lines)
    }

    /// Retrieves message headers and body preview in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    ///   - sink: A closure called with each chunk of data.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topStream(_ index: Int, lines: Int, sink: ([UInt8]) throws -> Void) throws {
        try requireSelectedFolder().topStream(index, lines: lines, sink: sink)
    }

    internal func updateSelectedFolder(_ folder: Pop3Folder?, access: FolderAccess?) {
        selectedFolder = folder
        selectedAccess = access
    }
}

/// Represents the POP3 INBOX folder.
///
/// POP3 only supports a single folder called INBOX where all messages are stored.
/// This class provides methods for listing, retrieving, and deleting messages
/// within the INBOX.
///
/// ## Overview
///
/// Unlike IMAP, POP3 has no concept of multiple folders or hierarchical
/// organization. All operations are performed on the INBOX, and the only
/// access mode supported is read-only.
///
/// ## Message Operations
///
/// The folder provides several ways to access messages:
///
/// - ``stat()`` - Get message count and total size
/// - ``list()`` - Get sizes of all messages
/// - ``uidl()`` - Get unique identifiers for all messages
/// - ``retr(_:)`` - Download a complete message
/// - ``top(_:lines:)`` - Download headers and a preview
/// - ``dele(_:)`` - Mark a message for deletion
///
/// ## Thread Safety
///
/// This class is not thread-safe. Access should be synchronized externally
/// if used from multiple threads.
///
/// ## See Also
///
/// - ``Pop3MailStore`` for the parent mail store
/// - ``AsyncPop3Folder`` for async/await support
public final class Pop3Folder: MailFolderBase {
    fileprivate weak var store: Pop3MailStore?
    private let session: Pop3Session

    /// Initializes a new POP3 folder.
    ///
    /// - Parameters:
    ///   - session: The POP3 session to use for commands.
    ///   - store: The parent mail store (weak reference to avoid retain cycles).
    public init(session: Pop3Session, store: Pop3MailStore?) {
        self.session = session
        self.store = store
        super.init(fullName: "INBOX", delimiter: nil)
    }

    /// Opens the folder with the specified access mode.
    ///
    /// POP3 only supports read-only access to the INBOX.
    ///
    /// - Parameter access: The access mode (must be `.readOnly`).
    /// - Returns: `nil` (POP3 has no SELECT response).
    /// - Throws: ``Pop3FolderError/unsupportedAccess`` if access is not `.readOnly`.
    public func open(_ access: FolderAccess) throws -> Pop3Response? {
        guard access == .readOnly else {
            throw Pop3FolderError.unsupportedAccess
        }
        updateOpenState(access)
        store?.updateSelectedFolder(self, access: access)
        return nil
    }

    /// Closes the folder.
    ///
    /// This method updates the folder's open state but does not send any
    /// commands to the server.
    public func close() {
        updateOpenState(nil)
        store?.updateSelectedFolder(nil, access: nil)
    }

    /// Sends a NOOP command to keep the connection alive.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func noop() throws -> Pop3Response {
        try session.noop()
    }

    /// Resets the session state, undeleting any messages marked for deletion.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func rset() throws -> Pop3Response {
        try session.rset()
    }

    /// Marks a message for deletion.
    ///
    /// The message is not actually deleted until the session ends with QUIT.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func dele(_ index: Int) throws -> Pop3Response {
        try session.dele(index)
    }

    /// Gets the highest message number accessed in this session.
    ///
    /// - Returns: The highest accessed message number.
    /// - Throws: An error if the command fails or is not supported.
    public func last() throws -> Int {
        try session.last()
    }

    /// Gets the message count and total size of the mailbox.
    ///
    /// - Returns: A ``Pop3StatResponse`` containing the count and size.
    /// - Throws: An error if the command fails.
    public func stat() throws -> Pop3StatResponse {
        try session.stat()
    }

    /// Gets a list of all messages with their sizes.
    ///
    /// - Returns: An array of ``Pop3ListItem`` containing message indices and sizes.
    /// - Throws: An error if the command fails.
    public func list() throws -> [Pop3ListItem] {
        try session.list()
    }

    /// Gets the size of a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3ListItem`` containing the message index and size.
    /// - Throws: An error if the command fails.
    public func list(_ index: Int) throws -> Pop3ListItem {
        try session.list(index)
    }

    /// Gets the unique identifiers for all messages.
    ///
    /// - Returns: An array of ``Pop3UidlItem`` containing message indices and UIDs.
    /// - Throws: An error if the command fails.
    public func uidl() throws -> [Pop3UidlItem] {
        try session.uidl()
    }

    /// Gets the unique identifier for a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3UidlItem`` containing the message index and UID.
    /// - Throws: An error if the command fails.
    public func uidl(_ index: Int) throws -> Pop3UidlItem {
        try session.uidl(index)
    }

    /// Retrieves a message as an array of lines.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as an array of strings.
    /// - Throws: An error if the command fails.
    public func retr(_ index: Int) throws -> [String] {
        try session.retr(index)
    }

    /// Retrieves a message as structured data.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3MessageData`` containing the response and message bytes.
    /// - Throws: An error if the command fails.
    public func retrData(_ index: Int) throws -> Pop3MessageData {
        try session.retrData(index)
    }

    /// Retrieves and parses a message as a MIME message.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - options: Parser options for controlling MIME parsing behavior.
    /// - Returns: The parsed ``MimeMessage``.
    /// - Throws: An error if the command fails or parsing fails.
    public func message(_ index: Int, options: ParserOptions = .default) throws -> MimeMessage {
        try retrData(index).message(options: options)
    }

    /// Retrieves a message as raw bytes.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as a byte array.
    /// - Throws: An error if the command fails.
    public func retrRaw(_ index: Int) throws -> [UInt8] {
        try session.retrRaw(index)
    }

    /// Retrieves a message in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - sink: A closure called with each chunk of message data.
    /// - Throws: An error if the command fails.
    public func retrStream(_ index: Int, sink: ([UInt8]) throws -> Void) throws {
        try session.retrStream(index, sink: sink)
    }

    /// Retrieves message headers and the first few lines of the body.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The message headers and body lines as an array of strings.
    /// - Throws: An error if the command fails.
    public func top(_ index: Int, lines: Int) throws -> [String] {
        try session.top(index, lines: lines)
    }

    /// Retrieves message headers and body preview as structured data.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: A ``Pop3MessageData`` containing the response and data.
    /// - Throws: An error if the command fails.
    public func topData(_ index: Int, lines: Int) throws -> Pop3MessageData {
        try session.topData(index, lines: lines)
    }

    /// Retrieves and parses message headers.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The parsed ``HeaderList``.
    /// - Throws: An error if the command fails.
    public func topHeaders(_ index: Int, lines: Int) throws -> HeaderList {
        try topData(index, lines: lines).parseHeaders()
    }

    /// Retrieves message headers and body preview as raw bytes.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The data as a byte array.
    /// - Throws: An error if the command fails.
    public func topRaw(_ index: Int, lines: Int) throws -> [UInt8] {
        try session.topRaw(index, lines: lines)
    }

    /// Retrieves message headers and body preview in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    ///   - sink: A closure called with each chunk of data.
    /// - Throws: An error if the command fails.
    public func topStream(_ index: Int, lines: Int, sink: ([UInt8]) throws -> Void) throws {
        try session.topStream(index, lines: lines, sink: sink)
    }
}
