//
// HeaderSet.swift
//
// Ported from MailKit HeaderSet.
//

import Foundation
import SwiftMimeKit

public struct HeaderSet: Sendable, Equatable, Sequence {
    private static let atomSafeCharacters = "!#$%&'*+-/=?^_`{|}~"
    private static let invariantLocale = Locale(identifier: "en_US_POSIX")

    private var storage: Set<String>
    private var ordered: [String]
    private var readOnly: Bool
    private var excludeStorage: Bool

    public static let all = HeaderSet(exclude: true, isReadOnly: true)
    public static let envelope = HeaderSet(
        headers: [
            .sender,
            .from,
            .replyTo,
            .to,
            .cc,
            .bcc,
            .subject,
            .date,
            .messageId,
            .inReplyTo
        ],
        isReadOnly: true
    )
    public static let references = HeaderSet(headers: [.references], isReadOnly: true)

    public init() {
        self.storage = []
        self.ordered = []
        self.readOnly = false
        self.excludeStorage = false
    }

    public init(headers: [HeaderId], exclude: Bool = false, isReadOnly: Bool = false) {
        self.storage = []
        self.ordered = []
        self.readOnly = false
        self.excludeStorage = exclude
        addRange(headers)
        self.readOnly = isReadOnly
    }

    public init(headers: [String], exclude: Bool = false, isReadOnly: Bool = false) {
        self.storage = []
        self.ordered = []
        self.readOnly = false
        self.excludeStorage = exclude
        addRange(headers)
        self.readOnly = isReadOnly
    }

    private init(exclude: Bool, isReadOnly: Bool) {
        self.storage = []
        self.ordered = []
        self.readOnly = isReadOnly
        self.excludeStorage = exclude
    }

    public var count: Int {
        ordered.count
    }

    public var isEmpty: Bool {
        ordered.isEmpty
    }

    public var isReadOnly: Bool {
        readOnly
    }

    public var exclude: Bool {
        get { excludeStorage }
        set {
            checkReadOnly()
            excludeStorage = newValue
        }
    }

    public func contains(_ header: String) -> Bool {
        storage.contains(normalize(header))
    }

    public func contains(_ header: HeaderId) -> Bool {
        guard header != .unknown else { return false }
        return storage.contains(normalize(header.headerName))
    }

    public mutating func add(_ header: HeaderId) {
        precondition(header != .unknown, "HeaderId.unknown is not valid for HeaderSet.")
        checkReadOnly()
        insert(normalize(header.headerName))
    }

    public mutating func add(_ header: String) {
        precondition(HeaderSet.isValid(header), "The header field is invalid.")
        checkReadOnly()
        insert(normalize(header))
    }

    public mutating func addRange(_ headers: [HeaderId]) {
        for header in headers {
            add(header)
        }
    }

    public mutating func addRange(_ headers: [String]) {
        for header in headers {
            add(header)
        }
    }

    public mutating func remove(_ header: HeaderId) {
        precondition(header != .unknown, "HeaderId.unknown is not valid for HeaderSet.")
        checkReadOnly()
        removeNormalized(normalize(header.headerName))
    }

    public mutating func remove(_ header: String) {
        checkReadOnly()
        removeNormalized(normalize(header))
    }

    public mutating func clear() {
        checkReadOnly()
        storage.removeAll(keepingCapacity: true)
        ordered.removeAll(keepingCapacity: true)
    }

    public func makeIterator() -> IndexingIterator<[String]> {
        ordered.makeIterator()
    }

    public var orderedHeaders: [String] {
        ordered
    }

    public static func isValidFieldName(_ header: String) -> Bool {
        isValid(header)
    }

    private mutating func insert(_ header: String) {
        guard !storage.contains(header) else { return }
        storage.insert(header)
        ordered.append(header)
    }

    private mutating func removeNormalized(_ header: String) {
        guard storage.contains(header) else { return }
        storage.remove(header)
        ordered.removeAll { $0 == header }
    }

    private func normalize(_ header: String) -> String {
        header.uppercased(with: HeaderSet.invariantLocale)
    }

    private func checkReadOnly() {
        precondition(!readOnly, "HeaderSet is read-only.")
    }

    private static func isValid(_ header: String) -> Bool {
        guard !header.isEmpty else { return false }
        for scalar in header.unicodeScalars {
            if scalar.value < 127 {
                let byte = UInt8(scalar.value)
                if !isAsciiAtom(byte) {
                    return false
                }
            }
        }
        return true
    }

    private static func isAsciiAtom(_ byte: UInt8) -> Bool {
        if byte >= 48, byte <= 57 { return true }
        if byte >= 65, byte <= 90 { return true }
        if byte >= 97, byte <= 122 { return true }
        return atomSafeCharacters.utf8.contains(byte)
    }
}
