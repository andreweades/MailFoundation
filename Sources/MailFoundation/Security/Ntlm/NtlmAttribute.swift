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
// NtlmAttribute.swift
//
// NTLM target info attribute types.
//
// Port of MailKit's NtlmAttribute.cs
// https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-nlmp/b38c36ed-2804-4868-a9ff-8dd3182128e4
//

import Foundation

/// Target info attribute types used in NTLM AV_PAIR structures.
///
/// These attributes are used in the Target Information block of NTLM Challenge
/// messages (Type 2) and are used in computing the NTLMv2 response.
public enum NtlmAttribute: Int16, Sendable {
    /// End of list marker.
    case eol = 0

    /// The server's NetBIOS computer name.
    case serverName = 1

    /// The server's NetBIOS domain name.
    case domainName = 2

    /// The fully qualified domain name (FQDN) of the server.
    case dnsServerName = 3

    /// The fully qualified domain name (FQDN) of the domain.
    case dnsDomainName = 4

    /// The fully qualified domain name (FQDN) of the forest.
    case dnsTreeName = 5

    /// A 32-bit value indicating server or client configuration flags.
    case flags = 6

    /// A FILETIME timestamp containing the server local time.
    case timestamp = 7

    /// Single host data structure.
    case singleHost = 8

    /// The Service Principal Name (SPN) of the server.
    case targetName = 9

    /// The channel binding hash (MD5 of channel binding data).
    case channelBinding = 10
}
