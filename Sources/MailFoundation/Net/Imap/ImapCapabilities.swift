//
// ImapCapabilities.swift
//
// IMAP capability parsing.
//

import Foundation

public struct ImapCapabilities: Sendable, Equatable {
    public let rawTokens: [String]
    public let capabilities: Set<String>

    public init(tokens: [String]) {
        self.rawTokens = tokens
        self.capabilities = Set(tokens.map { $0.uppercased() })
    }

    public func supports(_ name: String) -> Bool {
        capabilities.contains(name.uppercased())
    }

    public static func parse(from line: String) -> ImapCapabilities? {
        if let bracketed = parseBracketedCapabilities(from: line) {
            return bracketed
        }

        let tokens = line.split(separator: " ").map(String.init)
        guard let index = tokens.firstIndex(where: { $0.caseInsensitiveEquals("CAPABILITY") }) else {
            return nil
        }
        let capabilityTokens = tokens[(index + 1)...]
        guard !capabilityTokens.isEmpty else { return nil }
        return ImapCapabilities(tokens: Array(capabilityTokens))
    }

    private static func parseBracketedCapabilities(from line: String) -> ImapCapabilities? {
        guard let range = line.range(of: "[CAPABILITY", options: [.caseInsensitive]) else {
            return nil
        }

        let after = line[range.upperBound...]
        guard let end = after.firstIndex(of: "]") else {
            return nil
        }

        let contents = after[..<end]
        let tokens = contents.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return nil }
        return ImapCapabilities(tokens: tokens)
    }
}

private extension String {
    func caseInsensitiveEquals(_ other: String) -> Bool {
        compare(other, options: [.caseInsensitive]) == .orderedSame
    }
}
