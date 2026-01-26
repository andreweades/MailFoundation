//
// SmtpCommand.swift
//
// Basic SMTP command model.
//

/// Represents an SMTP command to be sent to an SMTP server.
///
/// SMTP commands consist of a keyword (verb) and optional arguments,
/// terminated by CRLF. This type provides a structured way to create
/// and serialize SMTP commands.
///
/// ## Example
/// ```swift
/// // Create a simple command
/// let noop = SmtpCommand(keyword: "NOOP")
///
/// // Create a command with arguments
/// let ehlo = SmtpCommand(keyword: "EHLO", arguments: "example.com")
///
/// // Get the serialized form ready to send
/// let bytes = Array(ehlo.serialized.utf8)  // "EHLO example.com\r\n"
/// ```
///
/// For common SMTP commands, consider using ``SmtpCommandKind`` which provides
/// type-safe command construction.
///
/// ## See Also
/// - ``SmtpCommandKind``
/// - ``SmtpResponse``
public struct SmtpCommand: Sendable {
    /// The command keyword (verb).
    ///
    /// Common SMTP keywords include: HELO, EHLO, MAIL, RCPT, DATA, QUIT, RSET, NOOP, VRFY, EXPN, HELP.
    public let keyword: String

    /// The command arguments, if any.
    ///
    /// For example, for `EHLO example.com`, the arguments would be `"example.com"`.
    /// For `MAIL FROM:<user@example.com>`, the arguments would be `"FROM:<user@example.com>"`.
    public let arguments: String?

    /// Creates a new SMTP command.
    ///
    /// - Parameters:
    ///   - keyword: The command keyword (e.g., "EHLO", "MAIL", "RCPT").
    ///   - arguments: Optional arguments for the command.
    public init(keyword: String, arguments: String? = nil) {
        self.keyword = keyword
        self.arguments = arguments
    }

    /// The serialized command string ready to be sent to the server.
    ///
    /// The format is `"KEYWORD ARGUMENTS\r\n"` if arguments are present,
    /// or `"KEYWORD\r\n"` if there are no arguments.
    public var serialized: String {
        if let arguments {
            return "\(keyword) \(arguments)\r\n"
        }
        return "\(keyword)\r\n"
    }
}
