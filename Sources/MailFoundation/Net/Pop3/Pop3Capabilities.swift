//
// Pop3Capabilities.swift
//
// POP3 capabilities parsed from CAPA.
//

/// Represents the capabilities advertised by a POP3 server.
///
/// The `Pop3Capabilities` struct parses and provides access to the capabilities
/// returned by the CAPA command. Capabilities indicate which optional POP3
/// extensions the server supports.
///
/// ## Overview
///
/// Common POP3 capabilities include:
/// - `TOP` - Server supports the TOP command for retrieving message headers
/// - `UIDL` - Server supports unique message identifiers
/// - `USER` - Server supports USER/PASS authentication
/// - `SASL` - Server supports SASL authentication mechanisms
/// - `STLS` - Server supports STARTTLS for encryption
/// - `PIPELINING` - Server supports command pipelining
/// - `EXPIRE` - Messages may be automatically deleted after a period
/// - `LOGIN-DELAY` - Minimum delay between login attempts
/// - `RESP-CODES` - Server sends extended response codes
/// - `AUTH-RESP-CODE` - Server sends authentication response codes
///
/// ## Usage
///
/// ```swift
/// // After connecting to a POP3 server
/// if let caps = try session.capa() {
///     // Check for specific capabilities
///     if caps.supports("UIDL") {
///         print("Server supports unique IDs")
///     }
///
///     // Get SASL mechanisms
///     let mechanisms = caps.saslMechanisms()
///     print("Supported auth: \(mechanisms)")
///
///     // Get capability value
///     if let expire = caps.value(for: "EXPIRE") {
///         print("Messages expire after: \(expire)")
///     }
/// }
/// ```
///
/// ## See Also
///
/// - ``Pop3Session/capa()`` for querying capabilities
/// - ``Pop3Sasl`` for SASL authentication
public struct Pop3Capabilities: Sendable, Equatable {
    /// The raw capability lines as returned by the server.
    public let rawLines: [String]

    /// Capabilities that have associated values (e.g., "SASL PLAIN LOGIN").
    ///
    /// Keys are normalized to uppercase.
    public let extensions: [String: String]

    /// Capabilities that are simple flags without values.
    ///
    /// Values are normalized to uppercase.
    public let flags: Set<String>

    /// Initializes capabilities from raw CAPA response lines.
    ///
    /// - Parameter rawLines: The lines from the CAPA multiline response (excluding the status line).
    public init(rawLines: [String]) {
        self.rawLines = rawLines
        var extensions: [String: String] = [:]
        var flags: Set<String> = []

        for line in rawLines {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard let name = parts.first else { continue }
            let key = String(name).uppercased()
            if parts.count > 1 {
                extensions[key] = String(parts[1])
            } else {
                flags.insert(key)
            }
        }

        self.extensions = extensions
        self.flags = flags
    }

    /// Checks if the server supports a specific capability.
    ///
    /// The check is case-insensitive.
    ///
    /// - Parameter name: The capability name to check.
    /// - Returns: `true` if the capability is supported.
    public func supports(_ name: String) -> Bool {
        let key = name.uppercased()
        return flags.contains(key) || extensions[key] != nil
    }

    /// Gets the value associated with a capability.
    ///
    /// Some capabilities like `SASL` or `EXPIRE` have associated values.
    ///
    /// - Parameter name: The capability name (case-insensitive).
    /// - Returns: The capability value, or nil if not present or no value.
    public func value(for name: String) -> String? {
        extensions[name.uppercased()]
    }

    /// Gets the list of supported SASL authentication mechanisms.
    ///
    /// This method checks both the SASL and AUTH capabilities in various
    /// formats used by different servers.
    ///
    /// - Returns: An array of supported mechanism names in uppercase.
    public func saslMechanisms() -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        func appendMechanisms(from value: String) {
            for token in value.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let mechanism = trimmed.uppercased()
                guard !seen.contains(mechanism) else { continue }
                seen.insert(mechanism)
                result.append(mechanism)
            }
        }

        if let saslValue = extensions["SASL"] {
            appendMechanisms(from: saslValue)
        }
        if let authValue = extensions["AUTH"] {
            appendMechanisms(from: authValue)
        }
        for flag in flags {
            if flag.hasPrefix("SASL=") {
                appendMechanisms(from: String(flag.dropFirst("SASL=".count)))
            } else if flag.hasPrefix("AUTH=") {
                appendMechanisms(from: String(flag.dropFirst("AUTH=".count)))
            }
        }

        return result
    }

    /// Parses capabilities from a CAPA response event.
    ///
    /// - Parameter event: The multiline response event from a CAPA command.
    /// - Returns: The parsed capabilities, or nil if parsing failed.
    public static func parse(_ event: Pop3ResponseEvent) -> Pop3Capabilities? {
        guard case let .multiline(response, lines) = event, response.isSuccess else {
            return nil
        }
        return Pop3Capabilities(rawLines: lines)
    }
}
