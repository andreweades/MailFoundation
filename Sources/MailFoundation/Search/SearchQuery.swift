//
// SearchQuery.swift
//
// Basic IMAP search query builder.
//

import Foundation

public struct SearchQuery: Sendable, CustomStringConvertible {
    public indirect enum Term: Sendable {
        case all
        case answered
        case deleted
        case flagged
        case seen
        case draft
        case recent
        case new
        case old
        case unseen
        case unanswered
        case undraft
        case from(String)
        case to(String)
        case cc(String)
        case bcc(String)
        case subject(String)
        case body(String)
        case text(String)
        case header(String, String)
        case keyword(String)
        case unkeyword(String)
        case on(Date)
        case since(Date)
        case before(Date)
        case sentOn(Date)
        case sentSince(Date)
        case sentBefore(Date)
        case larger(Int)
        case smaller(Int)
        case uid(String)
        case not(Term)
        case or(Term, Term)
        case and([Term])
        case raw(String)
    }

    public let term: Term

    public init(_ term: Term) {
        self.term = term
    }

    public var description: String {
        serialize()
    }

    public func serialize() -> String {
        Self.serialize(term)
    }

    public func and(_ other: SearchQuery) -> SearchQuery {
        SearchQuery(.and([term, other.term]))
    }

    public func or(_ other: SearchQuery) -> SearchQuery {
        SearchQuery(.or(term, other.term))
    }

    public func not() -> SearchQuery {
        SearchQuery(.not(term))
    }
}

public extension SearchQuery {
    static var all: SearchQuery { SearchQuery(.all) }
    static var answered: SearchQuery { SearchQuery(.answered) }
    static var deleted: SearchQuery { SearchQuery(.deleted) }
    static var flagged: SearchQuery { SearchQuery(.flagged) }
    static var seen: SearchQuery { SearchQuery(.seen) }
    static var draft: SearchQuery { SearchQuery(.draft) }
    static var recent: SearchQuery { SearchQuery(.recent) }
    static var new: SearchQuery { SearchQuery(.new) }
    static var old: SearchQuery { SearchQuery(.old) }
    static var unseen: SearchQuery { SearchQuery(.unseen) }
    static var unanswered: SearchQuery { SearchQuery(.unanswered) }
    static var undraft: SearchQuery { SearchQuery(.undraft) }

    static func from(_ value: String) -> SearchQuery { SearchQuery(.from(value)) }
    static func to(_ value: String) -> SearchQuery { SearchQuery(.to(value)) }
    static func cc(_ value: String) -> SearchQuery { SearchQuery(.cc(value)) }
    static func bcc(_ value: String) -> SearchQuery { SearchQuery(.bcc(value)) }
    static func subject(_ value: String) -> SearchQuery { SearchQuery(.subject(value)) }
    static func body(_ value: String) -> SearchQuery { SearchQuery(.body(value)) }
    static func text(_ value: String) -> SearchQuery { SearchQuery(.text(value)) }
    static func header(_ name: String, _ value: String) -> SearchQuery { SearchQuery(.header(name, value)) }
    static func keyword(_ value: String) -> SearchQuery { SearchQuery(.keyword(value)) }
    static func unkeyword(_ value: String) -> SearchQuery { SearchQuery(.unkeyword(value)) }

    static func on(_ date: Date) -> SearchQuery { SearchQuery(.on(date)) }
    static func since(_ date: Date) -> SearchQuery { SearchQuery(.since(date)) }
    static func before(_ date: Date) -> SearchQuery { SearchQuery(.before(date)) }
    static func sentOn(_ date: Date) -> SearchQuery { SearchQuery(.sentOn(date)) }
    static func sentSince(_ date: Date) -> SearchQuery { SearchQuery(.sentSince(date)) }
    static func sentBefore(_ date: Date) -> SearchQuery { SearchQuery(.sentBefore(date)) }

    static func larger(_ size: Int) -> SearchQuery { SearchQuery(.larger(size)) }
    static func smaller(_ size: Int) -> SearchQuery { SearchQuery(.smaller(size)) }
    static func uid(_ set: String) -> SearchQuery { SearchQuery(.uid(set)) }
    static func uid(_ set: UniqueIdSet) -> SearchQuery { SearchQuery(.uid(set.description)) }
    static func uid(_ ids: [UniqueId]) -> SearchQuery { SearchQuery(.uid(UniqueIdSet(ids).description)) }

    static func not(_ query: SearchQuery) -> SearchQuery { SearchQuery(.not(query.term)) }
    static func or(_ lhs: SearchQuery, _ rhs: SearchQuery) -> SearchQuery { SearchQuery(.or(lhs.term, rhs.term)) }
    static func and(_ queries: [SearchQuery]) -> SearchQuery { SearchQuery(.and(queries.map { $0.term })) }
    static func raw(_ value: String) -> SearchQuery { SearchQuery(.raw(value)) }
}

private extension SearchQuery {
    static func serialize(_ term: Term) -> String {
        switch term {
        case .all:
            return "ALL"
        case .answered:
            return "ANSWERED"
        case .deleted:
            return "DELETED"
        case .flagged:
            return "FLAGGED"
        case .seen:
            return "SEEN"
        case .draft:
            return "DRAFT"
        case .recent:
            return "RECENT"
        case .new:
            return "NEW"
        case .old:
            return "OLD"
        case .unseen:
            return "UNSEEN"
        case .unanswered:
            return "UNANSWERED"
        case .undraft:
            return "UNDRAFT"
        case let .from(value):
            return "FROM \(quote(value))"
        case let .to(value):
            return "TO \(quote(value))"
        case let .cc(value):
            return "CC \(quote(value))"
        case let .bcc(value):
            return "BCC \(quote(value))"
        case let .subject(value):
            return "SUBJECT \(quote(value))"
        case let .body(value):
            return "BODY \(quote(value))"
        case let .text(value):
            return "TEXT \(quote(value))"
        case let .header(name, value):
            return "HEADER \(quote(name)) \(quote(value))"
        case let .keyword(value):
            return "KEYWORD \(quote(value))"
        case let .unkeyword(value):
            return "UNKEYWORD \(quote(value))"
        case let .on(date):
            return "ON \(formatDate(date))"
        case let .since(date):
            return "SINCE \(formatDate(date))"
        case let .before(date):
            return "BEFORE \(formatDate(date))"
        case let .sentOn(date):
            return "SENTON \(formatDate(date))"
        case let .sentSince(date):
            return "SENTSINCE \(formatDate(date))"
        case let .sentBefore(date):
            return "SENTBEFORE \(formatDate(date))"
        case let .larger(size):
            return "LARGER \(size)"
        case let .smaller(size):
            return "SMALLER \(size)"
        case let .uid(value):
            return "UID \(value)"
        case let .not(inner):
            let rendered = serialize(inner)
            if needsGrouping(inner) {
                return "NOT (\(rendered))"
            }
            return "NOT \(rendered)"
        case let .or(lhs, rhs):
            let left = serialize(lhs)
            let right = serialize(rhs)
            let leftRendered = needsGrouping(lhs) ? "(\(left))" : left
            let rightRendered = needsGrouping(rhs) ? "(\(right))" : right
            return "OR \(leftRendered) \(rightRendered)"
        case let .and(terms):
            if terms.isEmpty {
                return "ALL"
            }
            return terms.map { serialize($0) }.joined(separator: " ")
        case let .raw(value):
            return value
        }
    }

    static func quote(_ value: String) -> String {
        var result = "\""
        for ch in value {
            if ch == "\\" || ch == "\"" {
                result.append("\\")
            }
            result.append(ch)
        }
        result.append("\"")
        return result
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd-MMM-yyyy"
        return formatter.string(from: date)
    }

    static func needsGrouping(_ term: Term) -> Bool {
        switch term {
        case .and(let terms):
            return terms.count > 1
        case .or:
            return true
        default:
            return false
        }
    }
}
