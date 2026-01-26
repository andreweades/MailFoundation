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
// Pop3MailStoreError.swift
//
// Store-level POP3 errors.
//

/// Errors that can occur at the mail store level.
///
/// These errors indicate problems with the overall store state rather than
/// individual command failures.
///
/// ## See Also
///
/// - ``Pop3CommandError`` for command-level errors
/// - ``Pop3FolderError`` for folder-level errors
public enum Pop3MailStoreError: Error, Sendable, Equatable {
    /// No folder is currently selected.
    ///
    /// This error is thrown when attempting to perform operations that require
    /// a selected folder (like `stat()`, `list()`, `retr()`) without first
    /// opening the INBOX.
    ///
    /// ## Resolution
    ///
    /// Call ``Pop3MailStore/openInbox(access:)`` or authenticate (which automatically
    /// opens the INBOX) before performing message operations.
    ///
    /// ```swift
    /// // Either authenticate (opens INBOX automatically)
    /// try store.authenticate(user: "user", password: "pass")
    ///
    /// // Or explicitly open the inbox
    /// try store.openInbox()
    ///
    /// // Now operations will work
    /// let stat = try store.stat()
    /// ```
    case noSelectedFolder
}
