//
// MessageFlags.swift
//
// Ported from MailKit (C#) to Swift.
//

public struct MessageFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let none = MessageFlags([])
    public static let seen = MessageFlags(rawValue: 1 << 0)
    public static let answered = MessageFlags(rawValue: 1 << 1)
    public static let flagged = MessageFlags(rawValue: 1 << 2)
    public static let deleted = MessageFlags(rawValue: 1 << 3)
    public static let draft = MessageFlags(rawValue: 1 << 4)
    public static let recent = MessageFlags(rawValue: 1 << 5)
    public static let userDefined = MessageFlags(rawValue: 1 << 6)
}
