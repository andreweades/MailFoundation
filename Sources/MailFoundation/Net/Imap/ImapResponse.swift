//
// ImapResponse.swift
//
// Basic IMAP response model.
//

import Foundation

public enum ImapResponseKind: Sendable, Equatable {
    case untagged
    case tagged(String)
    case continuation
}

public enum ImapResponseStatus: String, Sendable {
    case ok = "OK"
    case no = "NO"
    case bad = "BAD"
    case preauth = "PREAUTH"
    case bye = "BYE"
}

public struct ImapResponse: Sendable, Equatable {
    public let kind: ImapResponseKind
    public let status: ImapResponseStatus?
    public let text: String

    public var isOk: Bool {
        status == .ok
    }

    public static func parse(_ line: String) -> ImapResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("+") {
            let message = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            return ImapResponse(kind: .continuation, status: nil, text: String(message))
        }

        let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard let first = parts.first else { return nil }

        let kind: ImapResponseKind
        if first == "*" {
            kind = .untagged
        } else {
            kind = .tagged(String(first))
        }

        let statusIndex = first == "*" ? 1 : 1
        guard parts.count > statusIndex else {
            return ImapResponse(kind: kind, status: nil, text: "")
        }

        let statusToken = String(parts[statusIndex])
        let status = ImapResponseStatus(rawValue: statusToken)
        let text: String
        if parts.count > statusIndex + 1 {
            text = String(parts[statusIndex + 1])
        } else {
            text = ""
        }

        return ImapResponse(kind: kind, status: status, text: text)
    }
}
