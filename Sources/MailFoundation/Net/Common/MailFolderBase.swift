//
// MailFolderBase.swift
//
// Shared folder base types.
//

// MARK: - Folder Access Mode

/// Represents the access mode for an opened mail folder.
///
/// When opening a folder, you can request either read-only or read-write
/// access. The server may grant read-only access even when read-write
/// is requested if the folder's permissions don't allow modification.
///
/// ## IMAP Considerations
///
/// In IMAP, this corresponds to the SELECT (read-write) vs EXAMINE
/// (read-only) commands.
///
/// - Note: Ported from MailKit's `FolderAccess` enum.
public enum FolderAccess: Sendable, Equatable {
    /// Read-only access to the folder.
    ///
    /// Messages can be read but not modified, moved, or deleted.
    /// New messages cannot be appended to the folder.
    case readOnly

    /// Read-write access to the folder.
    ///
    /// Full access to read, modify, move, delete, and append messages.
    case readWrite
}

// MARK: - MailFolderBase

/// An abstract base class for mail folder implementations.
///
/// `MailFolderBase` provides common functionality for mail folders including
/// name parsing, open state tracking, and delimiter handling.
///
/// ## Folder Names and Paths
///
/// Mail folders have both a full path name and a display name:
/// - ``fullName``: The complete path (e.g., "INBOX/Work/Projects")
/// - ``name``: Just the folder's name (e.g., "Projects")
///
/// The ``delimiter`` character separates path components and varies by server.
///
/// ## Subclassing
///
/// Protocol-specific folder implementations should inherit from this class
/// and add their own message access methods.
///
/// - Note: Ported from MailKit's folder base classes.
open class MailFolderBase: MailFolder {
    /// The full path name of the folder.
    ///
    /// This includes all parent folder names separated by the ``delimiter``.
    public let fullName: String

    /// The display name of the folder (without parent path).
    ///
    /// This is computed from ``fullName`` by extracting the last path component.
    public let name: String

    /// The character that separates folder path components.
    ///
    /// Common delimiters are "/" and ".". This value is provided by the
    /// server and may be `nil` if the folder hierarchy is flat.
    public let delimiter: String?

    /// The current access mode of the folder.
    ///
    /// This is set when the folder is opened and cleared when it is closed.
    /// When `nil`, the folder is not currently open.
    public private(set) var access: FolderAccess?

    /// Indicates whether the folder is currently open.
    ///
    /// A folder must be opened before messages can be accessed.
    public var isOpen: Bool {
        access != nil
    }

    /// Creates a mail folder with the specified path.
    ///
    /// - Parameters:
    ///   - fullName: The complete path to the folder.
    ///   - delimiter: The path delimiter character (optional).
    public init(fullName: String, delimiter: String? = nil) {
        self.fullName = fullName
        self.delimiter = delimiter
        self.name = MailFolderBase.computeName(fullName, delimiter: delimiter)
    }

    /// Updates the folder's open state.
    ///
    /// Call this method when the folder is opened or closed to track
    /// its current access mode.
    ///
    /// - Parameter access: The access mode, or `nil` if the folder is being closed.
    public func updateOpenState(_ access: FolderAccess?) {
        self.access = access
    }

    /// Computes the display name from a full path.
    ///
    /// This utility method extracts the last path component from a
    /// folder's full name.
    ///
    /// - Parameters:
    ///   - fullName: The complete folder path.
    ///   - delimiter: The path delimiter character.
    /// - Returns: The folder's display name.
    public static func computeName(_ fullName: String, delimiter: String?) -> String {
        guard let delimiter, let delimiterChar = delimiter.first else { return fullName }
        return fullName.split(separator: delimiterChar).last.map(String.init) ?? fullName
    }
}

// MARK: - AsyncMailFolderBase

/// An asynchronous actor-based mail folder implementation.
///
/// `AsyncMailFolderBase` provides the same functionality as ``MailFolderBase``
/// but as an actor for safe concurrent access in async code.
///
/// ## Thread Safety
///
/// As an actor, `AsyncMailFolderBase` provides automatic synchronization
/// for its mutable state. The ``fullName``, ``name``, and ``delimiter``
/// properties are marked `nonisolated` since they are immutable.
///
/// - Note: Available on macOS 10.15+ and iOS 13.0+.
@available(macOS 10.15, iOS 13.0, *)
public actor AsyncMailFolderBase: AsyncMailFolder {
    /// The full path name of the folder.
    public nonisolated let fullName: String

    /// The display name of the folder (without parent path).
    public nonisolated let name: String

    /// The character that separates folder path components.
    public nonisolated let delimiter: String?

    /// The current access mode of the folder.
    private var access: FolderAccess?

    /// Creates an async mail folder with the specified path.
    ///
    /// - Parameters:
    ///   - fullName: The complete path to the folder.
    ///   - delimiter: The path delimiter character (optional).
    public init(fullName: String, delimiter: String? = nil) {
        self.fullName = fullName
        self.delimiter = delimiter
        self.name = MailFolderBase.computeName(fullName, delimiter: delimiter)
    }

    /// Indicates whether the folder is currently open.
    public var isOpen: Bool {
        access != nil
    }

    /// Updates the folder's open state.
    ///
    /// - Parameter access: The access mode, or `nil` if closing.
    public func updateOpenState(_ access: FolderAccess?) {
        self.access = access
    }
}
