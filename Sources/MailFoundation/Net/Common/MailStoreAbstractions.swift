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
// MailStoreAbstractions.swift
//
// Mail store and folder protocols.
//

// MARK: - MailFolder Protocol

/// A protocol representing a mail folder (mailbox) on a mail server.
///
/// Mail folders organize email messages into hierarchical structures.
/// Common folders include INBOX, Sent, Drafts, and Trash, though servers
/// may support arbitrary folder hierarchies.
///
/// ## Folder Naming
///
/// - ``fullName``: The complete path including parent folders (e.g., "INBOX/Work/Projects")
/// - ``name``: Just the folder's own name (e.g., "Projects")
///
/// ## Conforming Types
///
/// - ``ImapMailFolder`` for IMAP servers
/// - ``Pop3MailFolder`` for POP3 servers (limited folder support)
///
/// - Note: Ported from MailKit's `IMailFolder` interface.
public protocol MailFolder: AnyObject {
    /// The full path name of the folder.
    ///
    /// This includes all parent folder names separated by the folder
    /// delimiter character (typically "/" or ".").
    ///
    /// Example: "INBOX/Work/Projects"
    var fullName: String { get }

    /// The display name of the folder (without parent path).
    ///
    /// This is the last component of the ``fullName`` path.
    ///
    /// Example: For "INBOX/Work/Projects", this would be "Projects"
    var name: String { get }
}

/// An asynchronous version of ``MailFolder`` for use with Swift concurrency.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
public protocol AsyncMailFolder {
    /// The full path name of the folder.
    var fullName: String { get }

    /// The display name of the folder (without parent path).
    var name: String { get }
}

// MARK: - MailStore Protocol

/// A protocol for mail stores that provide access to mail folders and messages.
///
/// `MailStore` extends ``MailService`` with folder access capabilities.
/// It is implemented by protocols that support mailbox access, such as
/// IMAP and POP3.
///
/// ## Folder Operations
///
/// ```swift
/// let store = ImapMailStore(host: "imap.example.com", port: 993)
/// try store.connect()
/// try store.authenticate(user: "user", password: "pass")
///
/// // Get a specific folder
/// let inbox = try store.getFolder("INBOX")
///
/// // List all folders
/// let folders = try store.getFolders(reference: "", pattern: "*", subscribedOnly: false)
/// for folder in folders {
///     print(folder.fullName)
/// }
/// ```
///
/// - Note: Ported from MailKit's `IMailStore` interface.
public protocol MailStore: MailService {
    /// The type of folder used by this mail store.
    associatedtype FolderType: MailFolder

    /// The currently selected (opened) folder, if any.
    ///
    /// This property is set after calling the folder's `open()` method
    /// and is cleared when the folder is closed.
    var selectedFolder: FolderType? { get }

    /// The access mode of the currently selected folder.
    ///
    /// Indicates whether the folder was opened for read-only or
    /// read-write access. Returns `nil` if no folder is selected.
    var selectedAccess: FolderAccess? { get }

    /// Gets a folder by its full path.
    ///
    /// - Parameter path: The full path to the folder (e.g., "INBOX/Work").
    /// - Returns: The folder at the specified path.
    /// - Throws: An error if the folder does not exist or cannot be accessed.
    func getFolder(_ path: String) throws -> FolderType

    /// Lists folders matching the specified pattern.
    ///
    /// This method returns folders that match the given pattern within
    /// the reference namespace.
    ///
    /// - Parameters:
    ///   - reference: The reference namespace (typically "" for root).
    ///   - pattern: The pattern to match ("*" matches all, "%" matches one level).
    ///   - subscribedOnly: If `true`, only return subscribed folders.
    /// - Returns: An array of matching folders.
    /// - Throws: An error if the operation fails.
    ///
    /// - Note: Ported from MailKit's folder listing methods.
    func getFolders(reference: String, pattern: String, subscribedOnly: Bool) throws -> [FolderType]
}

// MARK: - AsyncMailStore Protocol

/// An asynchronous version of ``MailStore`` for use with Swift concurrency.
///
/// `AsyncMailStore` provides the same folder access capabilities as
/// ``MailStore`` but with `async` methods for concurrent Swift code.
///
/// ## Example Usage
///
/// ```swift
/// let store = AsyncImapMailStore(transport: transport)
/// _ = try await store.connect()
/// _ = try await store.authenticate(user: "user", password: "pass")
///
/// let inbox = try await store.getFolder("INBOX")
/// let folders = try await store.getFolders(reference: "", pattern: "*", subscribedOnly: false)
/// ```
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public protocol AsyncMailStore: AsyncMailService {
    /// The type of folder used by this mail store.
    associatedtype FolderType: AsyncMailFolder

    /// The currently selected (opened) folder, if any.
    var selectedFolder: FolderType? { get async }

    /// The access mode of the currently selected folder.
    var selectedAccess: FolderAccess? { get async }

    /// Asynchronously gets a folder by its full path.
    ///
    /// - Parameter path: The full path to the folder.
    /// - Returns: The folder at the specified path.
    /// - Throws: An error if the folder does not exist.
    func getFolder(_ path: String) async throws -> FolderType

    /// Asynchronously lists folders matching the specified pattern.
    ///
    /// - Parameters:
    ///   - reference: The reference namespace.
    ///   - pattern: The pattern to match.
    ///   - subscribedOnly: If `true`, only return subscribed folders.
    /// - Returns: An array of matching folders.
    /// - Throws: An error if the operation fails.
    func getFolders(reference: String, pattern: String, subscribedOnly: Bool) async throws -> [FolderType]
}
