//
// Pop3Capabilities.swift
//
// POP3 capabilities parsed from CAPA.
//

public struct Pop3Capabilities: Sendable, Equatable {
    public let rawLines: [String]
    public let extensions: [String: String]
    public let flags: Set<String>

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

    public func supports(_ name: String) -> Bool {
        let key = name.uppercased()
        return flags.contains(key) || extensions[key] != nil
    }

    public func value(for name: String) -> String? {
        extensions[name.uppercased()]
    }

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

    public static func parse(_ event: Pop3ResponseEvent) -> Pop3Capabilities? {
        guard case let .multiline(response, lines) = event, response.isSuccess else {
            return nil
        }
        return Pop3Capabilities(rawLines: lines)
    }
}
