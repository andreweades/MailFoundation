//
// Author: Jeffrey Stedfast <jestedfa@microsoft.com>
//
// Copyright (c) 2013-2026 .NET Foundation and Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

//
// ImapFetchBodySection.swift
//
// Helpers for building BODY[] FETCH items.
//

public struct ImapFetchPartial: Sendable, Equatable, Hashable {
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

    public static func parse(_ text: String) -> ImapFetchBodySection? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ImapFetchBodySection() }
        let components = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !components.isEmpty else { return nil }

        var part: [Int] = []
        var subsectionParts: [Substring] = []
        var encounteredNonNumeric = false

        for component in components {
            if !encounteredNonNumeric, let value = Int(component), value > 0 {
                part.append(value)
            } else {
                encounteredNonNumeric = true
                subsectionParts.append(component)
            }
        }

        if subsectionParts.isEmpty {
            return ImapFetchBodySection(part: part, subsection: nil)
        }

        let subsectionText = subsectionParts.joined(separator: ".")
        guard let subsection = ImapFetchBodySubsection.parse(subsectionText) else {
            return nil
        }
        return ImapFetchBodySection(part: part, subsection: subsection)
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

private extension ImapFetchBodySubsection {
    static func parse(_ text: String) -> ImapFetchBodySubsection? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        if upper.hasPrefix("HEADER.FIELDS.NOT") {
            guard let fields = parseFieldList(from: trimmed, prefix: "HEADER.FIELDS.NOT") else { return nil }
            return .headerFieldsNot(fields)
        }
        if upper.hasPrefix("HEADER.FIELDS") {
            guard let fields = parseFieldList(from: trimmed, prefix: "HEADER.FIELDS") else { return nil }
            return .headerFields(fields)
        }
        if upper == "HEADER" {
            return .header
        }
        if upper == "TEXT" {
            return .text
        }
        if upper == "MIME" {
            return .mime
        }
        return nil
    }

    static func parseFieldList(from text: String, prefix: String) -> [String]? {
        let range = text.range(of: prefix, options: [.caseInsensitive, .anchored])
        guard let range else { return nil }
        let remainder = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard remainder.first == "(",
              let endIndex = remainder.lastIndex(of: ")") else {
            return nil
        }
        let inner = remainder[remainder.index(after: remainder.startIndex)..<endIndex]
        let fields = inner.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        return fields
    }
}
