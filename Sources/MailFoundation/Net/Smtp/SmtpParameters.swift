//
// SmtpParameters.swift
//
// SMTP extension parameter models (SMTPUTF8/DSN/CHUNKING helpers).
//

/// Specifies the content transfer encoding for the message body.
///
/// Used with the BODY parameter of the MAIL FROM command when the server
/// supports 8BITMIME (RFC 1652) or BINARYMIME (RFC 3030) extensions.
///
/// ## See Also
/// - ``SmtpMailFromParameters``
public enum SmtpBodyKind: String, Sendable, Equatable {
    /// 7-bit ASCII content (the default).
    ///
    /// All data must be 7-bit clean with lines no longer than 998 characters.
    case sevenBit = "7BIT"

    /// 8-bit MIME content.
    ///
    /// Allows 8-bit data but still requires lines no longer than 998 characters.
    /// Requires the server to support the 8BITMIME extension.
    case eightBitMime = "8BITMIME"

    /// Binary MIME content.
    ///
    /// Allows arbitrary binary data with no line length restrictions.
    /// Requires the server to support the BINARYMIME extension.
    case binaryMime = "BINARYMIME"
}

/// Specifies what should be returned in a delivery status notification (DSN).
///
/// Used with the RET parameter of the MAIL FROM command when the server
/// supports the DSN extension (RFC 1891).
///
/// ## See Also
/// - ``SmtpMailFromParameters``
public enum SmtpReturnOption: String, Sendable, Equatable {
    /// Return the full message in the DSN.
    case full = "FULL"

    /// Return only the message headers in the DSN.
    case headers = "HDRS"
}

/// Specifies when delivery status notifications (DSN) should be sent.
///
/// Used with the NOTIFY parameter of the RCPT TO command when the server
/// supports the DSN extension (RFC 1891).
///
/// ## Example
/// ```swift
/// var params = SmtpRcptToParameters()
/// params.notify = [.failure, .delay]  // Notify on failure or delay
/// ```
///
/// ## See Also
/// - ``SmtpRcptToParameters``
public enum SmtpNotifyOption: String, Sendable, Equatable {
    /// Never send delivery notifications.
    ///
    /// This option must be used alone and cannot be combined with other options.
    case never = "NEVER"

    /// Send notification when the message is successfully delivered.
    case success = "SUCCESS"

    /// Send notification when delivery fails permanently.
    case failure = "FAILURE"

    /// Send notification when delivery is delayed.
    case delay = "DELAY"
}

/// Parameters for the SMTP MAIL FROM command.
///
/// These parameters are used with various SMTP extensions to provide additional
/// information about the message being sent. The transport automatically adds
/// appropriate parameters based on the message content and server capabilities.
///
/// ## Example
/// ```swift
/// var params = SmtpMailFromParameters()
/// params.size = 1024000  // Declare message size (SIZE extension)
/// params.body = .eightBitMime  // Use 8-bit encoding (8BITMIME extension)
/// params.ret = .headers  // Return headers only in DSN (DSN extension)
/// params.envid = "unique-id-123"  // Envelope ID for DSN tracking
///
/// try transport.sendChunked(message, mailParameters: params)
/// ```
///
/// ## Extensions
///
/// | Parameter | Extension | RFC |
/// |-----------|-----------|-----|
/// | smtpUtf8 | SMTPUTF8 | RFC 6531 |
/// | body | 8BITMIME/BINARYMIME | RFC 1652/3030 |
/// | size | SIZE | RFC 1870 |
/// | ret, envid | DSN | RFC 1891 |
/// | requireTls | REQUIRETLS | RFC 8689 |
///
/// ## See Also
/// - ``SmtpRcptToParameters``
/// - ``SmtpBodyKind``
/// - ``SmtpReturnOption``
public struct SmtpMailFromParameters: Sendable, Equatable {
    /// Whether to use the SMTPUTF8 extension for internationalized email.
    ///
    /// Set to `true` when the message contains UTF-8 in headers or addresses.
    /// Requires the server to support the SMTPUTF8 extension (RFC 6531).
    public var smtpUtf8: Bool

    /// The content transfer encoding for the message body.
    ///
    /// Specifies whether the message uses 7-bit, 8-bit, or binary encoding.
    /// Requires the server to support the appropriate extension.
    public var body: SmtpBodyKind?

    /// The declared size of the message in bytes.
    ///
    /// Allows the server to reject messages that exceed its size limit
    /// before the full message is transmitted. Requires the SIZE extension.
    public var size: Int?

    /// What to return in delivery status notifications.
    ///
    /// Specifies whether the full message or just headers should be included
    /// in bounce messages. Requires the DSN extension.
    public var ret: SmtpReturnOption?

    /// The envelope identifier for DSN correlation.
    ///
    /// A unique identifier that will be included in any delivery status
    /// notifications, allowing correlation with the original message.
    /// Requires the DSN extension.
    public var envid: String?

    /// Whether to require TLS for the entire delivery path.
    ///
    /// When enabled, all SMTP servers in the delivery chain must use TLS.
    /// If any server cannot guarantee TLS, the message will be bounced.
    /// Requires the REQUIRETLS extension (RFC 8689).
    public var requireTls: Bool

    /// Additional custom parameters to include.
    ///
    /// These are appended to the MAIL FROM command as-is.
    public var additional: [String]

    /// Creates new MAIL FROM parameters with the specified values.
    ///
    /// - Parameters:
    ///   - smtpUtf8: Whether to use SMTPUTF8. Defaults to `false`.
    ///   - body: The content encoding. Defaults to `nil` (not specified).
    ///   - size: The message size in bytes. Defaults to `nil`.
    ///   - ret: The DSN return option. Defaults to `nil`.
    ///   - envid: The envelope ID for DSN. Defaults to `nil`.
    ///   - requireTls: Whether to require TLS. Defaults to `false`.
    ///   - additional: Additional custom parameters. Defaults to empty.
    public init(
        smtpUtf8: Bool = false,
        body: SmtpBodyKind? = nil,
        size: Int? = nil,
        ret: SmtpReturnOption? = nil,
        envid: String? = nil,
        requireTls: Bool = false,
        additional: [String] = []
    ) {
        self.smtpUtf8 = smtpUtf8
        self.body = body
        self.size = size
        self.ret = ret
        self.envid = envid
        self.requireTls = requireTls
        self.additional = additional
    }

    /// Generates the parameter arguments for the MAIL FROM command.
    ///
    /// - Returns: An array of parameter strings (e.g., `["SIZE=1024", "BODY=8BITMIME"]`).
    public func arguments() -> [String] {
        var args: [String] = []
        if smtpUtf8 {
            args.append("SMTPUTF8")
        }
        if let body {
            args.append("BODY=\(body.rawValue)")
        }
        if let size {
            args.append("SIZE=\(size)")
        }
        if let ret {
            args.append("RET=\(ret.rawValue)")
        }
        if let envid {
            args.append("ENVID=\(envid)")
        }
        if requireTls {
            args.append("REQUIRETLS")
        }
        if !additional.isEmpty {
            args.append(contentsOf: additional)
        }
        return args
    }
}

/// Parameters for the SMTP RCPT TO command.
///
/// These parameters are used with the DSN (Delivery Status Notification)
/// extension to control when and how delivery notifications are sent
/// for specific recipients.
///
/// ## Example
/// ```swift
/// var params = SmtpRcptToParameters()
/// params.notify = [.failure, .delay]  // Notify on failure or delay
/// params.orcpt = "rfc822;original@example.com"  // Original recipient
///
/// try transport.sendChunked(message, rcptParameters: params)
/// ```
///
/// ## See Also
/// - ``SmtpMailFromParameters``
/// - ``SmtpNotifyOption``
public struct SmtpRcptToParameters: Sendable, Equatable {
    /// When to send delivery status notifications for this recipient.
    ///
    /// Can be any combination of `.success`, `.failure`, and `.delay`,
    /// or `.never` by itself. An empty array means no NOTIFY parameter
    /// is sent (server default behavior).
    public var notify: [SmtpNotifyOption]

    /// The original recipient address for DSN purposes.
    ///
    /// Used when the actual recipient differs from the original intended
    /// recipient (e.g., after alias expansion). Format is `type;address`
    /// where type is typically `rfc822`.
    public var orcpt: String?

    /// Additional custom parameters to include.
    ///
    /// These are appended to the RCPT TO command as-is.
    public var additional: [String]

    /// Creates new RCPT TO parameters with the specified values.
    ///
    /// - Parameters:
    ///   - notify: When to send notifications. Defaults to empty (server default).
    ///   - orcpt: The original recipient. Defaults to `nil`.
    ///   - additional: Additional custom parameters. Defaults to empty.
    public init(
        notify: [SmtpNotifyOption] = [],
        orcpt: String? = nil,
        additional: [String] = []
    ) {
        self.notify = notify
        self.orcpt = orcpt
        self.additional = additional
    }

    /// Generates the parameter arguments for the RCPT TO command.
    ///
    /// - Returns: An array of parameter strings (e.g., `["NOTIFY=FAILURE,DELAY"]`).
    public func arguments() -> [String] {
        var args: [String] = []
        if !notify.isEmpty {
            let value = notify.map { $0.rawValue }.joined(separator: ",")
            args.append("NOTIFY=\(value)")
        }
        if let orcpt {
            args.append("ORCPT=\(orcpt)")
        }
        if !additional.isEmpty {
            args.append(contentsOf: additional)
        }
        return args
    }
}
