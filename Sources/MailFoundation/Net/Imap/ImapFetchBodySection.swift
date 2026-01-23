//
// ImapFetchBodySection.swift
//
// Helpers for building BODY[] FETCH items.
//

public struct ImapFetchPartial: Sendable, Equatable {
    public let start: Int
    public let length: Int

    public init(start: Int, length: Int) {
        precondition(start >= 0, "Partial start must be non-negative.")
        precondition(length > 0, "Partial length must be positive.")
        self.start = start
        self.length = length
    }
}

public enum ImapFetchBodySubsection: Sendable, Equatable {
    case header
    case headerFields([String])
    case headerFieldsNot([String])
    case text
    case mime

    fileprivate func serialize() -> String {
        switch self {
        case .header:
            return "HEADER"
        case .headerFields(let fields):
            return "HEADER.FIELDS (\(fields.joined(separator: " ")))"
        case .headerFieldsNot(let fields):
            return "HEADER.FIELDS.NOT (\(fields.joined(separator: " ")))"
        case .text:
            return "TEXT"
        case .mime:
            return "MIME"
        }
    }
}

public struct ImapFetchBodySection: Sendable, Equatable {
    public let part: [Int]
    public let subsection: ImapFetchBodySubsection?

    public init(part: [Int] = [], subsection: ImapFetchBodySubsection? = nil) {
        self.part = part
        self.subsection = subsection
    }

    public static var header: ImapFetchBodySection {
        ImapFetchBodySection(subsection: .header)
    }

    public static func headerFields(_ fields: [String]) -> ImapFetchBodySection {
        ImapFetchBodySection(subsection: .headerFields(fields))
    }

    public static func headerFieldsNot(_ fields: [String]) -> ImapFetchBodySection {
        ImapFetchBodySection(subsection: .headerFieldsNot(fields))
    }

    public static var text: ImapFetchBodySection {
        ImapFetchBodySection(subsection: .text)
    }

    public static var mime: ImapFetchBodySection {
        ImapFetchBodySection(subsection: .mime)
    }

    public func serialize() -> String {
        var result = ""
        if !part.isEmpty {
            result = part.map { String($0) }.joined(separator: ".")
        }
        if let subsection {
            let suffix = subsection.serialize()
            if result.isEmpty {
                result = suffix
            } else {
                result += ".\(suffix)"
            }
        }
        return result
    }
}

public enum ImapFetchBody {
    public static func section(
        _ section: ImapFetchBodySection? = nil,
        peek: Bool = false,
        partial: ImapFetchPartial? = nil
    ) -> String {
        let base = peek ? "BODY.PEEK" : "BODY"
        let sectionText = section?.serialize() ?? ""
        var result = "\(base)[\(sectionText)]"
        if let partial {
            result += "<\(partial.start).\(partial.length)>"
        }
        return result
    }
}
