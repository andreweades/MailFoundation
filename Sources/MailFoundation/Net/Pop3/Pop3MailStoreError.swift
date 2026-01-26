//
// Pop3MailStoreError.swift
//
// Store-level POP3 errors.
//

/// Errors that can occur at the mail store level.
///
/// These errors indicate problems with the overall store state rather than
/// individual command failures.
///
/// ## See Also
///
/// - ``Pop3CommandError`` for command-level errors
/// - ``Pop3FolderError`` for folder-level errors
public enum Pop3MailStoreError: Error, Sendable, Equatable {
    /// No folder is currently selected.
    ///
    /// This error is thrown when attempting to perform operations that require
    /// a selected folder (like `stat()`, `list()`, `retr()`) without first
    /// opening the INBOX.
    ///
    /// ## Resolution
    ///
    /// Call ``Pop3MailStore/openInbox(access:)`` or authenticate (which automatically
    /// opens the INBOX) before performing message operations.
    ///
    /// ```swift
    /// // Either authenticate (opens INBOX automatically)
    /// try store.authenticate(user: "user", password: "pass")
    ///
    /// // Or explicitly open the inbox
    /// try store.openInbox()
    ///
    /// // Now operations will work
    /// let stat = try store.stat()
    /// ```
    case noSelectedFolder
}
