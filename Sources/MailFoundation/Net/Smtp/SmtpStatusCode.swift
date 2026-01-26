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
// SmtpStatusCode.swift
//
// SMTP status code values (ported from MailKit).
//

/// Represents possible SMTP status codes returned by an SMTP server.
///
/// SMTP status codes are three-digit numbers that indicate the result of an SMTP command.
/// The first digit indicates the general category of the response:
/// - 2xx: Positive completion reply (the requested action has been successfully completed)
/// - 3xx: Positive intermediate reply (the command was accepted, but more input is needed)
/// - 4xx: Transient negative completion reply (temporary failure, retry later)
/// - 5xx: Permanent negative completion reply (permanent failure, do not retry)
///
/// ## Example
/// ```swift
/// let response = try transport.ehlo(domain: "example.com")
/// if response.statusCode == .ok {
///     print("EHLO succeeded")
/// }
/// ```
///
/// ## See Also
/// - ``SmtpResponse``
/// - ``SmtpEnhancedStatusCode``
public struct SmtpStatusCode: RawRepresentable, Sendable, Equatable, Hashable, ExpressibleByIntegerLiteral {
    /// The underlying integer value of the status code.
    public let rawValue: Int

    /// Creates a new SMTP status code from an integer value.
    ///
    /// - Parameter rawValue: The three-digit SMTP status code.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Creates a new SMTP status code from an integer literal.
    ///
    /// - Parameter value: The three-digit SMTP status code.
    public init(integerLiteral value: Int) {
        self.rawValue = value
    }

    /// The "system status" status code (211).
    ///
    /// Indicates system status or system help reply.
    public static let systemStatus: SmtpStatusCode = 211

    /// The "help message" status code (214).
    ///
    /// Contains help information about the server.
    public static let helpMessage: SmtpStatusCode = 214

    /// The "service ready" status code (220).
    ///
    /// Indicates the SMTP server is ready and waiting for commands.
    /// This is the greeting response sent when a client first connects.
    public static let serviceReady: SmtpStatusCode = 220

    /// The "service closing transmission channel" status code (221).
    ///
    /// Indicates the server is closing the connection, typically in response to a QUIT command.
    public static let serviceClosingTransmissionChannel: SmtpStatusCode = 221

    /// The "authentication successful" status code (235).
    ///
    /// Indicates that authentication was completed successfully.
    public static let authenticationSuccessful: SmtpStatusCode = 235

    /// The general purpose "OK" status code (250).
    ///
    /// Indicates the requested action was completed successfully.
    /// This is the most common success response.
    public static let ok: SmtpStatusCode = 250

    /// The "user not local; will forward" status code (251).
    ///
    /// Indicates the recipient is not local but the server will accept
    /// the message and attempt to forward it.
    public static let userNotLocalWillForward: SmtpStatusCode = 251

    /// The "cannot verify user; will attempt delivery" status code (252).
    ///
    /// Indicates the server cannot verify the user but will accept
    /// the message and attempt delivery anyway.
    public static let cannotVerifyUserWillAttemptDelivery: SmtpStatusCode = 252

    /// The "authentication challenge" status code (334).
    ///
    /// Indicates the server is issuing a challenge during SASL authentication.
    /// The response text contains the base64-encoded challenge data.
    public static let authenticationChallenge: SmtpStatusCode = 334

    /// The "start mail input" status code (354).
    ///
    /// Indicates the server is ready to receive the message content
    /// after a DATA command. The client should send the message body
    /// followed by a line containing only a period.
    public static let startMailInput: SmtpStatusCode = 354

    /// The "service not available" status code (421).
    ///
    /// Indicates a transient failure where the service is temporarily
    /// unavailable. The client should try again later.
    public static let serviceNotAvailable: SmtpStatusCode = 421

    /// The "password transition needed" status code (432).
    ///
    /// Indicates that a password transition is required before authentication can proceed.
    public static let passwordTransitionNeeded: SmtpStatusCode = 432

    /// The "mailbox busy" status code (450).
    ///
    /// Indicates the requested action was not taken because the mailbox
    /// was temporarily unavailable (e.g., busy or temporarily blocked).
    public static let mailboxBusy: SmtpStatusCode = 450

    /// The "error in processing" status code (451).
    ///
    /// Indicates the requested action was aborted due to a local error
    /// in processing. The client should try again later.
    public static let errorInProcessing: SmtpStatusCode = 451

    /// The "insufficient storage" status code (452).
    ///
    /// Indicates the requested action was not taken due to insufficient
    /// system storage. This is typically a transient condition.
    public static let insufficientStorage: SmtpStatusCode = 452

    /// The "temporary authentication failure" status code (454).
    ///
    /// Indicates a temporary failure during authentication.
    /// The client may try again later.
    public static let temporaryAuthenticationFailure: SmtpStatusCode = 454

    /// The "command unrecognized" status code (500).
    ///
    /// Indicates the server did not recognize the command.
    /// This may occur if the command is misspelled or not supported.
    public static let commandUnrecognized: SmtpStatusCode = 500

    /// The "syntax error" status code (501).
    ///
    /// Indicates a syntax error in the command parameters or arguments.
    public static let syntaxError: SmtpStatusCode = 501

    /// The "command not implemented" status code (502).
    ///
    /// Indicates the command is recognized but not implemented by this server.
    public static let commandNotImplemented: SmtpStatusCode = 502

    /// The "bad command sequence" status code (503).
    ///
    /// Indicates the commands were issued in an invalid sequence.
    /// For example, sending DATA before MAIL FROM and RCPT TO.
    public static let badCommandSequence: SmtpStatusCode = 503

    /// The "command parameter not implemented" status code (504).
    ///
    /// Indicates a command parameter is not implemented by the server.
    public static let commandParameterNotImplemented: SmtpStatusCode = 504

    /// The "authentication required" status code (530).
    ///
    /// Indicates that authentication is required before the requested
    /// action can be performed.
    public static let authenticationRequired: SmtpStatusCode = 530

    /// The "authentication mechanism too weak" status code (534).
    ///
    /// Indicates the selected authentication mechanism is too weak
    /// and the server requires a stronger mechanism.
    public static let authenticationMechanismTooWeak: SmtpStatusCode = 534

    /// The "authentication invalid credentials" status code (535).
    ///
    /// Indicates that authentication failed due to invalid credentials.
    public static let authenticationInvalidCredentials: SmtpStatusCode = 535

    /// The "encryption required for authentication mechanism" status code (538).
    ///
    /// Indicates that the requested authentication mechanism requires
    /// an encrypted connection (TLS/SSL).
    public static let encryptionRequiredForAuthenticationMechanism: SmtpStatusCode = 538

    /// The "mailbox unavailable" status code (550).
    ///
    /// Indicates the requested action was not taken because the mailbox
    /// is unavailable. This is a permanent failure.
    public static let mailboxUnavailable: SmtpStatusCode = 550

    /// The "user not local; try alternate path" status code (551).
    ///
    /// Indicates the user is not local and the server provides
    /// information about where to forward the message.
    public static let userNotLocalTryAlternatePath: SmtpStatusCode = 551

    /// The "exceeded storage allocation" status code (552).
    ///
    /// Indicates the requested action was aborted because the user's
    /// mailbox has exceeded its storage quota.
    public static let exceededStorageAllocation: SmtpStatusCode = 552

    /// The "mailbox name not allowed" status code (553).
    ///
    /// Indicates the requested action was not taken because the mailbox
    /// name is not allowed (e.g., mailbox syntax incorrect).
    public static let mailboxNameNotAllowed: SmtpStatusCode = 553

    /// The "transaction failed" status code (554).
    ///
    /// Indicates the transaction failed. This is a general permanent
    /// failure response.
    public static let transactionFailed: SmtpStatusCode = 554

    /// The "MAIL FROM/RCPT TO parameters not recognized or not implemented" status code (555).
    ///
    /// Indicates that parameters in the MAIL FROM or RCPT TO command
    /// were not recognized or are not implemented.
    public static let mailFromOrRcptToParametersNotRecognizedOrNotImplemented: SmtpStatusCode = 555
}
