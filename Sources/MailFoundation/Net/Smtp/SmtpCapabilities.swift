//
// SmtpCapabilities.swift
//
// SMTP capabilities parsed from EHLO.
//

/// Represents the capabilities supported by an SMTP server.
///
/// SMTP capabilities are advertised by the server in response to the EHLO command.
/// They indicate which SMTP extensions the server supports, such as authentication
/// mechanisms, message size limits, STARTTLS, pipelining, and more.
///
/// ## Common Capabilities
///
/// | Capability | Description | RFC |
/// |------------|-------------|-----|
/// | SIZE | Maximum message size | RFC 1870 |
/// | 8BITMIME | 8-bit MIME support | RFC 1652 |
/// | PIPELINING | Command pipelining | RFC 2920 |
/// | STARTTLS | TLS encryption upgrade | RFC 3207 |
/// | AUTH | SASL authentication | RFC 4954 |
/// | DSN | Delivery status notifications | RFC 1891 |
/// | CHUNKING | Chunked message transfer | RFC 3030 |
/// | SMTPUTF8 | Internationalized email | RFC 6531 |
///
/// ## Example
/// ```swift
/// let capabilities = try transport.ehlo(domain: "client.example.com")
///
/// // Check if the server supports TLS
/// if capabilities.supports("STARTTLS") {
///     try transport.startTls()
/// }
///
/// // Get the maximum message size
/// if let sizeStr = capabilities.value(for: "SIZE"),
///    let maxSize = Int(sizeStr) {
///     print("Max message size: \(maxSize) bytes")
/// }
///
/// // Check authentication methods
/// if let authMethods = capabilities.value(for: "AUTH") {
///     print("Supported auth: \(authMethods)")
/// }
/// ```
///
/// ## See Also
/// - ``SmtpTransport/ehlo(domain:)``
/// - ``AsyncSmtpTransport/ehlo(domain:)``
public struct SmtpCapabilities: Sendable, Equatable {
    /// The raw capability lines from the EHLO response.
    ///
    /// These are the original lines as received from the server,
    /// with the status code prefix removed.
    public let rawLines: [String]

    /// Capabilities that have associated values.
    ///
    /// For example, `AUTH PLAIN LOGIN` would be stored as `["AUTH": "PLAIN LOGIN"]`,
    /// and `SIZE 52428800` would be stored as `["SIZE": "52428800"]`.
    public let extensions: [String: String]

    /// Capabilities that are simple flags without values.
    ///
    /// For example, `PIPELINING` or `SMTPUTF8` are stored as flags.
    public let flags: Set<String>

    /// Creates capabilities from raw EHLO response lines.
    ///
    /// Parses each line to extract the capability name and optional value.
    /// Names are normalized to uppercase for case-insensitive matching.
    ///
    /// - Parameter rawLines: The capability lines from the EHLO response,
    ///   excluding the first line (server greeting).
    public init(rawLines: [String]) {
        self.rawLines = rawLines
        var map: [String: String] = [:]
        var flags: Set<String> = []
        for line in rawLines {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let name = parts.first else { continue }
            let key = String(name).uppercased()
            if parts.count > 1 {
                map[key] = String(parts[1])
            } else {
                flags.insert(key)
            }
        }
        self.extensions = map
        self.flags = flags
    }

    /// Checks whether the server supports a specific capability.
    ///
    /// The check is case-insensitive.
    ///
    /// - Parameter name: The capability name to check (e.g., "STARTTLS", "PIPELINING").
    /// - Returns: `true` if the server advertised this capability.
    public func supports(_ name: String) -> Bool {
        let key = name.uppercased()
        return flags.contains(key) || extensions[key] != nil
    }

    /// Gets the value associated with a capability.
    ///
    /// For capabilities like `AUTH PLAIN LOGIN` or `SIZE 52428800`,
    /// this returns the part after the capability name.
    ///
    /// - Parameter name: The capability name (case-insensitive).
    /// - Returns: The capability value, or `nil` if not present or has no value.
    public func value(for name: String) -> String? {
        extensions[name.uppercased()]
    }

    /// Parses capabilities from an EHLO response.
    ///
    /// The EHLO response includes the server greeting on the first line,
    /// followed by capability lines. This method extracts just the capabilities.
    ///
    /// - Parameter response: The complete EHLO response.
    /// - Returns: The parsed capabilities, or `nil` if the response was not successful.
    public static func parseEhlo(_ response: SmtpResponse) -> SmtpCapabilities? {
        guard response.code == 250 else { return nil }
        let lines = response.lines
        guard !lines.isEmpty else { return nil }
        let capabilityLines = Array(lines.dropFirst())
        return SmtpCapabilities(rawLines: capabilityLines)
    }
}
