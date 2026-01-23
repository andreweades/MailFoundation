//
// ImapModSeqResponse.swift
//
// Parse CONDSTORE/QRESYNC MODSEQ response codes.
//

public enum ImapModSeqKind: Sendable, Equatable {
    case highest
    case modSeq
}

public struct ImapModSeqResponse: Sendable, Equatable {
    public let kind: ImapModSeqKind
    public let value: UInt64

    public static func parse(_ line: String) -> ImapModSeqResponse? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "["), let close = trimmed.firstIndex(of: "]"), close > open else {
            return nil
        }
        let inner = trimmed[trimmed.index(after: open)..<close]
        let parts = inner.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, let value = UInt64(parts[1]) else {
            return nil
        }
        let code = parts[0].uppercased()
        switch code {
        case "HIGHESTMODSEQ":
            return ImapModSeqResponse(kind: .highest, value: value)
        case "MODSEQ":
            return ImapModSeqResponse(kind: .modSeq, value: value)
        default:
            return nil
        }
    }
}
