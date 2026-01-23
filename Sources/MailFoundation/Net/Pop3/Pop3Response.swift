//
// Pop3Response.swift
//
// Basic POP3 response model.
//

import Foundation

public enum Pop3ResponseStatus: Sendable {
    case ok
    case err
    case continuation
}

public struct Pop3Response: Sendable, Equatable {
    public let status: Pop3ResponseStatus
    public let message: String

    public var isSuccess: Bool {
        status == .ok
    }

    public var isContinuation: Bool {
        status == .continuation
    }

    public var apopChallenge: String? {
        guard status == .ok else { return nil }
        guard let start = message.firstIndex(of: "<"),
              let end = message[start...].firstIndex(of: ">"),
              start < end else {
            return nil
        }
        return String(message[start...end])
    }

    public static func parse(_ line: String) -> Pop3Response? {
        if line.hasPrefix("+OK") {
            let message = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
            return Pop3Response(status: .ok, message: String(message))
        }
        if line.hasPrefix("-ERR") {
            let message = line.dropFirst(4).trimmingCharacters(in: .whitespaces)
            return Pop3Response(status: .err, message: String(message))
        }
        if line.hasPrefix("+") {
            let message = line.dropFirst(1).trimmingCharacters(in: .whitespaces)
            return Pop3Response(status: .continuation, message: String(message))
        }
        return nil
    }
}
