//
// HeaderSet.swift
//
// Ported from MailKit HeaderSet.
//

import Foundation
import SwiftMimeKit

public enum HeaderSetError: Error, Sendable, Equatable {
    case readOnly
    case invalidHeaderField(String)
    case invalidHeaderId
}

public struct HeaderSet: Sendable, Equatable, Sequence {
    private static let atomSafeCharacters = "!#$%&'*+-/=?^_`{|}~"
    private static let invariantLocale = Locale(identifier: "en_US_POSIX")

    private var storage: Set<String>
    private var ordered: [String]
    private var readOnly: Bool
    private var excludeStorage: Bool

    public static let all = HeaderSet(exclude: true, isReadOnly: true)
    public static let envelope = HeaderSet.makePreset(headers: [
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
    ])
    public static let references = HeaderSet.makePreset(headers: [.references])

    public init() {
        self.storage = []
        self.ordered = []
        self.readOnly = false
        self.excludeStorage = false
    }

    public init(headers: [HeaderId], exclude: Bool = false, isReadOnly: Bool = false) throws {
        self.storage = []
        self.ordered = []
        self.readOnly = false
        self.excludeStorage = exclude
        try addRange(headers)
        self.readOnly = isReadOnly
    }

    public init(headers: [String], exclude: Bool = false, isReadOnly: Bool = false) throws {
        self.storage = []
        self.ordered = []
        self.readOnly = false
        self.excludeStorage = exclude
        try addRange(headers)
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
        excludeStorage
    }

    public mutating func setExclude(_ value: Bool) throws {
        try checkReadOnly()
        excludeStorage = value
    }

    public func contains(_ header: String) -> Bool {
        storage.contains(normalize(header))
    }

    public func contains(_ header: HeaderId) -> Bool {
        guard header != .unknown else { return false }
        return storage.contains(normalize(header.headerName))
    }

    @discardableResult
    public mutating func add(_ header: HeaderId) throws -> Bool {
        guard header != .unknown else {
            throw HeaderSetError.invalidHeaderId
        }
        try checkReadOnly()
        return insert(normalize(header.headerName))
    }

    @discardableResult
    public mutating func add(_ header: String) throws -> Bool {
        guard HeaderSet.isValid(header) else {
            throw HeaderSetError.invalidHeaderField(header)
        }
        try checkReadOnly()
        return insert(normalize(header))
    }

    public mutating func addRange(_ headers: [HeaderId]) throws {
        try checkReadOnly()
        for header in headers {
            _ = try add(header)
        }
    }

    public mutating func addRange(_ headers: [String]) throws {
        try checkReadOnly()
        for header in headers {
            _ = try add(header)
        }
    }

    @discardableResult
    public mutating func remove(_ header: HeaderId) throws -> Bool {
        guard header != .unknown else {
            throw HeaderSetError.invalidHeaderId
        }
        try checkReadOnly()
        return removeNormalized(normalize(header.headerName))
    }

    @discardableResult
    public mutating func remove(_ header: String) throws -> Bool {
        try checkReadOnly()
        return removeNormalized(normalize(header))
    }

    public mutating func clear() throws {
        try checkReadOnly()
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

    @discardableResult
    private mutating func insert(_ header: String) -> Bool {
        guard !storage.contains(header) else { return false }
        storage.insert(header)
        ordered.append(header)
        return true
    }

    @discardableResult
    private mutating func removeNormalized(_ header: String) -> Bool {
        guard storage.contains(header) else { return false }
        storage.remove(header)
        ordered.removeAll { $0 == header }
        return true
    }

    private func normalize(_ header: String) -> String {
        HeaderSet.normalizeHeader(header)
    }

    private static func normalizeHeader(_ header: String) -> String {
        header.uppercased(with: HeaderSet.invariantLocale)
    }

    private func checkReadOnly() throws {
        if readOnly {
            throw HeaderSetError.readOnly
        }
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

    private static func makePreset(headers: [HeaderId]) -> HeaderSet {
        var set = HeaderSet()
        for header in headers where header != .unknown {
            set.insert(normalizeHeader(header.headerName))
        }
        set.readOnly = true
        return set
    }

    private static func isAsciiAtom(_ byte: UInt8) -> Bool {
        if byte >= 48, byte <= 57 { return true }
        if byte >= 65, byte <= 90 { return true }
        if byte >= 97, byte <= 122 { return true }
        return atomSafeCharacters.utf8.contains(byte)
    }
}
