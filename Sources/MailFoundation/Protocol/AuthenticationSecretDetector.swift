//
// AuthenticationSecretDetector.swift
//
// Ported from MailKit (C#) to Swift.
//

public struct AuthenticationSecret: Sendable, Hashable {
    public let startIndex: Int
    public let length: Int

    public init(startIndex: Int, length: Int) {
        self.startIndex = startIndex
        self.length = length
    }
}

public protocol AuthenticationSecretDetector: AnyObject {
    func detectSecrets(in buffer: [UInt8], offset: Int, count: Int) -> [AuthenticationSecret]
}

public typealias IAuthenticationSecretDetector = AuthenticationSecretDetector
