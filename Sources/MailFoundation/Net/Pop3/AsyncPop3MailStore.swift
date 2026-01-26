//
// AsyncPop3MailStore.swift
//
// Async POP3 mail store and inbox folder wrapper.
//

import MimeFoundation

/// An asynchronous POP3 mail store for retrieving messages from a POP3 server.
///
/// The `AsyncPop3MailStore` class provides an async/await interface for connecting to a POP3 server,
/// authenticating, and retrieving email messages. This is the preferred API for Swift concurrency
/// environments.
///
/// ## Overview
///
/// Unlike the synchronous ``Pop3MailStore``, this class is implemented as an actor, providing
/// inherent thread safety for concurrent access. All operations are asynchronous and support
/// Swift's structured concurrency model.
///
/// ## Usage
///
/// To connect and retrieve messages:
///
/// ```swift
/// // Create a mail store using the factory method
/// let store = try AsyncPop3MailStore.make(
///     host: "pop.example.com",
///     port: 995,
///     backend: .tls
/// )
///
/// // Connect to the server
/// try await store.connect()
///
/// // Authenticate with credentials
/// try await store.authenticate(user: "user@example.com", password: "secret")
///
/// // Get message count and sizes
/// if let stat = try await store.stat() {
///     print("Messages: \(stat.count), Total size: \(stat.size) bytes")
/// }
///
/// // Retrieve a message
/// let message = try await store.message(1)
/// print("Subject: \(message.subject ?? "No subject")")
///
/// // Disconnect when done
/// await store.disconnect()
/// ```
///
/// ## Timeouts
///
/// Network operations have a configurable timeout (default: 2 minutes). You can adjust this
/// using the ``setTimeout(milliseconds:)`` method:
///
/// ```swift
/// await store.setTimeout(milliseconds: 30_000)  // 30 seconds
/// ```
///
/// ## See Also
///
/// - ``Pop3MailStore`` for synchronous operations
/// - ``AsyncPop3Folder`` for folder-level operations
/// - ``AsyncPop3Session`` for low-level protocol access
@available(macOS 10.15, iOS 13.0, *)
public actor AsyncPop3MailStore: AsyncMailStore {
    /// The folder type used by this mail store.
    public typealias FolderType = AsyncPop3Folder

    private let session: AsyncPop3Session

    /// The INBOX folder.
    ///
    /// In POP3, this is the only folder available. All messages are stored in the INBOX.
    /// This property is `nonisolated` for convenient access without awaiting.
    public nonisolated let inbox: AsyncPop3Folder

    private var selectedFolderStorage: AsyncPop3Folder?
    private var selectedAccessStorage: FolderAccess?

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

    /// Creates a new async POP3 mail store with the specified connection parameters.
    ///
    /// This factory method creates a transport connection and initializes the mail store.
    ///
    /// - Parameters:
    ///   - host: The hostname of the POP3 server.
    ///   - port: The port number to connect to (typically 110 for POP3 or 995 for POP3S).
    ///   - backend: The async transport backend to use.
    ///   - timeoutMilliseconds: The timeout for network operations in milliseconds.
    /// - Returns: A configured `AsyncPop3MailStore` ready for connection.
    /// - Throws: An error if the transport cannot be created.
    public static func make(
        host: String,
        port: UInt16,
        backend: AsyncTransportBackend = .network,
        timeoutMilliseconds: Int = defaultPop3TimeoutMs
    ) throws -> AsyncPop3MailStore {
        let transport = try AsyncTransportFactory.make(host: host, port: port, backend: backend)
        return AsyncPop3MailStore(transport: transport, timeoutMilliseconds: timeoutMilliseconds)
    }

    /// Creates a new async POP3 mail store with proxy support.
    ///
    /// This factory method creates a transport connection through a proxy server.
    ///
    /// - Parameters:
    ///   - host: The hostname of the POP3 server.
    ///   - port: The port number to connect to.
    ///   - backend: The async transport backend to use.
    ///   - proxy: The proxy settings for the connection.
    ///   - timeoutMilliseconds: The timeout for network operations in milliseconds.
    /// - Returns: A configured `AsyncPop3MailStore` ready for connection.
    /// - Throws: An error if the transport cannot be created or proxy connection fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let store = try await AsyncPop3MailStore.make(
    ///     host: "pop.example.com",
    ///     port: 995,
    ///     backend: .tls,
    ///     proxy: ProxySettings(type: .socks5, host: "proxy.local", port: 1080)
    /// )
    /// ```
    public static func make(
        host: String,
        port: UInt16,
        backend: AsyncTransportBackend = .network,
        proxy: ProxySettings,
        timeoutMilliseconds: Int = defaultPop3TimeoutMs
    ) async throws -> AsyncPop3MailStore {
        let transport = try await AsyncTransportFactory.make(host: host, port: port, backend: backend, proxy: proxy)
        return AsyncPop3MailStore(transport: transport, timeoutMilliseconds: timeoutMilliseconds)
    }

    /// Initializes a new async POP3 mail store with an existing transport.
    ///
    /// Use this initializer when you have already created a transport connection
    /// or need custom transport configuration.
    ///
    /// - Parameters:
    ///   - transport: The async transport connection to use.
    ///   - timeoutMilliseconds: The timeout for network operations in milliseconds.
    public init(transport: AsyncTransport, timeoutMilliseconds: Int = defaultPop3TimeoutMs) {
        self.session = AsyncPop3Session(transport: transport, timeoutMilliseconds: timeoutMilliseconds)
        let folder = AsyncPop3Folder(session: session, store: nil)
        self.inbox = folder
        Task { await folder.attachStore(self) }
    }

    /// Connects to the POP3 server.
    ///
    /// This method establishes a connection to the POP3 server and waits for the
    /// greeting response. After connecting, you must authenticate before accessing
    /// messages.
    ///
    /// - Returns: The server's greeting response, or `nil` if no response was received.
    /// - Throws: An error if the connection fails or the server rejects the connection.
    @discardableResult
    public func connect() async throws -> Pop3Response? {
        try await session.connect()
    }

    /// Disconnects from the POP3 server.
    ///
    /// This method sends the QUIT command to the server, which causes any messages
    /// marked for deletion to be permanently removed. After disconnecting, you must
    /// call ``connect()`` again before performing any operations.
    public func disconnect() async {
        await inbox.close()
        await session.disconnect()
        selectedFolderStorage = nil
        selectedAccessStorage = nil
    }

    /// The current connection state.
    ///
    /// Returns `.authenticated` if authenticated, `.connected` if connected but not
    /// authenticated, or `.disconnected` if not connected.
    public var state: MailServiceState {
        get async {
            await session.isAuthenticated ? .authenticated : (await session.isConnected ? .connected : .disconnected)
        }
    }

    /// Whether the client is currently connected to a POP3 server.
    public var isConnected: Bool {
        get async { await session.isConnected }
    }

    /// Whether the client has been authenticated.
    public var isAuthenticated: Bool {
        get async { await session.isAuthenticated }
    }

    /// The currently selected folder, if any.
    ///
    /// For POP3, this will always be either `nil` or the INBOX folder.
    public var selectedFolder: AsyncPop3Folder? {
        get async { selectedFolderStorage }
    }

    /// The access mode of the currently selected folder.
    ///
    /// POP3 folders can only be opened in read-only mode.
    public var selectedAccess: FolderAccess? {
        get async { selectedAccessStorage }
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
    public func authenticate(user: String, password: String) async throws -> (user: Pop3Response?, pass: Pop3Response?) {
        let responses = try await session.authenticate(user: user, password: password)
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
        return responses
    }

    /// Authenticates using the APOP command with a pre-computed digest.
    ///
    /// APOP provides a more secure authentication method where the password is never
    /// sent over the network.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - digest: The pre-computed MD5 digest of the timestamp and password.
    /// - Returns: The server's response to the APOP command.
    /// - Throws: An error if authentication fails.
    public func authenticateApop(user: String, digest: String) async throws -> Pop3Response? {
        let response = try await session.apop(user: user, digest: digest)
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
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
    public func authenticateApop(user: String, password: String) async throws -> Pop3Response? {
        let response = try await session.authenticateApop(user: user, password: password)
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
        return response
    }

    /// Authenticates using SASL with automatic mechanism selection.
    ///
    /// This method selects the most secure SASL mechanism supported by both
    /// the client and server.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - password: The user's password.
    ///   - capabilities: Optional server capabilities. If nil, capabilities will be queried.
    ///   - mechanisms: Optional list of allowed mechanisms. If nil, all supported mechanisms are tried.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails or no suitable mechanism is available.
    public func authenticateSasl(
        user: String,
        password: String,
        capabilities: Pop3Capabilities? = nil,
        mechanisms: [String]? = nil
    ) async throws -> Pop3Response? {
        let response = try await session.authenticateSasl(
            user: user,
            password: password,
            capabilities: capabilities,
            mechanisms: mechanisms
        )
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
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
    public func authenticateCramMd5(user: String, password: String) async throws -> Pop3Response? {
        let response = try await session.authenticateCramMd5(user: user, password: password)
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
        return response
    }

    /// Authenticates using XOAUTH2 for OAuth 2.0 authentication.
    ///
    /// This method is used for OAuth 2.0 authentication with services like Gmail
    /// and Outlook.com.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - accessToken: The OAuth 2.0 access token.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails.
    public func authenticateXoauth2(user: String, accessToken: String) async throws -> Pop3Response? {
        let response = try await session.authenticateXoauth2(user: user, accessToken: accessToken)
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
        return response
    }

    /// Authenticates using SASL with an OAuth access token.
    ///
    /// This method allows OAuth authentication with automatic mechanism selection.
    ///
    /// - Parameters:
    ///   - user: The username or email address.
    ///   - accessToken: The OAuth 2.0 access token.
    ///   - capabilities: Optional server capabilities.
    ///   - mechanisms: Optional list of allowed mechanisms.
    /// - Returns: The server's response to the AUTH command.
    /// - Throws: An error if authentication fails.
    public func authenticateSasl(
        user: String,
        accessToken: String,
        capabilities: Pop3Capabilities? = nil,
        mechanisms: [String]? = nil
    ) async throws -> Pop3Response? {
        let response = try await session.authenticateSasl(
            user: user,
            accessToken: accessToken,
            capabilities: capabilities,
            mechanisms: mechanisms
        )
        await inbox.attachStore(self)
        _ = try await inbox.open(.readOnly)
        return response
    }

    /// Gets a folder by its path.
    ///
    /// Since POP3 only supports the INBOX folder, this method only succeeds
    /// when the path is "INBOX" (case-insensitive).
    ///
    /// - Parameter path: The folder path (must be "INBOX").
    /// - Returns: The INBOX folder.
    /// - Throws: ``Pop3FolderError/unsupportedFolder`` if the path is not "INBOX".
    public func getFolder(_ path: String) async throws -> AsyncPop3Folder {
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
    public func getFolders(reference: String, pattern: String, subscribedOnly: Bool = false) async throws -> [AsyncPop3Folder] {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "*" || trimmed == "%" || trimmed.caseInsensitiveCompare("INBOX") == .orderedSame {
            return [inbox]
        }
        return []
    }

    /// Opens the INBOX folder.
    ///
    /// - Parameter access: The access mode (must be `.readOnly` for POP3).
    /// - Returns: The opened INBOX folder.
    /// - Throws: ``Pop3FolderError/unsupportedAccess`` if access is not `.readOnly`.
    public func openInbox(access: FolderAccess = .readOnly) async throws -> AsyncPop3Folder {
        await inbox.attachStore(self)
        _ = try await inbox.open(access)
        return inbox
    }

    /// Sends a NOOP command to keep the connection alive.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func noop() async throws -> Pop3Response? {
        try await session.noop()
    }

    /// Resets the session state, undeleting any messages marked for deletion.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func rset() async throws -> Pop3Response? {
        try await session.rset()
    }

    /// Marks a message for deletion.
    ///
    /// The message is not actually deleted until the session ends with QUIT.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func dele(_ index: Int) async throws -> Pop3Response? {
        try await session.dele(index)
    }

    /// Gets the highest message number accessed in this session.
    ///
    /// - Returns: The highest accessed message number.
    /// - Throws: An error if the command fails or is not supported.
    public func last() async throws -> Int {
        try await session.last()
    }

    private func requireSelectedFolder() throws -> AsyncPop3Folder {
        guard let folder = selectedFolderStorage else {
            throw Pop3MailStoreError.noSelectedFolder
        }
        return folder
    }

    /// Gets the message count and total size of the mailbox.
    ///
    /// - Returns: A ``Pop3StatResponse`` containing the count and size.
    /// - Throws: An error if no folder is selected or the command fails.
    public func stat() async throws -> Pop3StatResponse? {
        try await requireSelectedFolder().stat()
    }

    /// Gets a list of all messages with their sizes.
    ///
    /// - Returns: An array of ``Pop3ListItem`` containing message indices and sizes.
    /// - Throws: An error if no folder is selected or the command fails.
    public func list() async throws -> [Pop3ListItem] {
        try await requireSelectedFolder().list()
    }

    /// Gets the size of a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3ListItem`` containing the message index and size.
    /// - Throws: An error if no folder is selected or the command fails.
    public func list(_ index: Int) async throws -> Pop3ListItem {
        try await requireSelectedFolder().list(index)
    }

    /// Gets the unique identifiers for all messages.
    ///
    /// - Returns: An array of ``Pop3UidlItem`` containing message indices and UIDs.
    /// - Throws: An error if no folder is selected or the command fails.
    public func uidl() async throws -> [Pop3UidlItem] {
        try await requireSelectedFolder().uidl()
    }

    /// Gets the unique identifier for a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3UidlItem`` containing the message index and UID.
    /// - Throws: An error if no folder is selected or the command fails.
    public func uidl(_ index: Int) async throws -> Pop3UidlItem {
        try await requireSelectedFolder().uidl(index)
    }

    /// Retrieves a message as an array of lines.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as an array of strings.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retr(_ index: Int) async throws -> [String] {
        try await requireSelectedFolder().retr(index)
    }

    /// Retrieves a message as structured data.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3MessageData`` containing the response and message bytes.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retrData(_ index: Int) async throws -> Pop3MessageData {
        try await requireSelectedFolder().retrData(index)
    }

    /// Retrieves and parses a message as a MIME message.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - options: Parser options for controlling MIME parsing behavior.
    /// - Returns: The parsed ``MimeMessage``.
    /// - Throws: An error if no folder is selected, the command fails, or parsing fails.
    public func message(_ index: Int, options: ParserOptions = .default) async throws -> MimeMessage {
        try await requireSelectedFolder().message(index, options: options)
    }

    /// Retrieves a message as raw bytes.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as a byte array.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retrRaw(_ index: Int) async throws -> [UInt8] {
        try await requireSelectedFolder().retrRaw(index)
    }

    /// Retrieves a message in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - sink: An async closure called with each chunk of message data.
    /// - Throws: An error if no folder is selected or the command fails.
    public func retrStream(
        _ index: Int,
        sink: @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        try await requireSelectedFolder().retrStream(index, sink: sink)
    }

    /// Retrieves message headers and the first few lines of the body.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The message headers and body lines as an array of strings.
    /// - Throws: An error if no folder is selected or the command fails.
    public func top(_ index: Int, lines: Int) async throws -> [String] {
        try await requireSelectedFolder().top(index, lines: lines)
    }

    /// Retrieves message headers and body preview as structured data.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: A ``Pop3MessageData`` containing the response and data.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topData(_ index: Int, lines: Int) async throws -> Pop3MessageData {
        try await requireSelectedFolder().topData(index, lines: lines)
    }

    /// Retrieves and parses message headers.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The parsed ``HeaderList``.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topHeaders(_ index: Int, lines: Int) async throws -> HeaderList {
        try await requireSelectedFolder().topHeaders(index, lines: lines)
    }

    /// Retrieves message headers and body preview as raw bytes.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The data as a byte array.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topRaw(_ index: Int, lines: Int) async throws -> [UInt8] {
        try await requireSelectedFolder().topRaw(index, lines: lines)
    }

    /// Retrieves message headers and body preview in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    ///   - sink: An async closure called with each chunk of data.
    /// - Throws: An error if no folder is selected or the command fails.
    public func topStream(
        _ index: Int,
        lines: Int,
        sink: @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        try await requireSelectedFolder().topStream(index, lines: lines, sink: sink)
    }

    internal func updateSelectedFolder(_ folder: AsyncPop3Folder?, access: FolderAccess?) {
        selectedFolderStorage = folder
        selectedAccessStorage = access
    }
}

/// Represents the async POP3 INBOX folder.
///
/// POP3 only supports a single folder called INBOX where all messages are stored.
/// This actor provides async methods for listing, retrieving, and deleting messages.
///
/// ## Overview
///
/// Unlike IMAP, POP3 has no concept of multiple folders or hierarchical
/// organization. All operations are performed on the INBOX, and the only
/// access mode supported is read-only.
///
/// ## Thread Safety
///
/// This class is implemented as an actor, providing inherent thread safety
/// for concurrent access within Swift's structured concurrency model.
///
/// ## See Also
///
/// - ``AsyncPop3MailStore`` for the parent mail store
/// - ``Pop3Folder`` for synchronous operations
@available(macOS 10.15, iOS 13.0, *)
public actor AsyncPop3Folder: AsyncMailFolder {
    /// The full path name of this folder.
    ///
    /// For POP3, this is always "INBOX".
    public nonisolated let fullName: String = "INBOX"

    /// The display name of this folder.
    ///
    /// For POP3, this is always "INBOX".
    public nonisolated let name: String = "INBOX"

    private let session: AsyncPop3Session
    private weak var store: AsyncPop3MailStore?
    private var access: FolderAccess?

    /// Initializes a new async POP3 folder.
    ///
    /// - Parameters:
    ///   - session: The async POP3 session to use for commands.
    ///   - store: The parent mail store (weak reference to avoid retain cycles).
    public init(session: AsyncPop3Session, store: AsyncPop3MailStore?) {
        self.session = session
        self.store = store
    }

    internal func attachStore(_ store: AsyncPop3MailStore) {
        self.store = store
    }

    /// Whether the folder is currently open.
    public var isOpen: Bool {
        access != nil
    }

    /// Opens the folder with the specified access mode.
    ///
    /// POP3 only supports read-only access to the INBOX.
    ///
    /// - Parameter access: The access mode (must be `.readOnly`).
    /// - Returns: `nil` (POP3 has no SELECT response).
    /// - Throws: ``Pop3FolderError/unsupportedAccess`` if access is not `.readOnly`.
    public func open(_ access: FolderAccess) async throws -> Pop3Response? {
        guard access == .readOnly else {
            throw Pop3FolderError.unsupportedAccess
        }
        self.access = access
        if let store {
            await store.updateSelectedFolder(self, access: access)
        }
        return nil
    }

    /// Closes the folder.
    public func close() async {
        access = nil
        if let store {
            await store.updateSelectedFolder(nil, access: nil)
        }
    }

    /// Sends a NOOP command to keep the connection alive.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func noop() async throws -> Pop3Response? {
        try await session.noop()
    }

    /// Resets the session state, undeleting any messages marked for deletion.
    ///
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func rset() async throws -> Pop3Response? {
        try await session.rset()
    }

    /// Marks a message for deletion.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The server's response.
    /// - Throws: An error if the command fails.
    public func dele(_ index: Int) async throws -> Pop3Response? {
        try await session.dele(index)
    }

    /// Gets the highest message number accessed in this session.
    ///
    /// - Returns: The highest accessed message number.
    /// - Throws: An error if the command fails or is not supported.
    public func last() async throws -> Int {
        try await session.last()
    }

    /// Gets the message count and total size of the mailbox.
    ///
    /// - Returns: A ``Pop3StatResponse`` containing the count and size.
    /// - Throws: An error if the command fails.
    public func stat() async throws -> Pop3StatResponse? {
        try await session.stat()
    }

    /// Gets a list of all messages with their sizes.
    ///
    /// - Returns: An array of ``Pop3ListItem`` containing message indices and sizes.
    /// - Throws: An error if the command fails.
    public func list() async throws -> [Pop3ListItem] {
        try await session.list()
    }

    /// Gets the size of a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3ListItem`` containing the message index and size.
    /// - Throws: An error if the command fails.
    public func list(_ index: Int) async throws -> Pop3ListItem {
        try await session.list(index)
    }

    /// Gets the unique identifiers for all messages.
    ///
    /// - Returns: An array of ``Pop3UidlItem`` containing message indices and UIDs.
    /// - Throws: An error if the command fails.
    public func uidl() async throws -> [Pop3UidlItem] {
        try await session.uidl()
    }

    /// Gets the unique identifier for a specific message.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3UidlItem`` containing the message index and UID.
    /// - Throws: An error if the command fails.
    public func uidl(_ index: Int) async throws -> Pop3UidlItem {
        try await session.uidl(index)
    }

    /// Retrieves a message as an array of lines.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as an array of strings.
    /// - Throws: An error if the command fails.
    public func retr(_ index: Int) async throws -> [String] {
        try await session.retr(index)
    }

    /// Retrieves a message as structured data.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: A ``Pop3MessageData`` containing the response and message bytes.
    /// - Throws: An error if the command fails.
    public func retrData(_ index: Int) async throws -> Pop3MessageData {
        try await session.retrData(index)
    }

    /// Retrieves and parses a message as a MIME message.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - options: Parser options for controlling MIME parsing behavior.
    /// - Returns: The parsed ``MimeMessage``.
    /// - Throws: An error if the command fails or parsing fails.
    public func message(_ index: Int, options: ParserOptions = .default) async throws -> MimeMessage {
        try await retrData(index).message(options: options)
    }

    /// Retrieves a message as raw bytes.
    ///
    /// - Parameter index: The 1-based message index.
    /// - Returns: The message content as a byte array.
    /// - Throws: An error if the command fails.
    public func retrRaw(_ index: Int) async throws -> [UInt8] {
        try await session.retrRaw(index)
    }

    /// Retrieves a message in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - sink: An async closure called with each chunk of message data.
    /// - Throws: An error if the command fails.
    public func retrStream(
        _ index: Int,
        sink: @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        try await session.retrStream(index, sink: sink)
    }

    /// Retrieves message headers and the first few lines of the body.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The message headers and body lines as an array of strings.
    /// - Throws: An error if the command fails.
    public func top(_ index: Int, lines: Int) async throws -> [String] {
        try await session.top(index, lines: lines)
    }

    /// Retrieves message headers and body preview as structured data.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: A ``Pop3MessageData`` containing the response and data.
    /// - Throws: An error if the command fails.
    public func topData(_ index: Int, lines: Int) async throws -> Pop3MessageData {
        try await session.topData(index, lines: lines)
    }

    /// Retrieves and parses message headers.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The parsed ``HeaderList``.
    /// - Throws: An error if the command fails.
    public func topHeaders(_ index: Int, lines: Int) async throws -> HeaderList {
        try await topData(index, lines: lines).parseHeaders()
    }

    /// Retrieves message headers and body preview as raw bytes.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    /// - Returns: The data as a byte array.
    /// - Throws: An error if the command fails.
    public func topRaw(_ index: Int, lines: Int) async throws -> [UInt8] {
        try await session.topRaw(index, lines: lines)
    }

    /// Retrieves message headers and body preview in streaming fashion.
    ///
    /// - Parameters:
    ///   - index: The 1-based message index.
    ///   - lines: The number of body lines to retrieve.
    ///   - sink: An async closure called with each chunk of data.
    /// - Throws: An error if the command fails.
    public func topStream(
        _ index: Int,
        lines: Int,
        sink: @Sendable ([UInt8]) async throws -> Void
    ) async throws {
        try await session.topStream(index, lines: lines, sink: sink)
    }
}
