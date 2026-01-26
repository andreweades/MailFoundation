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
// OrderBy.swift
//
// Ported from MailKit (C#) to Swift.
//

/// Errors that can occur when constructing an ``OrderBy`` instance.
public enum OrderByError: Error, Sendable, Equatable {
    /// The sort order cannot be ``SortOrder/none``.
    ///
    /// This error is thrown when attempting to create an ``OrderBy`` instance
    /// with a sort order of ``SortOrder/none``.
    case invalidSortOrder
}

/// Specifies an annotation entry and attribute for sorting by annotation values.
///
/// `OrderByAnnotation` is used with ``OrderBy/annotation(entry:attribute:order:)``
/// to specify which annotation value should be used for sorting search results.
///
/// ## Overview
///
/// IMAP servers that support the ANNOTATE extension (RFC 5257) allow messages
/// to have arbitrary annotations. This structure specifies which annotation
/// entry and attribute to use when sorting.
///
/// ```swift
/// // Sort by a custom annotation
/// let annotation = OrderByAnnotation(entry: "/comment", attribute: "value.priv")
/// let sortSpec = try OrderBy(annotation: annotation, order: .ascending)
/// ```
///
/// - Note: Annotation-based sorting requires server support for the ANNOTATE extension.
public struct OrderByAnnotation: Sendable, Equatable {
    /// The annotation entry path (e.g., "/comment" or "/flags").
    public let entry: String

    /// The annotation attribute (e.g., "value.priv" or "value.shared").
    public let attribute: String

    /// Creates a new annotation specification for sorting.
    ///
    /// - Parameters:
    ///   - entry: The annotation entry path.
    ///   - attribute: The annotation attribute to sort by.
    public init(entry: String, attribute: String) {
        self.entry = entry
        self.attribute = attribute
    }
}

/// Specifies a sort order for search results.
///
/// You can combine multiple `OrderBy` rules to specify the sort order that
/// IMAP SORT operations should return results in.
///
/// ## Overview
///
/// The `OrderBy` structure pairs an ``OrderByType`` with a ``SortOrder`` to
/// define how search results should be sorted. Multiple `OrderBy` instances
/// can be combined to create a multi-level sort.
///
/// ```swift
/// // Sort by date descending (newest first)
/// let dateSort = OrderBy.reverseDate
///
/// // Sort by sender ascending, then by date descending
/// let multiSort = [OrderBy.from, OrderBy.reverseDate]
///
/// // Custom sort specification
/// let customSort = try OrderBy(type: .subject, order: .ascending)
/// ```
///
/// ## Pre-defined Sort Orders
///
/// For convenience, `OrderBy` provides static properties for common sort configurations:
///
/// | Property | Description |
/// | --- | --- |
/// | ``arrival`` | Sort by arrival date, ascending (oldest first) |
/// | ``reverseArrival`` | Sort by arrival date, descending (newest first) |
/// | ``date`` | Sort by sent date, ascending |
/// | ``reverseDate`` | Sort by sent date, descending |
/// | ``from`` | Sort by sender email, ascending |
/// | ``reverseFrom`` | Sort by sender email, descending |
/// | ``subject`` | Sort by subject, ascending |
/// | ``reverseSubject`` | Sort by subject, descending |
/// | ``size`` | Sort by message size, ascending |
/// | ``reverseSize`` | Sort by message size, descending |
///
/// - Note: Sorting requires the IMAP server to support the SORT extension (RFC 5256).
///
/// ## See Also
/// - ``OrderByType``
/// - ``SortOrder``
public struct OrderBy: Sendable, Equatable {
    /// The field to sort by.
    ///
    /// Specifies which message attribute (date, sender, subject, etc.) should
    /// be used for sorting search results.
    public let type: OrderByType

    /// The sort order (ascending or descending).
    ///
    /// Determines whether results are sorted in ascending or descending order
    /// based on the value of ``type``.
    public let order: SortOrder

    /// The annotation specification for annotation-based sorting.
    ///
    /// This property is only set when ``type`` is ``OrderByType/annotation``.
    /// For all other sort types, this is `nil`.
    public let annotation: OrderByAnnotation?

    /// Creates a new sort specification with the given type and order.
    ///
    /// - Parameters:
    ///   - type: The field to sort by.
    ///   - order: The sort order. Must not be ``SortOrder/none``.
    ///
    /// - Throws: ``OrderByError/invalidSortOrder`` if `order` is ``SortOrder/none``.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Sort by arrival date, newest first
    /// let sortSpec = try OrderBy(type: .arrival, order: .descending)
    ///
    /// // Sort by sender, alphabetically
    /// let senderSort = try OrderBy(type: .from, order: .ascending)
    /// ```
    public init(type: OrderByType, order: SortOrder) throws {
        guard order != .none else { throw OrderByError.invalidSortOrder }
        self.type = type
        self.order = order
        self.annotation = nil
    }

    /// Creates a new sort specification for sorting by annotation values.
    ///
    /// - Parameters:
    ///   - annotation: The annotation entry and attribute to sort by.
    ///   - order: The sort order. Must not be ``SortOrder/none``.
    ///
    /// - Throws: ``OrderByError/invalidSortOrder`` if `order` is ``SortOrder/none``.
    ///
    /// - Note: This requires server support for the ANNOTATE extension (RFC 5257).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let annotation = OrderByAnnotation(entry: "/comment", attribute: "value.priv")
    /// let sortSpec = try OrderBy(annotation: annotation, order: .ascending)
    /// ```
    public init(annotation: OrderByAnnotation, order: SortOrder) throws {
        guard order != .none else { throw OrderByError.invalidSortOrder }
        self.type = .annotation
        self.order = order
        self.annotation = annotation
    }
}

// MARK: - Pre-defined Sort Orders

public extension OrderBy {
    /// Sort results by arrival date in ascending order (oldest first).
    ///
    /// - Note: This is equivalent to the `ARRIVAL` sort key in RFC 5256.
    static let arrival = try! OrderBy(type: .arrival, order: .ascending)

    /// Sort results by arrival date in descending order (newest first).
    ///
    /// - Note: This is equivalent to the `REVERSE ARRIVAL` sort key in RFC 5256.
    static let reverseArrival = try! OrderBy(type: .arrival, order: .descending)

    /// Sort results by the first email address in the Cc header in ascending order.
    ///
    /// - Note: This is equivalent to the `CC` sort key in RFC 5256.
    static let cc = try! OrderBy(type: .cc, order: .ascending)

    /// Sort results by the first email address in the Cc header in descending order.
    ///
    /// - Note: This is equivalent to the `REVERSE CC` sort key in RFC 5256.
    static let reverseCc = try! OrderBy(type: .cc, order: .descending)

    /// Sort results by the sent date in ascending order (oldest first).
    ///
    /// - Note: This is equivalent to the `DATE` sort key in RFC 5256.
    static let date = try! OrderBy(type: .date, order: .ascending)

    /// Sort results by the sent date in descending order (newest first).
    ///
    /// - Note: This is equivalent to the `REVERSE DATE` sort key in RFC 5256.
    static let reverseDate = try! OrderBy(type: .date, order: .descending)

    /// Sort results by the first email address in the From header in ascending order.
    ///
    /// - Note: This is equivalent to the `FROM` sort key in RFC 5256.
    static let from = try! OrderBy(type: .from, order: .ascending)

    /// Sort results by the first email address in the From header in descending order.
    ///
    /// - Note: This is equivalent to the `REVERSE FROM` sort key in RFC 5256.
    static let reverseFrom = try! OrderBy(type: .from, order: .descending)

    /// Sort results by the first display name in the From header in ascending order.
    ///
    /// - Note: This is equivalent to the `DISPLAYFROM` sort key in RFC 5957.
    static let displayFrom = try! OrderBy(type: .displayFrom, order: .ascending)

    /// Sort results by the first display name in the From header in descending order.
    ///
    /// - Note: This is equivalent to the `REVERSE DISPLAYFROM` sort key in RFC 5957.
    static let reverseDisplayFrom = try! OrderBy(type: .displayFrom, order: .descending)

    /// Sort results by the message size in ascending order (smallest first).
    ///
    /// - Note: This is equivalent to the `SIZE` sort key in RFC 5256.
    static let size = try! OrderBy(type: .size, order: .ascending)

    /// Sort results by the message size in descending order (largest first).
    ///
    /// - Note: This is equivalent to the `REVERSE SIZE` sort key in RFC 5256.
    static let reverseSize = try! OrderBy(type: .size, order: .descending)

    /// Sort results by the Subject header in ascending order (alphabetical).
    ///
    /// - Note: This is equivalent to the `SUBJECT` sort key in RFC 5256.
    static let subject = try! OrderBy(type: .subject, order: .ascending)

    /// Sort results by the Subject header in descending order (reverse alphabetical).
    ///
    /// - Note: This is equivalent to the `REVERSE SUBJECT` sort key in RFC 5256.
    static let reverseSubject = try! OrderBy(type: .subject, order: .descending)

    /// Sort results by the first email address in the To header in ascending order.
    ///
    /// - Note: This is equivalent to the `TO` sort key in RFC 5256.
    static let to = try! OrderBy(type: .to, order: .ascending)

    /// Sort results by the first email address in the To header in descending order.
    ///
    /// - Note: This is equivalent to the `REVERSE TO` sort key in RFC 5256.
    static let reverseTo = try! OrderBy(type: .to, order: .descending)

    /// Sort results by the first display name in the To header in ascending order.
    ///
    /// - Note: This is equivalent to the `DISPLAYTO` sort key in RFC 5957.
    static let displayTo = try! OrderBy(type: .displayTo, order: .ascending)

    /// Sort results by the first display name in the To header in descending order.
    ///
    /// - Note: This is equivalent to the `REVERSE DISPLAYTO` sort key in RFC 5957.
    static let reverseDisplayTo = try! OrderBy(type: .displayTo, order: .descending)

    /// Creates a sort specification for sorting by annotation values.
    ///
    /// - Parameters:
    ///   - entry: The annotation entry path (e.g., "/comment").
    ///   - attribute: The annotation attribute (e.g., "value.priv").
    ///   - order: The sort order. Must not be ``SortOrder/none``.
    ///
    /// - Returns: An ``OrderBy`` configured for annotation-based sorting.
    ///
    /// - Throws: ``OrderByError/invalidSortOrder`` if `order` is ``SortOrder/none``.
    ///
    /// - Note: This requires server support for the ANNOTATE extension (RFC 5257).
    ///
    /// ## Example
    ///
    /// ```swift
    /// let sortSpec = try OrderBy.annotation(
    ///     entry: "/comment",
    ///     attribute: "value.priv",
    ///     order: .ascending
    /// )
    /// ```
    static func annotation(entry: String, attribute: String, order: SortOrder) throws -> OrderBy {
        try OrderBy(annotation: OrderByAnnotation(entry: entry, attribute: attribute), order: order)
    }
}
