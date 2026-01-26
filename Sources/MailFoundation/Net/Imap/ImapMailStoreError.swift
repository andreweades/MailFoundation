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
// ImapMailStoreError.swift
//
// Store-level IMAP errors.
//

/// Errors that can occur when using an IMAP mail store.
///
/// These errors represent high-level problems with mail store operations,
/// as opposed to protocol-level IMAP errors.
///
/// ## See Also
///
/// - ``ImapMailStore``
/// - ``AsyncImapMailStore``
public enum ImapMailStoreError: Error, Sendable, Equatable {
    /// No folder is currently selected.
    ///
    /// This error occurs when attempting an operation that requires a selected
    /// folder (such as SEARCH, FETCH, or STORE) without first opening a folder
    /// using `openFolder(_:access:)` or `openInbox(access:)`.
    ///
    /// ## Resolution
    ///
    /// ```swift
    /// // Open a folder before performing message operations
    /// try store.openInbox(access: .readOnly)
    /// let results = try store.search(.all) // Now this works
    /// ```
    case noSelectedFolder
}
