//
// MessageSummaryItems.swift
//
// Ported from MailKit (C#) to Swift.
//

public struct MessageSummaryItems: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let none = MessageSummaryItems([])

    public static let annotations = MessageSummaryItems(rawValue: 1 << 0)
    public static let body = MessageSummaryItems(rawValue: 1 << 1)
    public static let bodyStructure = MessageSummaryItems(rawValue: 1 << 2)
    public static let envelope = MessageSummaryItems(rawValue: 1 << 3)
    public static let flags = MessageSummaryItems(rawValue: 1 << 4)
    public static let internalDate = MessageSummaryItems(rawValue: 1 << 5)
    public static let size = MessageSummaryItems(rawValue: 1 << 6)
    public static let modSeq = MessageSummaryItems(rawValue: 1 << 7)
    public static let references = MessageSummaryItems(rawValue: 1 << 8)
    public static let uniqueId = MessageSummaryItems(rawValue: 1 << 9)
    public static let emailId = MessageSummaryItems(rawValue: 1 << 10)
    public static let threadId = MessageSummaryItems(rawValue: 1 << 11)
    public static let gmailMessageId = MessageSummaryItems(rawValue: 1 << 12)
    public static let gmailThreadId = MessageSummaryItems(rawValue: 1 << 13)
    public static let gmailLabels = MessageSummaryItems(rawValue: 1 << 14)
    public static let headers = MessageSummaryItems(rawValue: 1 << 15)
    public static let previewText = MessageSummaryItems(rawValue: 1 << 16)
    public static let saveDate = MessageSummaryItems(rawValue: 1 << 17)

    public static let all: MessageSummaryItems = [.envelope, .flags, .internalDate, .size]
    public static let fast: MessageSummaryItems = [.flags, .internalDate, .size]
    public static let full: MessageSummaryItems = [.body, .envelope, .flags, .internalDate, .size]
}
