import Foundation
import Testing
@testable import MailFoundation

private func makeSummary(
    sequence: Int,
    subject: String? = nil,
    from: [ImapAddress] = [],
    to: [ImapAddress] = [],
    cc: [ImapAddress] = [],
    date: Date? = nil,
    size: Int? = nil,
    modSeq: UInt64? = nil
) -> MessageSummary {
    let envelope = subject == nil && from.isEmpty && to.isEmpty && cc.isEmpty && date == nil ? nil : ImapEnvelope(
        date: date,
        subject: subject,
        from: from,
        sender: [],
        replyTo: [],
        to: to,
        cc: cc,
        bcc: [],
        inReplyTo: nil,
        messageId: nil
    )

    return MessageSummary(
        sequence: sequence,
        items: .none,
        size: size,
        modSeq: modSeq,
        envelope: envelope
    )
}

private func mailbox(_ name: String?, _ address: String) -> ImapAddress {
    let parts = address.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
    let mailbox = String(parts.first ?? "")
    let host = parts.count > 1 ? String(parts[1]) : nil
    return .mailbox(ImapMailboxAddress(name: name, route: nil, mailbox: mailbox, host: host))
}

private func firstMailboxName(_ summary: MessageSummary) -> String {
    guard let first = summary.envelope?.from.first else { return "" }
    switch first {
    case .mailbox(let mailbox):
        return mailbox.name ?? ""
    case .group:
        return ""
    }
}

@Test("MessageSorter sorts by arrival index")
func messageSorterArrival() throws {
    let messages = [
        makeSummary(sequence: 3),
        makeSummary(sequence: 1),
        makeSummary(sequence: 2)
    ]

    let sorted = try MessageSorter.sort(messages, orderBy: [.arrival])
    #expect(sorted.map { $0.sequence } == [1, 2, 3])
}

@Test("MessageSorter sorts by subject")
func messageSorterSubject() throws {
    let messages = [
        makeSummary(sequence: 1, subject: "b"),
        makeSummary(sequence: 2, subject: "A")
    ]

    let sorted = try MessageSorter.sort(messages, orderBy: [.subject])
    #expect(sorted.map { $0.envelope?.subject ?? "" } == ["A", "b"])
}

@Test("MessageSorter sorts by from display name")
func messageSorterDisplayFrom() throws {
    let messages = [
        makeSummary(sequence: 1, from: [mailbox("Zoey", "z@example.com")]),
        makeSummary(sequence: 2, from: [mailbox("amy", "a@example.com")])
    ]

    let sorted = try MessageSorter.sort(messages, orderBy: [.displayFrom])
    #expect(sorted.map { firstMailboxName($0) } == ["amy", "Zoey"])
}

@Test("MessageSorter throws when envelope missing")
func messageSorterMissingEnvelope() {
    let messages = [makeSummary(sequence: 1)]
    #expect(throws: MessageSorterError.missingEnvelope) {
        _ = try MessageSorter.sort(messages, orderBy: [.subject])
    }
}

@Test("MessageSorter throws when size missing")
func messageSorterMissingSize() {
    let messages = [makeSummary(sequence: 1, subject: "a")]
    #expect(throws: MessageSorterError.missingSortData(.size)) {
        _ = try MessageSorter.sort(messages, orderBy: [.size])
    }
}

@Test("MessageSorter throws when orderBy is empty")
func messageSorterEmptyOrderBy() {
    let messages = [makeSummary(sequence: 1)]
    #expect(throws: MessageSorterError.emptyOrderBy) {
        _ = try MessageSorter.sort(messages, orderBy: [])
    }
}
