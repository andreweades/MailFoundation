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
// ImapEnvelopeCache.swift
//
// Cache for parsed IMAP envelope strings.
//

public actor ImapEnvelopeCache {
    private let maxEntries: Int
    private var storage: [String: ImapEnvelope] = [:]
    private var order: [String] = []

    public init(maxEntries: Int = 128) {
        self.maxEntries = max(1, maxEntries)
    }

    public func envelope(for raw: String) -> ImapEnvelope? {
        if let cached = storage[raw] {
            return cached
        }
        guard let parsed = ImapEnvelope.parse(raw) else { return nil }
        insert(raw: raw, envelope: parsed)
        return parsed
    }

    public func count() -> Int {
        storage.count
    }

    public func clear() {
        storage.removeAll()
        order.removeAll()
    }

    private func insert(raw: String, envelope: ImapEnvelope) {
        storage[raw] = envelope
        order.append(raw)
        if order.count > maxEntries {
            let removed = order.removeFirst()
            storage.removeValue(forKey: removed)
        }
    }
}
