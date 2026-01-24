//
// SmtpStatusCode.swift
//
// SMTP status code values (ported from MailKit).
//

public struct SmtpStatusCode: RawRepresentable, Sendable, Equatable, Hashable, ExpressibleByIntegerLiteral {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        self.rawValue = value
    }

    public static let systemStatus: SmtpStatusCode = 211
    public static let helpMessage: SmtpStatusCode = 214
    public static let serviceReady: SmtpStatusCode = 220
    public static let serviceClosingTransmissionChannel: SmtpStatusCode = 221
    public static let authenticationSuccessful: SmtpStatusCode = 235
    public static let ok: SmtpStatusCode = 250
    public static let userNotLocalWillForward: SmtpStatusCode = 251
    public static let cannotVerifyUserWillAttemptDelivery: SmtpStatusCode = 252
    public static let authenticationChallenge: SmtpStatusCode = 334
    public static let startMailInput: SmtpStatusCode = 354
    public static let serviceNotAvailable: SmtpStatusCode = 421
    public static let passwordTransitionNeeded: SmtpStatusCode = 432
    public static let mailboxBusy: SmtpStatusCode = 450
    public static let errorInProcessing: SmtpStatusCode = 451
    public static let insufficientStorage: SmtpStatusCode = 452
    public static let temporaryAuthenticationFailure: SmtpStatusCode = 454
    public static let commandUnrecognized: SmtpStatusCode = 500
    public static let syntaxError: SmtpStatusCode = 501
    public static let commandNotImplemented: SmtpStatusCode = 502
    public static let badCommandSequence: SmtpStatusCode = 503
    public static let commandParameterNotImplemented: SmtpStatusCode = 504
    public static let authenticationRequired: SmtpStatusCode = 530
    public static let authenticationMechanismTooWeak: SmtpStatusCode = 534
    public static let authenticationInvalidCredentials: SmtpStatusCode = 535
    public static let encryptionRequiredForAuthenticationMechanism: SmtpStatusCode = 538
    public static let mailboxUnavailable: SmtpStatusCode = 550
    public static let userNotLocalTryAlternatePath: SmtpStatusCode = 551
    public static let exceededStorageAllocation: SmtpStatusCode = 552
    public static let mailboxNameNotAllowed: SmtpStatusCode = 553
    public static let transactionFailed: SmtpStatusCode = 554
    public static let mailFromOrRcptToParametersNotRecognizedOrNotImplemented: SmtpStatusCode = 555
}
