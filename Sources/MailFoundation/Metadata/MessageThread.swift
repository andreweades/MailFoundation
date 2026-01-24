//
// MessageThread.swift
//
// Ported from MailKit (C#) to Swift.
//

public struct MessageThread: Sendable, Equatable {
    public let message: MessageSummary?
    public let uniqueId: UniqueId?
    public let children: [MessageThread]

    public init(message: MessageSummary?, children: [MessageThread] = []) {
        self.message = message
        if let message, let uid = message.uniqueId, uid.isValid {
            self.uniqueId = uid
        } else {
            self.uniqueId = nil
        }
        self.children = children
    }

    public init(uniqueId: UniqueId?, children: [MessageThread] = []) {
        self.message = nil
        self.uniqueId = uniqueId
        self.children = children
    }
}
