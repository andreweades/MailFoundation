//
// Pop3Response.swift
//
// Basic POP3 response model.
//

import Foundation

public enum Pop3ResponseStatus: Sendable {
    case ok
    case err
}

public struct Pop3Response: Sendable, Equatable {
    public let status: Pop3ResponseStatus
    public let message: String

    public var isSuccess: Bool {
        status == .ok
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
        return nil
    }
}
