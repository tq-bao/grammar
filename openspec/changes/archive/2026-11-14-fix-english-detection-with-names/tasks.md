# Tasks

## 1. Nhận diện tiếng Anh

- [x] 1.1 Sửa `LanguageGate`: đặt `languageHints = [.english: 0.6, .vietnamese: 0.4]` và đổi ngưỡng mặc định thành 0.5. Kiểm tra: `LanguageGateTests` có thêm "Hi, my name is Bao", "ok I will ping Tuan", "my name is Bao" (là tiếng Anh) và "hom nay toi di hoc muon", "anh check giup em cai PR nay nhe", một câu tiếng Đức, một câu tiếng Pháp (không phải tiếng Anh). Toàn bộ test cũ vẫn pass.

## 2. Phát hành

- [x] 2.1 Chạy toàn bộ unit test, chạy `GrammarBench` với model 7B (các chỉ số không giảm), rồi chạy `scripts/install.sh`. Kiểm tra: test pass, benchmark vẫn đạt ngưỡng, app mới được ký bằng "Grammar Local Signing" và đang chạy.
- [x] 2.2 Test tay: gõ "Hi, my name is Bao" trong một app bất kỳ. Kiểm tra: panel không báo "Không phải tiếng Anh" mà báo "Không có lỗi ngữ pháp".
