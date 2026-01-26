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
// ImapSort.swift
//
// IMAP SORT command helpers.
//

public enum ImapSortError: Error, Sendable, Equatable {
    case emptyOrderBy
    case missingAnnotation
    case sortNotSupported
    case sortDisplayNotSupported
    case annotationNotSupported
    case unsupportedOrderByType(OrderByType)
}

public enum ImapSort {
    public static func validateCapabilities(orderBy: [OrderBy], capabilities: ImapCapabilities?) throws {
        guard let capabilities else { return }
        guard capabilities.supports("SORT") else { throw ImapSortError.sortNotSupported }

        if orderBy.contains(where: { $0.type == .displayFrom || $0.type == .displayTo }) {
            if !(capabilities.supports("SORT=DISPLAY") || capabilities.supports("SORTDISPLAY")) {
                throw ImapSortError.sortDisplayNotSupported
            }
        }

        if orderBy.contains(where: { $0.type == .annotation }) {
            if !(capabilities.supports("ANNOTATE") || capabilities.supports("ANNOTATION")) {
                throw ImapSortError.annotationNotSupported
            }
        }
    }

    public static func buildArguments(
        orderBy: [OrderBy],
        query: SearchQuery,
        charset: String = "UTF-8"
    ) throws -> String {
        let order = try buildOrderBy(orderBy)
        return "\(order) \(charset) \(query.optimized().serialize())"
    }

    public static func buildArguments(
        orderBy: [OrderBy],
        criteria: String,
        charset: String = "UTF-8"
    ) throws -> String {
        let order = try buildOrderBy(orderBy)
        return "\(order) \(charset) \(criteria)"
    }

    public static func buildOrderBy(_ orderBy: [OrderBy]) throws -> String {
        guard !orderBy.isEmpty else { throw ImapSortError.emptyOrderBy }
        var tokens: [String] = []

        for rule in orderBy {
            var parts: [String] = []
            if rule.order == .descending {
                parts.append("REVERSE")
            }

            switch rule.type {
            case .annotation:
                guard let annotation = rule.annotation else { throw ImapSortError.missingAnnotation }
                parts.append("ANNOTATION")
                parts.append(annotation.entry)
                parts.append(annotation.attribute)
            case .arrival:
                parts.append("ARRIVAL")
            case .cc:
                parts.append("CC")
            case .date:
                parts.append("DATE")
            case .displayFrom:
                parts.append("DISPLAYFROM")
            case .displayTo:
                parts.append("DISPLAYTO")
            case .from:
                parts.append("FROM")
            case .size:
                parts.append("SIZE")
            case .subject:
                parts.append("SUBJECT")
            case .to:
                parts.append("TO")
            case .modSeq:
                throw ImapSortError.unsupportedOrderByType(.modSeq)
            }

            tokens.append(parts.joined(separator: " "))
        }

        return "(\(tokens.joined(separator: " ")))"
    }
}
