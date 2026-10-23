# Component Companion

App Flutter desktop (Linux / Windows) quản lý linh kiện điện tử: linh kiện → biến thể (đơn vị tồn kho) → tùy chọn mua theo shop, dự án, danh sách cần mua. Dữ liệu ObjectBox, state Riverpod + flutter_hooks. Giao diện, comment và commit viết tiếng Việt.

## Lệnh

- Test (cần thư viện native ObjectBox): `LD_LIBRARY_PATH=/mnt/data/.system/applications/component-companion/lib flutter test`
- Kiểm tra tĩnh: `flutter analyze` (phải sạch, kể cả info)
- Sinh code (entity, mapper, provider): `dart run build_runner build --delete-conflicting-outputs`
- Đóng gói Linux: `task release-linux` → `deploy/component-companion-<version>-linux-x64.tar.gz`

## Quy tắc

### Sau mỗi đợt sửa: tự build và cài bản mới

Xong một đợt thay đổi (`flutter analyze` sạch, toàn bộ test qua) thì **không cần hỏi**, tự làm:

1. Tăng `version` trong `pubspec.yaml`: sửa lỗi → tăng patch (`1.4.0+9` → `1.4.1+10`), thêm tính năng → tăng minor (`1.4.0+9` → `1.5.0+10`). Số build sau dấu `+` luôn tăng 1.
2. `task release-linux`.
3. Giải nén gói vào thư mục tạm (scratchpad), rồi copy **đè bằng file mới** vào thư mục cài:
   `cp -a --remove-destination <thư mục giải nén>/component-companion-<version>-linux-x64/. /mnt/data/.system/applications/component-companion/`
   (App thường đang mở: `cp` thường sẽ lỗi "Tập tin văn bản đang bận" và ghi đè `.so` đang chạy; `--remove-destination` tạo file mới nên phiên đang chạy không bị ảnh hưởng.)
4. Chạy `./install.sh` trong thư mục cài.
5. Báo version mới; nếu app đang chạy (`pgrep -a component_compa`) thì nhắc khởi động lại.

Trước khi cài bản có đổi schema ObjectBox, chép thư mục DB `$XDG_DATA_HOME/component-companion/database` sang `database.bak-<version cũ>-<ngày>`.

Không tự commit / push; chỉ commit khi được yêu cầu (commit thẳng lên `main`).

### ObjectBox

- Sau mỗi lần chạy build_runner, diff `lib/objectbox-model.json` với HEAD: chỉ được **thêm** id / property, không được retire hay tạo lại entity (sẽ mất dữ liệu).
- Không viết getter trả về kiểu record trên entity (làm generator lỗi, từng tạo lại entity `Project`) — dùng method.
- Thêm entity / field mới: cập nhật `DataTransferService` (sao lưu) và tăng `version` định dạng sao lưu.

### Dữ liệu cá nhân

- `TASKS.md` là ghi chú riêng, không commit (đã trong `.gitignore`).
- `.tmp/` chứa HTML trang Shopee có dữ liệu cá nhân: không copy vào test hay commit.
- API key AI (`ai.apiKey`) không được vào file sao lưu.

### Khác

- Quy tắc đặt tên / phân loại linh kiện: `docs/quy-tac-linh-kien.md`.
- Bookmarklet Shopee (`assets/bookmarklet/shopee_orders.js`): chỉ dựa vào chữ hiển thị và thuộc tính ổn định (aria-*, href, alt), **không dựa vào class** (Shopee đổi tên class sau mỗi lần build). Chỉ dùng comment khối và luôn có `;` vì bị gộp thành 1 dòng.
