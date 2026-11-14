// Sinh fixture đối chiếu tách câu: chạy NLTokenizer(unit: .sentence) thật của macOS trên các đoạn văn mẫu.
// Test C# SentenceSegmenterParityTests đọc file này để chắc bộ tách câu theo quy tắc cho cùng kết quả.
//
//   swift windows/scripts/gen-sentence-fixture.swift > windows/tests/Grammar.Core.Tests/Fixtures/sentences-nltokenizer.json
import Foundation
import NaturalLanguage

let texts = [
    "I like tea. He have two cats. We are fine.",
    "Nice 😀 day. She go home now.",
    "Upgrade React Native from 0.83.1 to 0.87.1. It touches both apps. We bump react too.",
    "Ping  about it. She go home now.",
    "I don’t want to mention",
    "Hello world",
    "Is it ready? Yes it is! Great.",
    "Wait... what happened? I don't know.",
    "He said \"stop.\" Then he left.",
    "(See the doc.) It has the numbers.",
    "Mr. Smith is here. He wants tea.",
    "We met Dr. Lee yesterday. She was nice.",
    "Use e.g. a hash map. It is faster.",
    "The U.S. team won. They were happy.",
    "Check example.com for details. Then reply.",
    "Version v1.2 is out. Please update.",
    "It costs 3.14 dollars. Cheap!",
    "first line\nsecond line",
    "Hi team,\n\nI will send the file tmr. Thanks",
    "line one.\nline two.",
    "gonna send u the file tmr, it have the numbers",
    "I went home and I was tired. I slept early.",
    "ok thanks",
    "what?? really!! ok.",
    "She said ‘hi.’ He waved.",
    "Meeting at 10 a.m. tomorrow. Be on time.",
    "J. K. Rowling wrote it. I read it.",
    "This is it… Done.",
    "I am fine.Thanks for asking.",
    "Call me at 5pm. I am free then.",
    "the datas shows that sales has increase. we need more",
    "I. Introduction. This is the first part.",
    "Hi Bao. Can you check the PR? Thanks!",
    "   leading spaces. trailing   ",
    "A.B.C. is a company. It sells things.",
    "Plan A. Then plan B.",
]

var out: [[String: Any]] = []
for text in texts {
    let tokenizer = NLTokenizer(unit: .sentence)
    tokenizer.string = text
    var sentences: [String] = []
    tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
        sentences.append(String(text[range]))
        return true
    }
    out.append(["text": text, "sentences": sentences])
}
let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys, .prettyPrinted])
print(String(decoding: data, as: UTF8.self))
