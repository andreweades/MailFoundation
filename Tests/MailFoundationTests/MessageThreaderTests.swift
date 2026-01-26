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

import Testing
@testable import MailFoundation

private func makeThreadable(
    index: inout Int,
    subject: String,
    messageId: String,
    date: String,
    references: String?
) -> MessageSummary {
    index += 1
    let parsedDate = DateUtils.tryParse(date)
    let parsedMessageId = MessageIdList.parseAll(messageId).first ?? messageId
    let refIds = references.map { MessageIdList.parseAll($0) } ?? []
    let envelope = ImapEnvelope(
        date: parsedDate,
        subject: subject,
        from: [],
        sender: [],
        replyTo: [],
        to: [],
        cc: [],
        bcc: [],
        inReplyTo: nil,
        messageId: parsedMessageId
    )

    let items: MessageSummaryItems = [.envelope, .references, .uniqueId, .size]
    return MessageSummary(
        sequence: index,
        items: items,
        uniqueId: UniqueId(id: UInt32(index)),
        size: 0,
        envelope: envelope,
        references: MessageIdList(refIds)
    )
}

private func writeMessageThread(
    _ builder: inout String,
    messages: [MessageSummary],
    thread: MessageThread,
    depth: Int
) {
    builder.append(String(repeating: " ", count: depth * 3))
    if let uniqueId = thread.uniqueId {
        let index = Int(uniqueId.id) - 1
        let subject = messages[index].envelope?.subject ?? ""
        builder.append(subject)
    } else {
        builder.append("dummy")
    }
    builder.append("\n")

    for child in thread.children {
        writeMessageThread(&builder, messages: messages, thread: child, depth: depth + 1)
    }
}

@Test("MessageThreader threads by subject")
func messageThreaderBySubject() throws {
    let defaultDate = "01 Jan 1997 12:00:00 -0400"
    var messages: [MessageSummary] = []
    var index = 0

    messages.append(makeThreadable(index: &index, subject: "Subject", messageId: "<1>", date: defaultDate, references: nil))
    messages.append(makeThreadable(index: &index, subject: "Re[2]: Subject", messageId: "<2>", date: defaultDate, references: "<1>"))
    messages.append(makeThreadable(index: &index, subject: "Re: Subject", messageId: "<3>", date: defaultDate, references: "<1> <2>"))
    messages.append(makeThreadable(index: &index, subject: "Re: Re: Subject", messageId: "<4>", date: defaultDate, references: "<1>"))
    messages.append(makeThreadable(index: &index, subject: "Re:RE:rE[3]: Subject", messageId: "<5>", date: defaultDate, references: "<3> <x1> <x2> <x3>"))

    let expected = """
Subject
   Re[2]: Subject
   Re: Subject
   Re: Re: Subject
   Re:RE:rE[3]: Subject
"""

    let threads = try messages.thread(algorithm: .orderedSubject)
    var builder = ""
    for thread in threads {
        writeMessageThread(&builder, messages: messages, thread: thread, depth: 0)
    }

    #expect(builder.trimmingCharacters(in: .newlines) == expected.trimmingCharacters(in: .newlines))
}

@Test("MessageThreader threads by references")
func messageThreaderByReferences() throws {
    let defaultDate = "01 Jan 1997 12:00:00 -0400"
    var messages: [MessageSummary] = []
    var index = 0

    messages.append(makeThreadable(index: &index, subject: "A", messageId: "<1>", date: defaultDate, references: nil))
    messages.append(makeThreadable(index: &index, subject: "B", messageId: "<2>", date: defaultDate, references: "<1>"))
    messages.append(makeThreadable(index: &index, subject: "C", messageId: "<3>", date: defaultDate, references: "<1> <2>"))
    messages.append(makeThreadable(index: &index, subject: "D", messageId: "<4>", date: defaultDate, references: "<1>"))
    messages.append(makeThreadable(index: &index, subject: "E", messageId: "<5>", date: defaultDate, references: "<3> <x1> <x2> <x3>"))
    messages.append(makeThreadable(index: &index, subject: "F", messageId: "<6>", date: defaultDate, references: "<2>"))
    messages.append(makeThreadable(index: &index, subject: "G", messageId: "<7>", date: defaultDate, references: "<nonesuch>"))
    messages.append(makeThreadable(index: &index, subject: "H", messageId: "<8>", date: defaultDate, references: "<nonesuch>"))

    messages.append(makeThreadable(index: &index, subject: "Loop1", messageId: "<loop1>", date: defaultDate, references: "<loop2> <loop3>"))
    messages.append(makeThreadable(index: &index, subject: "Loop2", messageId: "<loop2>", date: defaultDate, references: "<loop3> <loop1>"))
    messages.append(makeThreadable(index: &index, subject: "Loop3", messageId: "<loop3>", date: defaultDate, references: "<loop1> <loop2>"))

    messages.append(makeThreadable(index: &index, subject: "Loop4", messageId: "<loop4>", date: defaultDate, references: "<loop5>"))
    messages.append(makeThreadable(index: &index, subject: "Loop5", messageId: "<loop5>", date: defaultDate, references: "<loop4>"))

    messages.append(makeThreadable(index: &index, subject: "Loop6", messageId: "<loop6>", date: defaultDate, references: "<loop6>"))

    messages.append(makeThreadable(index: &index, subject: "Loop7", messageId: "<loop7>", date: defaultDate, references: "<loop8>  <loop9>  <loop10> <loop8>  <loop9> <loop10>"))
    messages.append(makeThreadable(index: &index, subject: "Loop8", messageId: "<loop8>", date: defaultDate, references: "<loop9>  <loop10> <loop7>  <loop9>  <loop10> <loop7>"))
    messages.append(makeThreadable(index: &index, subject: "Loop8", messageId: "<loop9>", date: defaultDate, references: "<loop10> <loop7>  <loop8>  <loop10> <loop7>  <loop8>"))
    messages.append(makeThreadable(index: &index, subject: "Loop10", messageId: "<loop10>", date: defaultDate, references: "<loop7>  <loop8>  <loop9>  <loop7>  <loop8>  <loop9>"))

    messages.append(makeThreadable(index: &index, subject: "Ambig1", messageId: "<ambig1>", date: defaultDate, references: nil))
    messages.append(makeThreadable(index: &index, subject: "Ambig2", messageId: "<ambig2>", date: defaultDate, references: "<ambig1>"))
    messages.append(makeThreadable(index: &index, subject: "Ambig3", messageId: "<ambig3>", date: defaultDate, references: "<ambig1> <ambig2>"))
    messages.append(makeThreadable(index: &index, subject: "Ambig4", messageId: "<ambig4>", date: defaultDate, references: "<ambig1> <ambig2> <ambig3>"))
    messages.append(makeThreadable(index: &index, subject: "Ambig5a", messageId: "<ambig5a>", date: defaultDate, references: "<ambig1> <ambig2> <ambig3> <ambig4>"))
    messages.append(makeThreadable(index: &index, subject: "Ambig5b", messageId: "<ambig5b>", date: defaultDate, references: "<ambig1> <ambig3> <ambig2> <ambig4>"))

    messages.append(makeThreadable(index: &index, subject: "dup", messageId: "<dup>", date: defaultDate, references: nil))
    messages.append(makeThreadable(index: &index, subject: "dup-kid", messageId: "<dup-kid>", date: defaultDate, references: "<dup>"))
    messages.append(makeThreadable(index: &index, subject: "dup-kid", messageId: "<dup-kid>", date: defaultDate, references: "<dup>"))
    messages.append(makeThreadable(index: &index, subject: "dup-kid-2", messageId: "<dup-kid-2>", date: defaultDate, references: "<dup>"))
    messages.append(makeThreadable(index: &index, subject: "dup-kid-2", messageId: "<dup-kid-2>", date: defaultDate, references: "<dup>"))
    messages.append(makeThreadable(index: &index, subject: "dup-kid-2", messageId: "<dup-kid-2>", date: defaultDate, references: "<dup>"))

    messages.append(makeThreadable(index: &index, subject: "same subject 1", messageId: "<ss1.1>", date: defaultDate, references: nil))
    messages.append(makeThreadable(index: &index, subject: "same subject 1", messageId: "<ss1.2>", date: defaultDate, references: nil))

    messages.append(makeThreadable(index: &index, subject: "missingmessage", messageId: "<missa>", date: defaultDate, references: nil))
    messages.append(makeThreadable(index: &index, subject: "missingmessage", messageId: "<missc>", date: defaultDate, references: "<missa> <missb>"))

    messages.append(makeThreadable(index: &index, subject: "liar 1", messageId: "<liar.1>", date: defaultDate, references: "<liar.a> <liar.c>"))
    messages.append(makeThreadable(index: &index, subject: "liar 2", messageId: "<liar.2>", date: defaultDate, references: "<liar.a> <liar.b> <liar.c>"))

    messages.append(makeThreadable(index: &index, subject: "liar2 1", messageId: "<liar2.1>", date: defaultDate, references: "<liar2.a> <liar2.b> <liar2.c>"))
    messages.append(makeThreadable(index: &index, subject: "liar2 2", messageId: "<liar2.2>", date: defaultDate, references: "<liar2.a> <liar2.c>"))

    messages.append(makeThreadable(index: &index, subject: "xx", messageId: "<331F7D61.2781@netscape.com>", date: "Thu, 06 Mar 1997 18:28:50 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "lkjhlkjh", messageId: "<3321E51F.41C6@netscape.com>", date: "Sat, 08 Mar 1997 14:15:59 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "test 2", messageId: "<3321E5A6.41C6@netscape.com>", date: "Sat, 08 Mar 1997 14:18:14 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "enc", messageId: "<3321E5C0.167E@netscape.com>", date: "Sat, 08 Mar 1997 14:18:40 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "lkjhlkjh", messageId: "<3321E715.15FB@netscape.com>", date: "Sat, 08 Mar 1997 14:24:21 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "eng", messageId: "<3321E7A4.59E2@netscape.com>", date: "Sat, 08 Mar 1997 14:26:44 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "lkjhl", messageId: "<3321E7BB.1CFB@netscape.com>", date: "Sat, 08 Mar 1997 14:27:07 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "Re: certs and signed messages", messageId: "<332230AA.41C6@netscape.com>", date: "Sat, 08 Mar 1997 19:38:18 -0800", references: "<33222A5E.ED4@netscape.com>"))
    messages.append(makeThreadable(index: &index, subject: "from dogbert", messageId: "<3323546E.BEE44C78@netscape.com>", date: "Sun, 09 Mar 1997 16:23:10 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "lkjhlkjhl", messageId: "<33321E2A.1C849A20@netscape.com>", date: "Thu, 20 Mar 1997 21:35:38 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "le:/u/jwz/mime/smi", messageId: "<33323C9D.ADA4BCBA@netscape.com>", date: "Thu, 20 Mar 1997 23:45:33 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "ile:/u/jwz", messageId: "<33323F62.402C573B@netscape.com>", date: "Thu, 20 Mar 1997 23:57:22 -0800", references: nil))
    messages.append(makeThreadable(index: &index, subject: "ljkljhlkjhl", messageId: "<336FBAD0.864BC1F4@netscape.com>", date: "Tue, 06 May 1997 16:12:16 -0700", references: nil))
    messages.append(makeThreadable(index: &index, subject: "lkjh", messageId: "<336FBB46.A0028A6D@netscape.com>", date: "Tue, 06 May 1997 16:14:14 -0700", references: nil))
    messages.append(makeThreadable(index: &index, subject: "foo", messageId: "<337265C1.5C758C77@netscape.com>", date: "Thu, 08 May 1997 16:46:09 -0700", references: nil))
    messages.append(makeThreadable(index: &index, subject: "Welcome to Netscape", messageId: "<337AAB3D.C8BCE069@netscape.com>", date: "Wed, 14 May 1997 23:20:45 -0700", references: nil))
    messages.append(makeThreadable(index: &index, subject: "Re: Welcome to Netscape", messageId: "<337AAE46.903032E4@netscape.com>", date: "Wed, 14 May 1997 23:33:45 -0700", references: "<337AAB3D.C8BCE069@netscape.com>"))
    messages.append(makeThreadable(index: &index, subject: "[Fwd: enc/signed test 1]", messageId: "<338B6EE2.BB26C74C@netscape.com>", date: "Tue, 27 May 1997 16:31:46 -0700", references: nil))

    let expected = """
A
   B
      C
         E
      F
   D
dummy
   G
   H
Loop5
   Loop4
Loop6
Ambig1
   Ambig2
      Ambig3
         Ambig4
            Ambig5a
            Ambig5b
dup
   dup-kid
   dup-kid
   dup-kid-2
   dup-kid-2
   dup-kid-2
dummy
   same subject 1
   same subject 1
missingmessage
   missingmessage
dummy
   liar 1
   liar 2
dummy
   liar2 1
   liar2 2
xx
dummy
   lkjhlkjh
   lkjhlkjh
test 2
enc
eng
lkjhl
Re: certs and signed messages
from dogbert
lkjhlkjhl
le:/u/jwz/mime/smi
ile:/u/jwz
ljkljhlkjhl
lkjh
foo
Welcome to Netscape
   Re: Welcome to Netscape
[Fwd: enc/signed test 1]
"""

    let threads = try messages.thread(algorithm: .references)
    var builder = ""
    for thread in threads {
        writeMessageThread(&builder, messages: messages, thread: thread, depth: 0)
    }

    #expect(builder.trimmingCharacters(in: .newlines) == expected.trimmingCharacters(in: .newlines))
}

@Test("MessageThreader throws for missing envelope")
func messageThreaderMissingEnvelope() {
    let summary = MessageSummary(sequence: 1, items: [.references])
    #expect(throws: MessageThreaderError.missingEnvelope) {
        _ = try MessageThreader.thread([summary], algorithm: .references)
    }
}
