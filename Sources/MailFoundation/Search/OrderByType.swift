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
// OrderByType.swift
//
// Ported from MailKit (C#) to Swift.
//

/// The field to sort search results by.
///
/// `OrderByType` specifies which message attribute should be used when sorting
/// search results. It is used in conjunction with ``SortOrder`` when constructing
/// ``OrderBy`` instances.
///
/// ## Overview
///
/// IMAP servers that support the SORT extension (RFC 5256) allow clients to request
/// search results sorted by various message attributes. This enumeration represents
/// the available sort fields.
///
/// ```swift
/// // Sort by message arrival date
/// let byArrival = try OrderBy(type: .arrival, order: .descending)
///
/// // Sort by sender's email address
/// let byFrom = try OrderBy(type: .from, order: .ascending)
///
/// // Sort by message size
/// let bySize = try OrderBy(type: .size, order: .descending)
/// ```
///
/// - Note: Some sort fields (such as ``annotation`` and ``modSeq``) require specific
///   IMAP extensions to be supported by the server.
///
/// ## See Also
/// - ``OrderBy``
/// - ``SortOrder``
public enum OrderByType: Sendable {
    /// Sort by an annotation value.
    ///
    /// This sort type is only available for use with IMAP servers that support the
    /// ANNOTATE extension as defined in RFC 5257.
    ///
    /// When using this type, the annotation entry and attribute must be specified
    /// via ``OrderBy/annotation(entry:attribute:order:)``.
    case annotation

    /// Sort by the message arrival date.
    ///
    /// This corresponds to the IMAP internal date, which is the date and time
    /// the message was received by the server.
    ///
    /// - Note: This is equivalent to the `ARRIVAL` sort key in RFC 5256.
    case arrival

    /// Sort by the first email address in the Cc header.
    ///
    /// - Note: This is equivalent to the `CC` sort key in RFC 5256.
    case cc

    /// Sort by the Date header.
    ///
    /// This sorts by the date the message was sent, as specified in the
    /// message's Date header.
    ///
    /// - Note: This is equivalent to the `DATE` sort key in RFC 5256.
    case date

    /// Sort by the display name of the first address in the From header.
    ///
    /// If the From header contains a display name (e.g., "John Doe <john@example.com>"),
    /// this sorts by that name. Otherwise, it falls back to the email address.
    ///
    /// - Note: This is equivalent to the `DISPLAYFROM` sort key in RFC 5957.
    case displayFrom

    /// Sort by the display name of the first address in the To header.
    ///
    /// If the To header contains a display name, this sorts by that name.
    /// Otherwise, it falls back to the email address.
    ///
    /// - Note: This is equivalent to the `DISPLAYTO` sort key in RFC 5957.
    case displayTo

    /// Sort by the first email address in the From header.
    ///
    /// - Note: This is equivalent to the `FROM` sort key in RFC 5256.
    case from

    /// Sort by the modification sequence number.
    ///
    /// This is only available for use with IMAP servers that support the
    /// CONDSTORE extension as defined in RFC 4551.
    ///
    /// - Note: This is equivalent to the `MODSEQ` sort key.
    case modSeq

    /// Sort by the message size in octets.
    ///
    /// - Note: This is equivalent to the `SIZE` sort key in RFC 5256.
    case size

    /// Sort by the message Subject header.
    ///
    /// The server normalizes the subject by removing leading "Re:" and similar
    /// prefixes before sorting.
    ///
    /// - Note: This is equivalent to the `SUBJECT` sort key in RFC 5256.
    case subject

    /// Sort by the first email address in the To header.
    ///
    /// - Note: This is equivalent to the `TO` sort key in RFC 5256.
    case to
}
