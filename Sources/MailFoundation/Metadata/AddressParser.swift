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
// AddressParser.swift
//
// Address parsing helpers backed by MimeFoundation.
//

import MimeFoundation

/// Errors that can occur during address parsing.
public enum AddressParserError: Error, Sendable {
    /// No mailbox address was found in the parsed string.
    ///
    /// The input string may have been empty, contained only group addresses,
    /// or could not be parsed as a valid address.
    case noMailboxFound
}

/// A utility for parsing email addresses from strings.
///
/// `AddressParser` provides convenient methods for parsing RFC 5322 email addresses
/// from string representations. It supports both single mailbox addresses and
/// full address lists (which may include groups).
///
/// ## Topics
///
/// ### Parsing Methods
/// - ``parseList(_:)``
/// - ``parseMailbox(_:)``
///
/// ## Example
///
/// ```swift
/// // Parse a list of addresses
/// let list = try AddressParser.parseList("John <john@example.com>, Jane <jane@example.com>")
///
/// // Parse a single mailbox address
/// let mailbox = try AddressParser.parseMailbox("John Doe <john@example.com>")
/// print(mailbox.address)  // "john@example.com"
/// print(mailbox.name)     // "John Doe"
/// ```
public enum AddressParser {
    /// Parses an address list from a string.
    ///
    /// This method parses a comma-separated list of email addresses, which may
    /// include both individual mailbox addresses and group addresses.
    ///
    /// - Parameter value: The string containing email addresses to parse.
    /// - Returns: An `InternetAddressList` containing the parsed addresses.
    /// - Throws: An error if the string cannot be parsed as a valid address list.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let list = try AddressParser.parseList("John <john@example.com>, Jane <jane@example.com>")
    /// for address in list {
    ///     if let mailbox = address as? MailboxAddress {
    ///         print(mailbox.address)
    ///     }
    /// }
    /// ```
    public static func parseList(_ value: String) throws -> InternetAddressList {
        try InternetAddressList(parsing: value)
    }

    /// Parses a single mailbox address from a string.
    ///
    /// This method parses the string and returns the first mailbox address found.
    /// If the string contains multiple addresses, only the first mailbox is returned.
    /// Group addresses are skipped.
    ///
    /// - Parameter value: The string containing an email address to parse.
    /// - Returns: The first `MailboxAddress` found in the string.
    /// - Throws: ``AddressParserError/noMailboxFound`` if no mailbox address is found,
    ///   or an error if the string cannot be parsed.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let mailbox = try AddressParser.parseMailbox("\"John Doe\" <john@example.com>")
    /// print(mailbox.name)     // "John Doe"
    /// print(mailbox.address)  // "john@example.com"
    /// ```
    public static func parseMailbox(_ value: String) throws -> MailboxAddress {
        let list = try InternetAddressList(parsing: value)
        for address in list {
            if let mailbox = address as? MailboxAddress {
                return mailbox
            }
        }
        throw AddressParserError.noMailboxFound
    }
}
