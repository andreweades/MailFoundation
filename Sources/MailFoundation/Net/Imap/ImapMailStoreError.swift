//
// ImapMailStoreError.swift
//
// Store-level IMAP errors.
//

public enum ImapMailStoreError: Error, Sendable, Equatable {
    case noSelectedFolder
}
