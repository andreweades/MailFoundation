//
// ImapCommand.swift
//
// Basic IMAP command model.
//

import Foundation

public struct ImapCommand: Sendable {
    public let tag: String
    public let name: String
    public let arguments: String?

    public init(tag: String, name: String, arguments: String? = nil) {
        self.tag = tag
        self.name = name
        self.arguments = arguments
    }

    public var serialized: String {
        if let arguments {
            return "\(tag) \(name) \(arguments)\r\n"
        }
        return "\(tag) \(name)\r\n"
    }
}

public struct ImapTagGenerator: Sendable {
    private var counter: UInt

    public init(seed: UInt = 0) {
        self.counter = seed
    }

    public mutating func nextTag() -> String {
        counter += 1
        return String(format: "A%04u", counter)
    }
}
