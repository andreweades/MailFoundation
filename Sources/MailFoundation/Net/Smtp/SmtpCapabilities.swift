//
// SmtpCapabilities.swift
//
// SMTP capabilities parsed from EHLO.
//

public struct SmtpCapabilities: Sendable, Equatable {
    public let rawLines: [String]
    public let extensions: [String: String]
    public let flags: Set<String>

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

    public func supports(_ name: String) -> Bool {
        let key = name.uppercased()
        return flags.contains(key) || extensions[key] != nil
    }

    public func value(for name: String) -> String? {
        extensions[name.uppercased()]
    }

    public static func parseEhlo(_ response: SmtpResponse) -> SmtpCapabilities? {
        guard response.code == 250 else { return nil }
        let lines = response.lines
        guard !lines.isEmpty else { return nil }
        let capabilityLines = Array(lines.dropFirst())
        return SmtpCapabilities(rawLines: capabilityLines)
    }
}
