//
// SmtpCommandError.swift
//
// SMTP command error wrapper (ported from MailKit semantics).
//

import MimeFoundation

/// An error that occurs when an SMTP command fails.
///
/// Unlike protocol-level errors that require reconnection, an `SmtpCommandError`
/// represents a logical error in the SMTP transaction that does not necessarily
/// break the connection. For example, a rejected recipient address or an
/// authentication failure would be represented as an `SmtpCommandError`.
///
/// ## Error Information
///
/// The error provides several pieces of information to help diagnose and handle the failure:
/// - ``errorCode``: A categorized error code for programmatic handling
/// - ``statusCode``: The raw SMTP status code from the server
/// - ``enhancedStatusCode``: The RFC 3463 enhanced status code, if available
/// - ``message``: The human-readable error message from the server
/// - ``mailbox``: The mailbox address that caused the error, if applicable
///
/// ## Example
/// ```swift
/// do {
///     try transport.send(message)
/// } catch let error as SmtpCommandError {
///     switch error.errorCode {
///     case .recipientNotAccepted:
///         print("Recipient rejected: \(error.mailbox?.address ?? "unknown")")
///     case .senderNotAccepted:
///         print("Sender rejected")
///     case .authenticationFailed:
///         print("Authentication failed: \(error.message)")
///     default:
///         print("SMTP error \(error.statusCode.rawValue): \(error.message)")
///     }
/// }
/// ```
///
/// ## See Also
/// - ``SmtpErrorCode``
/// - ``SmtpStatusCode``
/// - ``SmtpEnhancedStatusCode``
public struct SmtpCommandError: Error, Sendable, Equatable {
    /// The categorized error code for programmatic handling.
    ///
    /// Use this to determine the general category of the error without
    /// parsing the raw status code or message text.
    public let errorCode: SmtpErrorCode

    /// The SMTP status code returned by the server.
    ///
    /// This is the raw three-digit status code from the SMTP response.
    public let statusCode: SmtpStatusCode

    /// The raw mailbox address string that caused the error, if applicable.
    ///
    /// This is set when the error is related to a specific email address,
    /// such as a rejected sender or recipient.
    public let mailboxAddress: String?

    /// The parsed mailbox address that caused the error, if applicable.
    ///
    /// This is a parsed version of ``mailboxAddress`` as a ``MailboxAddress``.
    /// May be `nil` if the address could not be parsed or was not provided.
    public let mailbox: MailboxAddress?

    /// The error message text from the server.
    ///
    /// This is the human-readable text from all response lines,
    /// joined with spaces.
    public let message: String

    /// The individual response lines from the server.
    ///
    /// For multi-line error responses, each line is preserved separately.
    public let responseLines: [String]

    /// The RFC 3463 enhanced status code, if available.
    ///
    /// Enhanced status codes provide more detailed information about the
    /// error when the server supports the ENHANCEDSTATUSCODES extension.
    public let enhancedStatusCode: SmtpEnhancedStatusCode?

    /// Creates a new SMTP command error from a server response.
    ///
    /// - Parameters:
    ///   - errorCode: The categorized error code.
    ///   - response: The SMTP response that triggered the error.
    ///   - mailboxAddress: The mailbox address that caused the error, if applicable.
    public init(
        errorCode: SmtpErrorCode,
        response: SmtpResponse,
        mailboxAddress: String? = nil
    ) {
        self.errorCode = errorCode
        self.statusCode = SmtpStatusCode(rawValue: response.code)
        self.mailboxAddress = mailboxAddress
        self.mailbox = mailboxAddress.flatMap { try? MailboxAddress(parsing: $0) }
        self.message = response.lines.joined(separator: " ")
        self.responseLines = response.lines
        self.enhancedStatusCode = response.enhancedStatusCode
    }
}
