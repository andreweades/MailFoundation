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
// ImapCommandKind.swift
//
// IMAP command definitions.
//

public enum ImapCommandKind: Sendable {
    case capability
    case noop
    case login(String, String)
    case authenticate(String, initialResponse: String?)
    case select(String)
    case examine(String)
    case logout
    case create(String)
    case delete(String)
    case rename(String, String)
    case subscribe(String)
    case unsubscribe(String)
    case list(String, String)
    case lsub(String, String)
    case status(String, items: [String])
    case check
    case close
    case expunge
    case namespace
    case getQuota(String)
    case getQuotaRoot(String)
    case getAcl(String)
    case setAcl(String, identifier: String, rights: String)
    case listRights(String, identifier: String)
    case myRights(String)
    case getMetadata(String, options: ImapMetadataOptions?, entries: [String])
    case setMetadata(String, entries: [ImapMetadataEntry])
    case getAnnotation(String, entries: [String], attributes: [String])
    case setAnnotation(String, entry: String, attributes: [ImapAnnotationAttribute])
    case id(String)
    case fetch(String, String)
    case store(String, String)
    case copy(String, String)
    case move(String, String)
    case search(String)
    case sort(String)
    case uidFetch(String, String)
    case uidStore(String, String)
    case uidCopy(String, String)
    case uidMove(String, String)
    case uidSearch(String)
    case uidSort(String)
    case enable([String])
    case idle
    case idleDone
    case starttls

    public func command(tag: String) -> ImapCommand {
        switch self {
        case .capability:
            return ImapCommand(tag: tag, name: "CAPABILITY")
        case .noop:
            return ImapCommand(tag: tag, name: "NOOP")
        case let .login(user, password):
            return ImapCommand(tag: tag, name: "LOGIN", arguments: "\(user) \(password)")
        case let .authenticate(mechanism, initialResponse):
            if let response = initialResponse {
                return ImapCommand(tag: tag, name: "AUTHENTICATE", arguments: "\(mechanism) \(response)")
            }
            return ImapCommand(tag: tag, name: "AUTHENTICATE", arguments: mechanism)
        case let .select(mailbox):
            return ImapCommand(tag: tag, name: "SELECT", arguments: mailbox)
        case let .examine(mailbox):
            return ImapCommand(tag: tag, name: "EXAMINE", arguments: mailbox)
        case .logout:
            return ImapCommand(tag: tag, name: "LOGOUT")
        case let .create(mailbox):
            return ImapCommand(tag: tag, name: "CREATE", arguments: mailbox)
        case let .delete(mailbox):
            return ImapCommand(tag: tag, name: "DELETE", arguments: mailbox)
        case let .rename(from, to):
            return ImapCommand(tag: tag, name: "RENAME", arguments: "\(from) \(to)")
        case let .subscribe(mailbox):
            return ImapCommand(tag: tag, name: "SUBSCRIBE", arguments: mailbox)
        case let .unsubscribe(mailbox):
            return ImapCommand(tag: tag, name: "UNSUBSCRIBE", arguments: mailbox)
        case let .list(reference, mailbox):
            return ImapCommand(tag: tag, name: "LIST", arguments: "\(reference) \(mailbox)")
        case let .lsub(reference, mailbox):
            return ImapCommand(tag: tag, name: "LSUB", arguments: "\(reference) \(mailbox)")
        case let .status(mailbox, items):
            let itemList = items.joined(separator: " ")
            return ImapCommand(tag: tag, name: "STATUS", arguments: "\(mailbox) (\(itemList))")
        case .check:
            return ImapCommand(tag: tag, name: "CHECK")
        case .close:
            return ImapCommand(tag: tag, name: "CLOSE")
        case .expunge:
            return ImapCommand(tag: tag, name: "EXPUNGE")
        case .namespace:
            return ImapCommand(tag: tag, name: "NAMESPACE")
        case let .getQuota(root):
            return ImapCommand(tag: tag, name: "GETQUOTA", arguments: root)
        case let .getQuotaRoot(mailbox):
            return ImapCommand(tag: tag, name: "GETQUOTAROOT", arguments: mailbox)
        case let .getAcl(mailbox):
            return ImapCommand(tag: tag, name: "GETACL", arguments: mailbox)
        case let .setAcl(mailbox, identifier, rights):
            return ImapCommand(tag: tag, name: "SETACL", arguments: "\(mailbox) \(identifier) \(rights)")
        case let .listRights(mailbox, identifier):
            return ImapCommand(tag: tag, name: "LISTRIGHTS", arguments: "\(mailbox) \(identifier)")
        case let .myRights(mailbox):
            return ImapCommand(tag: tag, name: "MYRIGHTS", arguments: mailbox)
        case let .getMetadata(mailbox, options, entries):
            let entryList = ImapMetadata.formatEntryList(entries)
            if let options = options?.arguments() {
                return ImapCommand(tag: tag, name: "GETMETADATA", arguments: "\(mailbox) \(options) \(entryList)")
            }
            return ImapCommand(tag: tag, name: "GETMETADATA", arguments: "\(mailbox) \(entryList)")
        case let .setMetadata(mailbox, entries):
            let entryList = ImapMetadata.formatEntryPairs(entries)
            return ImapCommand(tag: tag, name: "SETMETADATA", arguments: "\(mailbox) \(entryList)")
        case let .getAnnotation(mailbox, entries, attributes):
            let entryList = ImapAnnotation.formatEntryList(entries)
            let attributeList = ImapAnnotation.formatAttributeList(attributes)
            return ImapCommand(tag: tag, name: "GETANNOTATION", arguments: "\(mailbox) \(entryList) \(attributeList)")
        case let .setAnnotation(mailbox, entry, attributes):
            let attributeList = ImapAnnotation.formatAttributes(attributes)
            let entryName = ImapMetadata.atomOrQuoted(entry)
            return ImapCommand(tag: tag, name: "SETANNOTATION", arguments: "\(mailbox) \(entryName) \(attributeList)")
        case let .id(arguments):
            return ImapCommand(tag: tag, name: "ID", arguments: arguments)
        case let .fetch(set, items):
            return ImapCommand(tag: tag, name: "FETCH", arguments: "\(set) \(items)")
        case let .store(set, data):
            return ImapCommand(tag: tag, name: "STORE", arguments: "\(set) \(data)")
        case let .copy(set, mailbox):
            return ImapCommand(tag: tag, name: "COPY", arguments: "\(set) \(mailbox)")
        case let .move(set, mailbox):
            return ImapCommand(tag: tag, name: "MOVE", arguments: "\(set) \(mailbox)")
        case let .search(criteria):
            return ImapCommand(tag: tag, name: "SEARCH", arguments: criteria)
        case let .sort(criteria):
            return ImapCommand(tag: tag, name: "SORT", arguments: criteria)
        case let .uidFetch(set, items):
            return ImapCommand(tag: tag, name: "UID FETCH", arguments: "\(set) \(items)")
        case let .uidStore(set, data):
            return ImapCommand(tag: tag, name: "UID STORE", arguments: "\(set) \(data)")
        case let .uidCopy(set, mailbox):
            return ImapCommand(tag: tag, name: "UID COPY", arguments: "\(set) \(mailbox)")
        case let .uidMove(set, mailbox):
            return ImapCommand(tag: tag, name: "UID MOVE", arguments: "\(set) \(mailbox)")
        case let .uidSearch(criteria):
            return ImapCommand(tag: tag, name: "UID SEARCH", arguments: criteria)
        case let .uidSort(criteria):
            return ImapCommand(tag: tag, name: "UID SORT", arguments: criteria)
        case let .enable(capabilities):
            let list = capabilities.joined(separator: " ")
            return ImapCommand(tag: tag, name: "ENABLE", arguments: list)
        case .idle:
            return ImapCommand(tag: tag, name: "IDLE")
        case .idleDone:
            return ImapCommand(tag: tag, name: "DONE")
        case .starttls:
            return ImapCommand(tag: tag, name: "STARTTLS")
        }
    }
}
