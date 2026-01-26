//
// Pop3CommandError.swift
//
// POP3 command error wrapper (ported from MailKit semantics).
//

/// An error that occurred when executing a POP3 command.
///
/// This error is thrown when a POP3 command fails with an `-ERR` response
/// from the server. It captures both the server's error message and any
/// additional context.
///
/// ## Usage
///
/// ```swift
/// do {
///     try store.retr(999)
/// } catch let error as Pop3CommandError {
///     print("Command failed: \(error.message)")
///     print("Server said: \(error.statusText)")
/// }
/// ```
///
/// ## Common Error Scenarios
///
/// - Invalid message number: "no such message"
/// - Authentication failure: "authentication failed"
/// - Mailbox locked: "maildrop already locked"
/// - Connection timeout: "connection timed out"
///
/// ## See Also
///
/// - ``Pop3MailStoreError`` for store-level errors
/// - ``Pop3Response`` for raw server responses
public struct Pop3CommandError: Error, Sendable, Equatable {
    /// A human-readable description of the error.
    ///
    /// This may be the same as `statusText` or may include additional context.
    public let message: String

    /// The raw status text from the server's `-ERR` response.
    public let statusText: String

    /// Initializes a new command error.
    ///
    /// - Parameters:
    ///   - statusText: The raw status text from the server.
    ///   - message: An optional human-readable message. Defaults to the status text.
    public init(statusText: String, message: String? = nil) {
        self.statusText = statusText
        self.message = message ?? statusText
    }
}
