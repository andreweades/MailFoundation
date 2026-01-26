//
// DeliveryStatusNotification.swift
//
// Delivery status notification helpers backed by MessageDeliveryStatus.
//

import Foundation
import MimeFoundation

/// A parsed delivery status notification (DSN) message.
///
/// Delivery Status Notifications, as defined in RFC 3464, are used to inform the sender
/// about the delivery status of their message. This structure provides a convenient way
/// to access the information contained in a DSN message.
///
/// A DSN contains per-message fields (such as the reporting MTA) and per-recipient
/// status information (such as the final recipient address and delivery status code).
///
/// ## Topics
///
/// ### Properties
/// - ``messageFields``
/// - ``recipients``
///
/// ### Creating a DSN
/// - ``init(messageFields:recipients:)``
/// - ``init(status:)``
/// - ``init(message:)``
/// - ``init(entity:)``
///
/// ## Example
///
/// ```swift
/// if let dsn = DeliveryStatusNotification(message: mimeMessage) {
///     if let mta = dsn.messageFields?.reportingMta {
///         print("Reported by: \(mta.address)")
///     }
///     for recipient in dsn.recipients {
///         if let status = recipient.status {
///             print("Status: \(status.rawValue)")
///         }
///         if recipient.action == .failed {
///             print("Delivery failed to: \(recipient.finalRecipient?.address ?? "unknown")")
///         }
///     }
/// }
/// ```
public struct DeliveryStatusNotification: Sendable, Equatable {
    /// The per-message fields from the DSN.
    ///
    /// Contains information that applies to the entire message, such as the
    /// reporting MTA, arrival date, and original envelope ID.
    public let messageFields: DeliveryStatusFields?

    /// The per-recipient status information.
    ///
    /// Each element represents the delivery status for one recipient of the
    /// original message.
    public let recipients: [DeliveryStatusRecipient]

    /// Creates a delivery status notification with the specified fields and recipients.
    ///
    /// - Parameters:
    ///   - messageFields: The per-message fields.
    ///   - recipients: The per-recipient status information.
    public init(messageFields: DeliveryStatusFields?, recipients: [DeliveryStatusRecipient]) {
        self.messageFields = messageFields
        self.recipients = recipients
    }

    /// Creates a delivery status notification from a `MessageDeliveryStatus` entity.
    ///
    /// - Parameter status: The message delivery status entity to parse.
    public init(status: MessageDeliveryStatus) {
        let groups = status.statusGroups
        if groups.isEmpty {
            self.messageFields = nil
            self.recipients = []
            return
        }
        self.messageFields = DeliveryStatusFields(headers: groups[0])
        if groups.count > 1 {
            self.recipients = (1..<groups.count).map { DeliveryStatusRecipient(headers: groups[$0]) }
        } else {
            self.recipients = []
        }
    }

    /// Creates a delivery status notification from a MIME message.
    ///
    /// This initializer searches the message body for a DSN and parses it.
    ///
    /// - Parameter message: The MIME message to search for a DSN.
    /// - Returns: A delivery status notification, or `nil` if no DSN is found.
    public init?(message: MimeMessage) {
        guard let entity = message.body else { return nil }
        self.init(entity: entity)
    }

    /// Creates a delivery status notification from a MIME entity.
    ///
    /// This initializer searches the entity (and its children if it's a multipart)
    /// for a DSN and parses it.
    ///
    /// - Parameter entity: The MIME entity to search for a DSN.
    /// - Returns: A delivery status notification, or `nil` if no DSN is found.
    public init?(entity: MimeEntity) {
        guard let status = DeliveryStatusNotification.findStatus(in: entity) else { return nil }
        self.init(status: status)
    }

    private static func findStatus(in entity: MimeEntity) -> MessageDeliveryStatus? {
        if let status = entity as? MessageDeliveryStatus {
            return status
        }
        if let report = entity as? MultipartReport {
            if report.reportType?.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() == "delivery-status" {
                for index in report.indices {
                    let part = report[index]
                    if let status = part as? MessageDeliveryStatus {
                        return status
                    }
                }
            }
        }
        return nil
    }
}

/// Per-message fields from a delivery status notification.
///
/// These fields provide information about the overall delivery attempt,
/// including which MTA is reporting the status and when the message arrived.
public struct DeliveryStatusFields: Sendable, Equatable {
    /// The MTA that is reporting the delivery status.
    ///
    /// Corresponds to the `Reporting-MTA` field in the DSN.
    public let reportingMta: DeliveryStatusAddress?

    /// The MTA from which the message was received.
    ///
    /// Corresponds to the `Received-From-MTA` field in the DSN.
    public let receivedFromMta: DeliveryStatusAddress?

    /// The original envelope identifier, if available.
    ///
    /// Corresponds to the `Original-Envelope-Id` field in the DSN.
    /// This allows the sender to correlate the DSN with the original message.
    public let originalEnvelopeId: String?

    /// The date and time the message arrived at the reporting MTA.
    ///
    /// Corresponds to the `Arrival-Date` field in the DSN.
    public let arrivalDate: Date?

    /// The name of the MTA, if available.
    ///
    /// Corresponds to the `MTA-Name` field in the DSN.
    public let mtaName: String?

    /// Any additional fields not parsed into specific properties.
    ///
    /// Contains field names (lowercased) mapped to their values.
    public let otherFields: [String: [String]]

    init(headers: HeaderList) {
        var remaining = DeliveryStatusFields.collectFields(headers)
        reportingMta = DeliveryStatusAddress.parse(remaining.popFirstValue(for: "reporting-mta"))
        receivedFromMta = DeliveryStatusAddress.parse(remaining.popFirstValue(for: "received-from-mta"))
        originalEnvelopeId = remaining.popFirstValue(for: "original-envelope-id")
        if let arrival = remaining.popFirstValue(for: "arrival-date") {
            arrivalDate = DateUtils.tryParse(arrival)
        } else {
            arrivalDate = nil
        }
        mtaName = remaining.popFirstValue(for: "mta-name")
        otherFields = remaining
    }

    fileprivate static func collectFields(_ headers: HeaderList) -> [String: [String]] {
        var fields: [String: [String]] = [:]
        for header in headers {
            let key = header.field.lowercased()
            fields[key, default: []].append(header.value)
        }
        return fields
    }
}

/// Per-recipient status information from a delivery status notification.
///
/// Each recipient of the original message has a separate status block in the DSN.
/// This structure contains the delivery status information for a single recipient.
public struct DeliveryStatusRecipient: Sendable, Equatable {
    /// The original recipient address as specified by the sender.
    ///
    /// Corresponds to the `Original-Recipient` field in the DSN.
    public let originalRecipient: DeliveryStatusAddress?

    /// The final recipient address after any forwarding or aliasing.
    ///
    /// Corresponds to the `Final-Recipient` field in the DSN.
    /// This is the address that was actually attempted for delivery.
    public let finalRecipient: DeliveryStatusAddress?

    /// The action performed by the reporting MTA.
    ///
    /// Corresponds to the `Action` field in the DSN. Indicates whether
    /// delivery failed, was delayed, succeeded, etc.
    public let action: DeliveryStatusAction?

    /// The delivery status code.
    ///
    /// Corresponds to the `Status` field in the DSN. This is a structured
    /// code that indicates the type of delivery result.
    public let status: DeliveryStatusCode?

    /// The remote MTA that reported the delivery status.
    ///
    /// Corresponds to the `Remote-MTA` field in the DSN.
    public let remoteMta: DeliveryStatusAddress?

    /// The diagnostic code from the remote MTA.
    ///
    /// Corresponds to the `Diagnostic-Code` field in the DSN.
    /// Contains the actual error message or response from the remote server.
    public let diagnosticCode: DeliveryStatusDiagnostic?

    /// The date and time of the last delivery attempt.
    ///
    /// Corresponds to the `Last-Attempt-Date` field in the DSN.
    public let lastAttemptDate: Date?

    /// The final log identifier, if available.
    ///
    /// Corresponds to the `Final-Log-Id` field in the DSN.
    public let finalLogId: String?

    /// The date until which delivery will continue to be attempted.
    ///
    /// Corresponds to the `Will-Retry-Until` field in the DSN.
    /// Only applicable when ``action`` is ``DeliveryStatusAction/delayed``.
    public let willRetryUntil: Date?

    /// Any additional fields not parsed into specific properties.
    ///
    /// Contains field names (lowercased) mapped to their values.
    public let otherFields: [String: [String]]

    init(headers: HeaderList) {
        var remaining = DeliveryStatusFields.collectFields(headers)
        originalRecipient = DeliveryStatusAddress.parse(remaining.popFirstValue(for: "original-recipient"))
        finalRecipient = DeliveryStatusAddress.parse(remaining.popFirstValue(for: "final-recipient"))
        if let actionValue = remaining.popFirstValue(for: "action") {
            action = DeliveryStatusAction.parse(actionValue)
        } else {
            action = nil
        }
        if let statusValue = remaining.popFirstValue(for: "status") {
            status = DeliveryStatusCode(rawValue: statusValue)
        } else {
            status = nil
        }
        remoteMta = DeliveryStatusAddress.parse(remaining.popFirstValue(for: "remote-mta"))
        diagnosticCode = DeliveryStatusDiagnostic.parse(remaining.popFirstValue(for: "diagnostic-code"))
        if let lastAttempt = remaining.popFirstValue(for: "last-attempt-date") {
            lastAttemptDate = DateUtils.tryParse(lastAttempt)
        } else {
            lastAttemptDate = nil
        }
        finalLogId = remaining.popFirstValue(for: "final-log-id")
        if let retryUntil = remaining.popFirstValue(for: "will-retry-until") {
            willRetryUntil = DateUtils.tryParse(retryUntil)
        } else {
            willRetryUntil = nil
        }
        otherFields = remaining
    }
}

/// The action performed by the reporting MTA for a recipient.
///
/// Indicates the result of the delivery attempt as specified in RFC 3464.
public enum DeliveryStatusAction: String, Sendable, Equatable {
    /// Delivery to the recipient failed permanently.
    ///
    /// The message could not be delivered and will not be retried.
    case failed

    /// Delivery to the recipient is delayed.
    ///
    /// The message is being held for future delivery attempts.
    /// Check ``DeliveryStatusRecipient/willRetryUntil`` for the retry deadline.
    case delayed

    /// The message was successfully delivered to the recipient.
    case delivered

    /// The message was relayed to another MTA.
    ///
    /// The reporting MTA forwarded the message but cannot guarantee
    /// that a DSN will be generated for subsequent delivery attempts.
    case relayed

    /// The message was expanded to multiple recipients.
    ///
    /// The original recipient address expanded to multiple addresses
    /// (e.g., a mailing list).
    case expanded

    /// Parses an action string into a `DeliveryStatusAction`.
    ///
    /// - Parameter value: The action string to parse.
    /// - Returns: The corresponding action, or `nil` if unrecognized.
    static func parse(_ value: String) -> DeliveryStatusAction? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return DeliveryStatusAction(rawValue: normalized)
    }
}

/// An address from a delivery status notification.
///
/// DSN addresses include a type specifier (usually "rfc822" for email addresses
/// or "dns" for MTA hostnames) followed by the actual address.
public struct DeliveryStatusAddress: Sendable, Equatable {
    /// The address type.
    ///
    /// Common values include:
    /// - `"rfc822"` for email addresses
    /// - `"dns"` for DNS hostnames
    public let type: String

    /// The address value.
    ///
    /// The format depends on the ``type``. For `"rfc822"` this is an email address;
    /// for `"dns"` this is a hostname.
    public let address: String

    /// Creates a delivery status address.
    ///
    /// - Parameters:
    ///   - type: The address type (e.g., "rfc822", "dns").
    ///   - address: The address value.
    public init(type: String, address: String) {
        self.type = type
        self.address = address
    }

    /// Parses an address string in the format "type; address".
    ///
    /// - Parameter value: The string to parse.
    /// - Returns: A parsed address, or `nil` if the format is invalid.
    static func parse(_ value: String?) -> DeliveryStatusAddress? {
        guard let value else { return nil }
        let parts = value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let type = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let address = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !type.isEmpty, !address.isEmpty else { return nil }
        return DeliveryStatusAddress(type: type, address: address)
    }
}

/// A diagnostic code from a delivery status notification.
///
/// Diagnostic codes provide human-readable error messages from the remote MTA,
/// along with a type specifier indicating the format of the diagnostic.
public struct DeliveryStatusDiagnostic: Sendable, Equatable {
    /// The diagnostic type.
    ///
    /// Common values include:
    /// - `"smtp"` for SMTP response codes
    /// - `"x-unix"` for Unix error messages
    public let type: String

    /// The diagnostic message.
    ///
    /// The actual error message or response from the remote server.
    /// For SMTP diagnostics, this typically includes the response code and text.
    public let message: String

    /// Creates a diagnostic code.
    ///
    /// - Parameters:
    ///   - type: The diagnostic type (e.g., "smtp").
    ///   - message: The diagnostic message.
    public init(type: String, message: String) {
        self.type = type
        self.message = message
    }

    /// Parses a diagnostic string in the format "type; message".
    ///
    /// - Parameter value: The string to parse.
    /// - Returns: A parsed diagnostic, or `nil` if the format is invalid.
    static func parse(_ value: String?) -> DeliveryStatusDiagnostic? {
        guard let value else { return nil }
        let parts = value.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let type = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let message = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !type.isEmpty, !message.isEmpty else { return nil }
        return DeliveryStatusDiagnostic(type: type, message: message)
    }
}

/// A structured delivery status code.
///
/// Status codes are defined in RFC 3463 and have the format `class.subject.detail`,
/// where each component is a numeric value indicating progressively more specific
/// information about the delivery status.
///
/// ## Class Codes
///
/// - `2` - Success: The message was delivered successfully.
/// - `4` - Persistent Transient Failure: Delivery failed but may succeed later.
/// - `5` - Permanent Failure: Delivery failed and will not be retried.
///
/// ## Example
///
/// ```swift
/// if let code = recipient.status {
///     if code.classCode == 5 {
///         print("Permanent failure: \(code.rawValue)")
///     }
/// }
/// ```
public struct DeliveryStatusCode: Sendable, Equatable {
    /// The class code (first component).
    ///
    /// Indicates the broad category of the status:
    /// - `2`: Success
    /// - `4`: Persistent transient failure
    /// - `5`: Permanent failure
    public let classCode: Int

    /// The subject code (second component).
    ///
    /// Indicates the category of the status within the class.
    /// Common values include:
    /// - `0`: Undefined/other status
    /// - `1`: Addressing status
    /// - `2`: Mailbox status
    /// - `3`: Mail system status
    /// - `4`: Network/routing status
    /// - `5`: Mail delivery protocol status
    /// - `6`: Message content/media status
    /// - `7`: Security/policy status
    public let subject: Int

    /// The detail code (third component).
    ///
    /// Provides specific information about the status within the subject category.
    public let detail: Int

    /// The status code as a string in the format "class.subject.detail".
    public let rawValue: String

    /// Parses a status code string.
    ///
    /// - Parameter rawValue: The status code string to parse (e.g., "5.1.1").
    /// - Returns: A parsed status code, or `nil` if the format is invalid.
    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = trimmed.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? trimmed
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let classCode = Int(parts[0]),
              let subject = Int(parts[1]),
              let detail = Int(parts[2]) else {
            return nil
        }
        self.classCode = classCode
        self.subject = subject
        self.detail = detail
        self.rawValue = "\(classCode).\(subject).\(detail)"
    }
}

private extension Dictionary where Key == String, Value == [String] {
    mutating func popFirstValue(for key: String) -> String? {
        guard var values = self[key], !values.isEmpty else { return nil }
        let first = values.removeFirst()
        if values.isEmpty {
            self[key] = nil
        } else {
            self[key] = values
        }
        return first
    }
}
