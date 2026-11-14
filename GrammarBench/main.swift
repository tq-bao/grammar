import Foundation
import GrammarKit

// GrammarBench: chấm các model GGUF trên golden set.
//
//   GrammarBench --golden GrammarAppTests/Fixtures/golden.json \
//                --model GrammarApp/Resources/Models/Qwen2.5-3B-Instruct-Q4_K_M.gguf \
//                [--model ...] [--verbose]

struct Arguments {
    var golden = "GrammarAppTests/Fixtures/golden.json"
    var models: [String] = []
    var verbose = false

    init() {
        var args = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = args.next() {
            switch arg {
            case "--golden": golden = args.next() ?? golden
            case "--model": if let m = args.next() { models.append(m) }
            case "--verbose": verbose = true
            default:
                FileHandle.standardError.write(Data("Tham số không hợp lệ: \(arg)\n".utf8))
                exit(64)
            }
        }
    }
}

func percent(_ x: Double) -> String { String(format: "%.0f%%", x * 100) }
func ms(_ s: Double) -> String { String(format: "%.0f ms", s * 1000) }

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

    print("Giữ nguyên câu đúng: \(percent(report.keepRate)) | Khớp đáp án: \(percent(report.matchRate)) | Bị EditGuard loại: \(percent(report.rewriteRate)) | p50 \(ms(report.p50)) | p95 \(ms(report.p95)) | nạp + warm-up \(String(format: "%.1f s", loadSeconds))")
    summary.append((name, report, loadSeconds))
}

print("\n| Model | Giữ nguyên câu đúng | Khớp đáp án | EditGuard loại | p50 | p95 | Nạp + warm-up |")
print("|---|---|---|---|---|---|---|")
for row in summary {
    let r = row.report
    print("| \(row.name) | \(percent(r.keepRate)) | \(percent(r.matchRate)) | \(percent(r.rewriteRate)) | \(ms(r.p50)) | \(ms(r.p95)) | \(String(format: "%.1f s", row.load)) |")
}
