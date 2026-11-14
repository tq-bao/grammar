import Foundation
import GrammarKit

// GrammarBench: chấm các model GGUF trên golden set.
//
//   GrammarBench --golden GrammarAppTests/Fixtures/golden.json \
//                --model GrammarApp/Resources/Models/Qwen2.5-3B-Instruct-Q4_K_M.gguf \
//                [--model ...] [--verbose] [--translate]
//
// --translate: sau golden set, dịch các câu mẫu sang tiếng Việt (in từng bản dịch để đọc bằng mắt),
// xen kẽ mỗi lần dịch với một lần sửa ngữ pháp, rồi in p50/p95 của bước dịch và p95 của bước sửa khi xen kẽ.

struct Arguments {
    var golden = "GrammarAppTests/Fixtures/golden.json"
    var models: [String] = []
    var verbose = false
    var translate = false

    init() {
        var args = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = args.next() {
            switch arg {
            case "--golden": golden = args.next() ?? golden
            case "--model": if let m = args.next() { models.append(m) }
            case "--verbose": verbose = true
            case "--translate": translate = true
            default:
                FileHandle.standardError.write(Data("Tham số không hợp lệ: \(arg)\n".utf8))
                exit(64)
            }
        }
    }
}

func percent(_ x: Double) -> String { String(format: "%.0f%%", x * 100) }
func ms(_ s: Double) -> String { String(format: "%.0f ms", s * 1000) }

func percentile(_ values: [Double], _ p: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = Int((Double(sorted.count - 1) * p).rounded())
    return sorted[index]
}

/// Câu mẫu cho bước dịch: câu thường, câu viết tắt kiểu chat, câu có tên riêng/thuật ngữ,
/// câu hỏi và yêu cầu (phải được dịch, không được trả lời), và một câu dài khoảng 40 từ.
let translationSamples = [
    "She went to school yesterday.",
    "I have finished the report.",
    "He has two cats.",
    "gonna send u the file tmr, it has the numbers",
    "ok cool, will do it after lunch",
    "Can you send me the file?",
    "What time does the meeting start tomorrow?",
    "Please review my pull request before Friday.",
    "Write a poem about the sea.",
    "The deployment to Kubernetes failed because the Docker image was missing.",
    "Minh and Lan will join the call with the Singapore team at 3 PM.",
    "There is a lot of information in the document.",
    "I am good at math but I need more practice with statistics.",
    "Thanks for your help, I really appreciate it.",
    "We decided to postpone the product launch until next quarter because the testing team found several critical bugs in the payment flow, and we want to make sure every customer has a smooth experience before we announce it publicly.",
]

let args = Arguments()
guard !args.models.isEmpty else {
    print("Cần ít nhất một --model <file.gguf>")
    exit(64)
}

let golden: GoldenSet
do {
    golden = try GoldenSet.load(from: URL(fileURLWithPath: args.golden))
} catch {
    print("Không đọc được golden set: \(error)")
    exit(1)
}

let guardian = EditGuard()
var summary: [(name: String, report: EvaluationReport, load: Double)] = []

for modelPath in args.models {
    let name = URL(fileURLWithPath: modelPath).lastPathComponent
    print("\n=== \(name) ===")

    let loadStart = Date()
    let engine: LlamaGrammarEngine
    do {
        engine = try LlamaGrammarEngine(modelURL: URL(fileURLWithPath: modelPath))
    } catch {
        print("Lỗi nạp model: \(error.localizedDescription)")
        continue
    }
    await engine.warmUp()
    let loadSeconds = Date().timeIntervalSince(loadStart)

    var report = EvaluationReport()
    let cases: [(String, [String]?)] =
        golden.incorrect.map { ($0.input, $0.expected) } + golden.correct.map { ($0, nil) }

    for (input, expected) in cases {
        let start = Date()
        let raw = (try? await engine.correct(input)) ?? "<lỗi>"
        // Giống app: bỏ qua khác biệt viết hoa/viết thường và dấu câu cuối câu.
        let output = CorrectionNormalizer.reconcile(original: input, corrected: raw)
        let seconds = Date().timeIntervalSince(start)
        let verdict = guardian.evaluate(WordDiff(original: input, corrected: output))
        let item = EvaluationReport.Item(
            input: input, output: output, expected: expected, verdict: verdict, seconds: seconds)
        report.items.append(item)

        if args.verbose || !item.passed {
            let mark = item.passed ? "✓" : "✗"
            let kind = expected == nil ? "đúng" : "sai "
            print("\(mark) [\(kind)] \(input)\n      -> \(output)\(verdict == .rewritten ? "  (EditGuard: viết lại)" : "")")
        }
    }

    if args.translate {
        print("\n--- Dịch (xen kẽ với sửa ngữ pháp) ---")
        var translateSeconds: [Double] = []
        var correctSeconds: [Double] = []
        for (index, sentence) in translationSamples.enumerated() {
            var start = Date()
            let translation: String
            do {
                translation = try await engine.translate(sentence)
            } catch {
                translation = "<lỗi: \(error.localizedDescription)>"
            }
            translateSeconds.append(Date().timeIntervalSince(start))
            print("\(sentence)\n      -> \(translation)  (\(ms(translateSeconds.last!)))")

            // Một lần sửa ngay sau lần dịch: kiểm tra prefix cache của bước sửa còn nguyên.
            let input = cases[index % cases.count].0
            start = Date()
            _ = try? await engine.correct(input)
            correctSeconds.append(Date().timeIntervalSince(start))
        }
        print("Dịch: p50 \(ms(percentile(translateSeconds, 0.5))) | p95 \(ms(percentile(translateSeconds, 0.95))) | Sửa khi xen kẽ: p50 \(ms(percentile(correctSeconds, 0.5))) | p95 \(ms(percentile(correctSeconds, 0.95)))")
    }

    print("Giữ nguyên câu đúng: \(percent(report.keepRate)) | Khớp đáp án: \(percent(report.matchRate)) | Bị EditGuard loại: \(percent(report.rewriteRate)) | p50 \(ms(report.p50)) | p95 \(ms(report.p95)) | nạp + warm-up \(String(format: "%.1f s", loadSeconds))")
    summary.append((name, report, loadSeconds))
}

print("\n| Model | Giữ nguyên câu đúng | Khớp đáp án | EditGuard loại | p50 | p95 | Nạp + warm-up |")
print("|---|---|---|---|---|---|---|")
for row in summary {
    let r = row.report
    print("| \(row.name) | \(percent(r.keepRate)) | \(percent(r.matchRate)) | \(percent(r.rewriteRate)) | \(ms(r.p50)) | \(ms(r.p95)) | \(String(format: "%.1f s", row.load)) |")
}
