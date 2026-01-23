//
// NullProtocolLogger.swift
//
// Ported from MailKit (C#) to Swift.
//

import Foundation

public final class NullProtocolLogger: ProtocolLoggerType {
    public init() {}

    public var authenticationSecretDetector: AuthenticationSecretDetector?

    public func logConnect(_ uri: URL) {
    }

    public func logClient(_ buffer: [UInt8], offset: Int, count: Int) {
    }

    public func logServer(_ buffer: [UInt8], offset: Int, count: Int) {
    }

    public func close() {
    }
}
