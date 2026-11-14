# Design

## Context

Lý do và phạm vi: xem proposal.md. Hành vi: xem `specs/translation/spec.md` và delta `specs/checker-window/spec.md`.

Hiện trạng liên quan (macOS):
- `LlamaGrammarEngine` là một actor giữ **một** llama context. Engine cache KV của phần prompt cố định (system + 7 ví dụ) giữa các lần gọi. Cache này là lý do p95 của model 7B giảm từ khoảng 1.66 s xuống 0.42 s (`docs/model-benchmark.md`). Nếu cùng context đó chạy một prompt khác, prefix bị xoá và lần sửa kế tiếp phải prefill lại từ đầu.
- `CheckCoordinator` (`@MainActor @Observable`) giữ `state: CheckState` và một `pendingTask`. Câu mới huỷ task cũ. `CheckState` cũng được port sang Windows (`windows/src/Grammar.Core/Pipeline/CheckState.cs`) và dùng để vẽ `StatusBadge`.
- `PanelSettings` là nơi duy nhất lưu cài đặt (`UserDefaults`). `AppModel` theo dõi nó bằng `withObservationTracking` (`observeLayoutSettings`).
- `TwoPaneView` tự co chiều cao theo nội dung. `CheckerPanel.scheduleRelayout()` đặt lại khung panel khi kích thước đổi.

## Goals / Non-Goals

**Goals:**
- Bật Dịch không làm chậm bước sửa ngữ pháp, kể cả lần sửa ngay sau một lần dịch.
- Người không bật Dịch không tốn thêm RAM hay thời gian GPU.
- Logic dịch (trạng thái, huỷ, cache) test được bằng engine giả, không cần model.

**Non-Goals:**
- Không port sang Windows trong change này.
- Không dịch sang ngôn ngữ khác ngoài tiếng Việt, và không cho chọn ngôn ngữ đích.
- Không có phím tắt hay mục menu để copy bản dịch.
- Không dịch cả đoạn văn, chỉ dịch câu đang kiểm tra.
- Không có bộ golden set chấm điểm tự động cho bản dịch. Chất lượng được kiểm bằng mắt qua `GrammarBench --translate`.

## Decisions

### 1. Dịch bằng model Qwen2.5-7B đang nạp sẵn
- Không thêm dependency hay file model. Giữ được lời hứa offline. Sau này port sang Windows được, vì bản đó cũng dùng llama.cpp.
- **Đã cân nhắc:**
  - Apple Translation framework: nhanh và chất lượng tốt, nhưng người dùng phải tải gói ngôn ngữ lần đầu, API gắn với SwiftUI (`translationTask`), và không có trên Windows.
  - API online (Google/DeepL): phá lời hứa "không gửi ra ngoài", lại cần API key.
  - Model dịch chuyên dụng (NLLB, MarianMT): thêm hàng trăm MB và một runtime khác.

### 2. Context llama thứ hai, tạo khi cần
- Actor tạo thêm một context từ cùng `llama_model`, với sampler greedy riêng và prefix cache riêng cho prompt dịch. Trọng số model dùng chung. KV cache riêng tốn khoảng 117 MB với n_ctx 2048 (Qwen2.5-7B: 28 layer × 4 KV head × 128 × 2 × fp16).
- Context dịch chỉ được tạo ở lần gọi `translate` đầu tiên. Người không bật Dịch không tốn RAM này.
- Cả hai context nằm trong cùng actor, nên lời gọi GPU vẫn tuần tự như hiện nay.
- **Đã cân nhắc:**
  - Dùng chung context: prefix sửa ngữ pháp bị xoá sau mỗi lần dịch, và p95 của bước sửa quay về mức khoảng 1.6 s.
  - Một context với hai sequence id (`n_seq_max = 2`): tiết kiệm hơn một chút, nhưng phải dựng `llama_batch` có seq id thay cho `llama_batch_get_one` và chia KV giữa hai luồng. Phức tạp hơn mà lợi không nhiều.

### 3. Tách vòng sinh token thành "phiên" dùng chung
- Gom phần trạng thái gắn với một context thành một kiểu private trong actor, gọi là `Session`. Phần này gồm: context, sampler, `cachedPrefix`, `fixedPrefix`, và hàm dựng message của prompt.
- `prefill`, `decode`, `fixedPrefixTokens` và vòng sample nhận `Session` làm tham số. `correct` gọi chúng với session sửa ngữ pháp, `translate` gọi với session dịch. Hành vi của `correct` không đổi.
- `maxTokens` của bản dịch là `số token câu × 4 + 32`, vì tiếng Việt có dấu tốn nhiều token hơn tiếng Anh. Điều kiện dừng sớm khi gặp xuống dòng được giữ nguyên.

### 4. Prompt dịch riêng: `TranslationPrompt`
- Theo mẫu của `GrammarPrompt`, gồm system prompt cùng 4–5 cặp ví dụ.
- Ví dụ phủ: câu thường, câu có từ viết tắt kiểu chat ("u", "tmr"), câu có tên riêng hoặc thuật ngữ, và một câu hỏi (phải được dịch, không được trả lời).
- Dùng lại `GrammarPrompt.Message` để không nhân đôi kiểu dữ liệu.

### 5. `OutputSanitizer.cleanTranslation` không lấy câu gốc làm dự phòng
- `clean(_:original:)` trả câu gốc khi output rỗng. Với bước sửa thì đúng ("không có gì để sửa"), nhưng với bước dịch, trả câu tiếng Anh sẽ trông như bản dịch.
- Hàm mới lấy dòng đầu, bỏ tiền tố ("Translation:", "Vietnamese:", "Bản dịch:", "Text:") và ngoặc kép bao ngoài. Output rỗng thì ném `GrammarEngineError.emptyTranslation`, và panel hiện lỗi theo spec.

### 5b. Cấm token chữ Trung/Nhật/Hàn khi dịch (thêm sau bench)
- Bench lần đầu cho thấy Qwen2.5-7B với greedy decoding thỉnh thoảng trôi sang tiếng Trung giữa câu, ví dụ "Tôi giỏi môn toán nhưng cần练习一下…". Thêm quy tắc vào prompt không sửa được.
- Khi tạo phiên dịch, engine quét vocab một lần (khoảng 150 nghìn token, mất khoảng 0.25 s). Token nào có phần chữ là UTF-8 hợp lệ và chứa ký tự CJK (Hán, Kana, Hangul, ký tự full-width) thì được đưa vào sampler `logit_bias` với bias −∞, đặt trước sampler greedy. Phiên sửa ngữ pháp không đổi.
- Token byte rời (UTF-8 chưa đủ) không bị cấm, vì tiếng Việt có dấu cũng cần chúng.
- Sau khi cấm, câu ví dụ dịch đúng ("…nhưng cần nhiều bài tập hơn về thống kê"). Vẫn còn lỗi nhỏ kiểu dính chữ tiếng Anh ("mấy giờTomorrow") hay sai nghĩa ("before Friday" thành "trước thứ Năm"). Vì vậy tiêu đề section là "Bản dịch (tham khảo)".
- **Đã cân nhắc:** Apple Translation framework (chất lượng tốt hơn nhưng phải tải gói ngôn ngữ, và phải viết lại engine). Người dùng chọn giữ Qwen.

### 6. `TranslationState` tách khỏi `CheckState`
- Coordinator có thêm thuộc tính `translation: TranslationState` với các giá trị `.hidden`, `.translating`, `.done(String)` và `.failed(String)`.
- Không thêm case vào `CheckState`. Nếu thêm, `StatusBadge`, mọi `switch` hiện có và bản port C# đều phải đổi, trong khi trạng thái dịch không ảnh hưởng nhãn trạng thái.
- Protocol mới `TranslationEngine` tách khỏi `GrammarEngine`. `setEngine` nhận thêm tham số `translator: (any TranslationEngine)?`. `AppModel` truyền cùng một `LlamaGrammarEngine` vào cả hai, còn test truyền engine giả.

### 7. Task dịch riêng, bị huỷ cùng câu
- Coordinator có thêm `translationTask` riêng, khởi động trong `apply(_:for:)` sau khi `state` thành `.ok` hoặc `.corrected`. Cả đường sửa mới lẫn đường lấy từ cache đều đi qua `apply`.
- Dùng task riêng thay vì nối vào `pendingTask`, vì việc bật công tắc khi đang có kết quả cũng cần khởi động dịch mà không chạy lại bước sửa.
- `submit` và việc tắt Dịch huỷ `translationTask`. Kết quả dịch có guard `câu == sentence` trước khi ghi, để bản dịch cũ không đè câu mới.
- Câu mới huỷ task dịch, và `Task.checkCancellation()` trong vòng sinh token dừng nó sau tối đa một token. Nhờ vậy actor nhanh chóng rảnh cho lần sửa kế tiếp.
- `translationCache: ResultCache<String>` (200 phần tử, chỉ trong bộ nhớ) dùng câu cần dịch làm key. Có cache thì gán `.done` ngay, không qua `.translating`.
- `waitForPendingCheck()` đợi cả `pendingTask` lẫn `translationTask`, để test không phải sleep.

### 8. Cài đặt nằm trong `PanelSettings`, coordinator không đọc trực tiếp
- `PanelSettings` có thêm `translationEnabled`, key `translation.enabled`, mặc định `false`, đưa vào `resetToDefaults()`. Không tạo kho cài đặt thứ hai.
- `CheckCoordinator` không phụ thuộc `PanelSettings`, đúng như hiện nay. `AppModel` gán `coordinator.isTranslationEnabled` lúc khởi động và mỗi khi giá trị đổi (`withObservationTracking`). Nó cũng gọi `scheduleRelayout()` để panel co hoặc giãn.

## Risks / Trade-offs

- **[Chất lượng dịch của model 7B 4-bit chưa hoàn hảo]** → Đã đo bằng `GrammarBench --translate` (`docs/model-benchmark.md`, mục "Dịch"): sau khi cấm token CJK (§5b), 12/15 câu dịch tốt, 3 câu lỗi nhẹ. Tiêu đề "Bản dịch (tham khảo)" báo cho người dùng biết điều này.
- **[Dịch chiếm GPU đúng lúc người dùng gõ tiếp]** → Câu mới huỷ bản dịch ngay. Debounce 700 ms cũng khiến lần sửa kế tiếp thường đến khi bản dịch đã xong hoặc đã bị huỷ. Bench kiểm tra p95 của bước sửa khi xen kẽ với dịch.
- **[Thêm khoảng 117 MB RAM khi bật]** → Context chỉ được tạo khi bật, và mặc định tắt. Tắt Dịch không giải phóng context ngay (giữ đơn giản), context được giải phóng khi thoát app.
- **[Câu dài làm bản dịch bị cắt do `maxTokens`]** → Hệ số ×4 + 32 dư cho câu tối đa 40 từ, ngưỡng mà spec độ trễ đặt ra. Bench có một câu dài để kiểm tra.
- **[Bản macOS và Windows lệch tính năng]** → Spec `translation` có requirement "Chỉ có trên macOS". Prompt dịch nằm trong một file riêng để port dễ.
- **[Model lỡ "trả lời" câu hỏi thay vì dịch]** → Có ví dụ câu hỏi trong prompt và test tay theo scenario "Câu hỏi" của spec.

## Migration Plan

Không cần migrate. Key `translation.enabled` mới, chưa có thì coi là tắt. Muốn rollback thì tắt công tắc, hoặc revert change.
