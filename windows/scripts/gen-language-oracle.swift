// Sinh đáp án chuẩn cho bộ nhận diện ngôn ngữ của bản Windows: chạy LanguageGate.swift thật
// (NLLanguageRecognizer của macOS) trên Fixtures/language-corpus.json.
// Test C# LanguageGateParityTests so kết quả với file này.
//
// Biên dịch cùng code GrammarKit (chạy từ thư mục gốc repo):
//   swiftc -O -o /tmp/lang-oracle GrammarKit/Diff/Tokenizer.swift GrammarKit/Pipeline/LanguageGate.swift \
//       windows/scripts/gen-language-oracle.swift
//   /tmp/lang-oracle windows/tests/Grammar.Core.Tests/Fixtures/language-corpus.json \
//       > windows/tests/Grammar.Core.Tests/Fixtures/language-oracle.json
import Foundation
import NaturalLanguage

let path = CommandLine.arguments[1]
let corpus = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
var sentences: [String] = []
for key in ["english", "vietnamese", "other", "tooShort"] {
    sentences += corpus[key] as? [String] ?? []
}
// Thêm toàn bộ câu trong golden set (đều là tiếng Anh).
let golden = try JSONSerialization.jsonObject(
    with: Data(contentsOf: URL(fileURLWithPath: "GrammarAppTests/Fixtures/golden.json"))) as! [String: Any]
for item in golden["incorrect"] as! [[String: Any]] { sentences.append(item["input"] as! String) }
sentences += golden["correct"] as! [String]

let gate = LanguageGate()
var out: [[String: Any]] = []
for s in sentences {
    let verdict: String = switch gate.evaluate(s) {
    case .english: "english"
    case .notEnglish: "notEnglish"
    case .tooShort: "tooShort"
    }
    let recognizer = NLLanguageRecognizer()
    recognizer.languageHints = LanguageGate.languageHints
    recognizer.processString(s)
    let english = recognizer.languageHypotheses(withMaximum: 3)[.english] ?? 0
    out.append(["sentence": s, "verdict": verdict, "englishProbability": (english * 1000).rounded() / 1000])
}
let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
