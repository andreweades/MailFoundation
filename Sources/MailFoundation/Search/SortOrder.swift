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
// SortOrder.swift
//
// Ported from MailKit (C#) to Swift.
//

/// An enumeration of sort orders for search results.
///
/// Sort order specifies whether results should be returned in ascending or descending order
/// based on the field specified by an ``OrderBy`` instance.
///
/// ## Overview
///
/// Use `SortOrder` in conjunction with ``OrderByType`` when constructing ``OrderBy`` instances
/// to specify how search results should be sorted.
///
/// ```swift
/// // Sort by date in descending order (newest first)
/// let sortSpec = try OrderBy(type: .date, order: .descending)
///
/// // Sort by sender in ascending order (alphabetical)
/// let senderSort = try OrderBy(type: .from, order: .ascending)
/// ```
///
/// - Note: The `none` case is typically used internally and should not be passed to
///   ``OrderBy/init(type:order:)`` as it will throw an ``OrderByError/invalidSortOrder`` error.
public enum SortOrder: Sendable {
    /// No sorting order specified.
    ///
    /// This value is primarily used as a sentinel and should not be passed to
    /// ``OrderBy/init(type:order:)`` constructors.
    case none

    /// Sort in ascending order.
    ///
    /// For text fields, this means alphabetical order (A to Z).
    /// For date fields, this means chronological order (oldest to newest).
    /// For numeric fields, this means smallest to largest.
    case ascending

    /// Sort in descending order.
    ///
    /// For text fields, this means reverse alphabetical order (Z to A).
    /// For date fields, this means reverse chronological order (newest to oldest).
    /// For numeric fields, this means largest to smallest.
    case descending
}
