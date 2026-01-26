//
// ImapMailStoreError.swift
//
// Store-level IMAP errors.
//

/// Errors that can occur when using an IMAP mail store.
///
/// These errors represent high-level problems with mail store operations,
/// as opposed to protocol-level IMAP errors.
///
/// ## See Also
///
/// - ``ImapMailStore``
/// - ``AsyncImapMailStore``
public enum ImapMailStoreError: Error, Sendable, Equatable {
    /// No folder is currently selected.
    ///
    /// This error occurs when attempting an operation that requires a selected
    /// folder (such as SEARCH, FETCH, or STORE) without first opening a folder
    /// using `openFolder(_:access:)` or `openInbox(access:)`.
    ///
    /// ## Resolution
    ///
    /// ```swift
    /// // Open a folder before performing message operations
    /// try store.openInbox(access: .readOnly)
    /// let results = try store.search(.all) // Now this works
    /// ```
    case noSelectedFolder
}
