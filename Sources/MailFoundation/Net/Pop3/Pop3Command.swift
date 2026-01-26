//
// Pop3Command.swift
//
// Basic POP3 command model.
//

/// Represents a POP3 command ready to be sent to the server.
///
/// A POP3 command consists of a keyword (like USER, PASS, STAT) and optional
/// arguments. This struct handles serialization to the wire format.
///
/// ## Command Format
///
/// POP3 commands follow this format:
/// ```
/// KEYWORD [arguments]\r\n
/// ```
///
/// ## Usage
///
/// For most use cases, use ``Pop3CommandKind`` to create commands:
///
/// ```swift
/// let command = Pop3CommandKind.user("username").command()
/// print(command.serialized)  // "USER username\r\n"
/// ```
///
/// Or create commands directly:
///
/// ```swift
/// let command = Pop3Command(keyword: "NOOP")
/// let retr = Pop3Command(keyword: "RETR", arguments: "1")
/// ```
///
/// ## See Also
///
/// - ``Pop3CommandKind`` for type-safe command construction
/// - ``Pop3Client/send(_:)`` for sending commands
public struct Pop3Command: Sendable {
    /// The command keyword (e.g., "USER", "PASS", "STAT").
    public let keyword: String

    /// Optional arguments for the command.
    public let arguments: String?

    /// Initializes a new POP3 command.
    ///
    /// - Parameters:
    ///   - keyword: The command keyword.
    ///   - arguments: Optional arguments for the command.
    public init(keyword: String, arguments: String? = nil) {
        self.keyword = keyword
        self.arguments = arguments
    }

    /// The command serialized for transmission.
    ///
    /// Returns the command in wire format, terminated with CRLF.
    public var serialized: String {
        if let arguments {
            return "\(keyword) \(arguments)\r\n"
        }
        return "\(keyword)\r\n"
    }
}
