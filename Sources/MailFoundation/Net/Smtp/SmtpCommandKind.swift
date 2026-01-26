//
// SmtpCommandKind.swift
//
// SMTP command definitions.
//

/// Represents the types of SMTP commands that can be sent to an SMTP server.
///
/// This enumeration provides type-safe construction of SMTP commands with their
/// required parameters. Use the ``command()`` method to get a serializable
/// ``SmtpCommand`` instance.
///
/// ## Example
/// ```swift
/// // Create an EHLO command
/// let ehloKind = SmtpCommandKind.ehlo("example.com")
/// let ehloCommand = ehloKind.command()
///
/// // Create a MAIL FROM command with parameters
/// var params = SmtpMailFromParameters()
/// params.size = 1024
/// let mailKind = SmtpCommandKind.mailFromParameters("sender@example.com", params)
/// ```
///
/// ## See Also
/// - ``SmtpCommand``
/// - ``SmtpMailFromParameters``
/// - ``SmtpRcptToParameters``
public enum SmtpCommandKind: Sendable {
    /// The HELO command for basic SMTP greeting.
    ///
    /// Used to identify the client to the server. EHLO is preferred for modern servers.
    /// - Parameter domain: The client's domain name or IP address.
    case helo(String)

    /// The EHLO command for extended SMTP greeting.
    ///
    /// Used to identify the client and request the server's capability list.
    /// This is the preferred greeting command for servers supporting ESMTP.
    /// - Parameter domain: The client's domain name or IP address.
    case ehlo(String)

    /// The MAIL FROM command to specify the envelope sender.
    ///
    /// Initiates a mail transaction with the specified sender address.
    /// - Parameter address: The sender's email address.
    case mailFrom(String)

    /// The MAIL FROM command with additional parameters.
    ///
    /// Initiates a mail transaction with the specified sender and ESMTP parameters
    /// such as SIZE, BODY, SMTPUTF8, or DSN options.
    /// - Parameters:
    ///   - address: The sender's email address.
    ///   - parameters: Additional ESMTP parameters for the command.
    case mailFromParameters(String, SmtpMailFromParameters)

    /// The RCPT TO command to specify a recipient.
    ///
    /// Adds a recipient to the current mail transaction.
    /// - Parameter address: The recipient's email address.
    case rcptTo(String)

    /// The RCPT TO command with additional parameters.
    ///
    /// Adds a recipient with ESMTP parameters such as DSN notification options.
    /// - Parameters:
    ///   - address: The recipient's email address.
    ///   - parameters: Additional ESMTP parameters for the command.
    case rcptToParameters(String, SmtpRcptToParameters)

    /// The DATA command to begin message content transmission.
    ///
    /// After receiving a 354 response, the client sends the message content
    /// followed by a line containing only a period (.) to end the data.
    case data

    /// The BDAT command for chunked message transmission.
    ///
    /// Part of the CHUNKING extension (RFC 3030). Allows sending message data
    /// in chunks without dot-stuffing.
    /// - Parameters:
    ///   - size: The size of the chunk in bytes.
    ///   - last: Whether this is the last chunk.
    case bdat(Int, last: Bool)

    /// The RSET command to reset the mail transaction.
    ///
    /// Aborts the current mail transaction and clears all buffers and state.
    case rset

    /// The NOOP command (no operation).
    ///
    /// Does nothing but can be used to keep the connection alive or test connectivity.
    case noop

    /// The QUIT command to close the connection.
    ///
    /// Requests the server to close the connection gracefully.
    case quit

    /// The STARTTLS command to upgrade to a TLS connection.
    ///
    /// Part of the STARTTLS extension (RFC 3207). After a successful response,
    /// the client should begin TLS negotiation.
    case starttls

    /// The VRFY command to verify a mailbox.
    ///
    /// Asks the server to verify that a mailbox exists. Many servers disable
    /// this command for security reasons.
    /// - Parameter argument: The mailbox or username to verify.
    case vrfy(String)

    /// The EXPN command to expand a mailing list.
    ///
    /// Asks the server to expand a mailing list. Many servers disable
    /// this command for security reasons.
    /// - Parameter argument: The mailing list to expand.
    case expn(String)

    /// The HELP command to request help information.
    ///
    /// Asks the server for help about a specific command or general help.
    /// - Parameter argument: Optional command name to get help for.
    case help(String?)

    /// The ETRN command to request mail queue run.
    ///
    /// Part of the ETRN extension. Requests the server to start sending
    /// queued mail for a specified domain.
    /// - Parameter argument: The domain to start queue processing for.
    case etrn(String)

    /// The AUTH command to begin SASL authentication.
    ///
    /// Initiates authentication using the specified SASL mechanism.
    /// - Parameters:
    ///   - mechanism: The SASL mechanism name (e.g., "PLAIN", "LOGIN", "XOAUTH2").
    ///   - initialResponse: Optional initial response data (base64-encoded).
    case auth(String, initialResponse: String?)

    /// Converts this command kind into a serializable ``SmtpCommand``.
    ///
    /// - Returns: An ``SmtpCommand`` ready to be sent to the server.
    public func command() -> SmtpCommand {
        switch self {
        case let .helo(domain):
            return SmtpCommand(keyword: "HELO", arguments: domain)
        case let .ehlo(domain):
            return SmtpCommand(keyword: "EHLO", arguments: domain)
        case let .mailFrom(address):
            return SmtpCommand(keyword: "MAIL", arguments: "FROM:<\(address)>")
        case let .mailFromParameters(address, parameters):
            let args = parameters.arguments()
            if args.isEmpty {
                return SmtpCommand(keyword: "MAIL", arguments: "FROM:<\(address)>")
            }
            return SmtpCommand(keyword: "MAIL", arguments: "FROM:<\(address)> \(args.joined(separator: " "))")
        case let .rcptTo(address):
            return SmtpCommand(keyword: "RCPT", arguments: "TO:<\(address)>")
        case let .rcptToParameters(address, parameters):
            let args = parameters.arguments()
            if args.isEmpty {
                return SmtpCommand(keyword: "RCPT", arguments: "TO:<\(address)>")
            }
            return SmtpCommand(keyword: "RCPT", arguments: "TO:<\(address)> \(args.joined(separator: " "))")
        case .data:
            return SmtpCommand(keyword: "DATA")
        case let .bdat(size, last):
            if last {
                return SmtpCommand(keyword: "BDAT", arguments: "\(size) LAST")
            }
            return SmtpCommand(keyword: "BDAT", arguments: "\(size)")
        case .rset:
            return SmtpCommand(keyword: "RSET")
        case .noop:
            return SmtpCommand(keyword: "NOOP")
        case .quit:
            return SmtpCommand(keyword: "QUIT")
        case .starttls:
            return SmtpCommand(keyword: "STARTTLS")
        case let .vrfy(argument):
            return SmtpCommand(keyword: "VRFY", arguments: argument)
        case let .expn(argument):
            return SmtpCommand(keyword: "EXPN", arguments: argument)
        case let .help(argument):
            if let argument {
                return SmtpCommand(keyword: "HELP", arguments: argument)
            }
            return SmtpCommand(keyword: "HELP")
        case let .etrn(argument):
            return SmtpCommand(keyword: "ETRN", arguments: argument)
        case let .auth(mechanism, initialResponse):
            if let response = initialResponse {
                return SmtpCommand(keyword: "AUTH", arguments: "\(mechanism) \(response)")
            }
            return SmtpCommand(keyword: "AUTH", arguments: mechanism)
        }
    }
}
