# Kho thông minh — thiết kế & lộ trình

Quản lý kho ảo (khay, ngăn) trong app, gán linh kiện vào ngăn, AI đề xuất chỗ cất, và khi tìm linh kiện thì app gọi BLE tới module JDY-23 → CH32V003 → dải WS2812 sáng đúng khay.

## 1. Kiến trúc

```
App Flutter ──BLE──▶ JDY-23 ──UART──▶ CH32V003 J4M6 (5V) ──▶ IRLZ44N (cắt GND dải) + WS2812 (≤ 60 LED)
(chọn khay, màu,     (cầu nối trong suốt,   (Standby; thức bằng sườn xuống
 độ sáng, giới        tự ngủ giữa các lần    trên RX khi có kết nối BLE;
 hạn dòng)            quảng bá)              giữ hẹn giờ tắt, nháy, MOSFET)
```

- **JDY-23 là cầu nối trong suốt**: không có firmware riêng, byte app ghi vào characteristic FFE1 ra thẳng UART TX của module, byte CH32 gửi vào RX của module thì thành notify. Toàn bộ logic nằm ở app và CH32.
- **App quyết định mọi thứ** (khay nào, màu gì, độ sáng sau khi giới hạn dòng). Firmware chỉ phát danh sách LED và có thêm 1 lớp chặn dòng an toàn.
- **CH32 giữ MOSFET, hẹn giờ tắt và hiệu ứng nháy**: app gửi lệnh xong là ngắt kết nối được ngay, module BLE tự ngủ giữa các lần quảng bá, không có MCU nào khác phải thức để đếm giờ hay tắt LED.
- App có lớp `LedController` (interface) với 2 bản: `SimulatedLedController` (vẽ LED lên sơ đồ kho, không cần phần cứng) và `BleLedController`.

## 2. Phần cứng

### Nguồn

```
220V → adapter 5V 2.4A ──┬── dải WS2812 (5V)  ── GND dải ── IRLZ44N (D) … (S) ── GND
                         ├── CH32V003 J4M6 (chạy thẳng 5V)
                         └── JDY-23 bản board (có ổn áp, VCC 3.6–6V)
```

Nối dây chi tiết: `smart-storage/NOI-DAY.md`. CH32 chạy 5V (datasheet cho 2.7–5.5V) để DIN và cổng MOSFET có đủ 5V, và để không có đường rò từ dải đang tắt về nguồn 3.3V (xem bên dưới). **JDY-23 bản board cấp thẳng 5V vào VCC**, nhưng chân tín hiệu vẫn ≤ 3.3V. Dây giữa JDY-23 và CH32 (5V): CH32 đọc JDY TX nối thẳng (CH32 chạy 5V đọc HIGH từ 2.61V, TX đo được 3.3V; TX của C3 3.3V từng chạy thật theo cách này), còn đường CH32 → JDY RX là open-drain nên CH32 không bao giờ đưa 5V vào module. RX tự đứng ở 2.7V; chưa chốt có cần thêm 10kΩ kéo lên 3.3V không. PWRC để trống (board nối sẵn xuống GND).

- **Vì sao không cắt nguồn module BLE**: JDY-23 đã tự ngủ giữa các lần quảng bá (lệnh `AT+STARTEN0`). Cắt nguồn module thì mất kết nối đang có và phải khởi động lại module (quảng bá lại từ đầu), chậm hơn nhiều mà tiết kiệm không đáng kể. Số dòng của module lấy từ tài liệu nhà sản xuất, **chưa đo**.
- **Dòng chờ của board JDY-23**: chưa đo. Ổn áp trên board tự tiêu thụ thêm, và module vẫn trả lời AT sau 20s không kết nối nên chưa rõ có ngủ thật không.
- **Sau này chạy pin** (Makita qua mini360, hoặc LiPo): thêm hồ sơ nguồn mới trong app (VD "Makita + mini360 5V 1.8A"). Lưu ý mạch buck như mini360 tự ăn vài mA khi không tải → có thể là thứ tốn điện nhất lúc chờ. Lúc đó cân nhắc cho module BLE + CH32 dùng thẳng pin qua HT7333 (LiPo 3.7–4.2V), chỉ bật buck 5V cho dải LED khi cần sáng.

### MOSFET cắt nguồn dải

- Dùng **IRLZ44N, cắt GND (low-side)**: cổng lái thẳng từ chân CH32 5V (logic-level, 0.025Ω ở Vgs 5V), không cần mạch dịch mức như khi cắt dương bằng P-MOSFET. Trở 100Ω nối tiếp cổng, 100kΩ kéo cổng xuống GND (MOSFET tắt khi CH32 đang khởi động / Standby). 60 LED xanh dương max ~1.2A → tổn hao ~36mW, không cần tản nhiệt.
- ⚠️ Cắt GND thì dải bị "treo" lên 5V: **chân DIN phải về Hi-Z / `ANALOG` khi MOSFET tắt**, nếu không dải được cấp ngược qua chân data (LED sáng lờ mờ, rò dòng). Firmware đảm bảo thứ tự: bật MOSFET → chờ ~1ms → DIN output → phát; tắt: DIN `ANALOG` → tắt MOSFET.
- Cắt GND mà CH32 chạy 3.3V thì vẫn có đường rò: GND dải treo lên ~5V → diode bảo vệ DIN của LED 1 → 330Ω → diode bảo vệ chân PC4 → nguồn 3.3V (cỡ 1mA, HT7333 không hút ngược được). CH32 chạy 5V thì hết rò.
- Không dùng NPD6020 (cắt dương): cổng phải kéo lên đúng 5V mới tắt hẳn. Relay chạy được nhưng kém hơn: cuộn hút ~70mA cần transistor + diode, bật mất 5–10ms (firmware `-DPOWER_ON_SETTLE_MS=30`), kêu tách, module relay có LED nguồn ăn mA liên tục; nếu dùng thì cắt 5V (high-side) — so sánh đầy đủ ở `NOI-DAY.md` §5.

### Mức logic DIN

WS2812 cấp 5V cần DIN ≥ 0.7 × 5V = 3.5V. CH32 chạy 5V nên DIN đủ mức, không cần mẹo hạ VDD LED đầu bằng 1N4148 như khi CH32 chạy 3.3V. Thêm trở 330Ω nối tiếp DIN, tụ 1000µF ở đầu dải.

### Chân CH32V003 J4M6

| Chân | Pad | Chức năng |
| :-: | :-- | :-- |
| 1 | PD6 (URX) | RX ← JDY-23 TX (nhận lệnh từ app, sườn xuống cũng đánh thức CH32); PA1 cùng chân để `ANALOG` |
| 3 | PA2 | không dùng (STAT của board JDY-23 nối GND; CH32 thức bằng sườn xuống trên RX, xem chân 1) |
| 5 | PC1 | TX open-drain → JDY-23 RX (gửi trạng thái), nối thẳng; chưa chốt có cần 10kΩ kéo lên 3.3V không |
| 6 | PC2 | Cổng IRLZ44N (100Ω nối tiếp, 100kΩ xuống GND) |
| 7 | PC4 | DIN WS2812 qua 330Ω (bit-bang, `ch32v003_ws2812`) |
| 8 | PD1 (SWIO) | Để nạp / debug, không dùng làm IO |

Không dùng chân MOSFET làm chân đánh thức: `+CONNECTED` trên TXD chỉ báo có kết nối BLE, còn MOSFET do CH32 tự giữ (hẹn giờ, nháy) kể cả sau khi app ngắt kết nối.

60 LED × 3 byte = 180 byte RAM → dùng thẳng `ch32v003_ws2812` (bộ đệm toàn dải), không cần sửa thư viện. Phát 60 LED bit-bang mất ~1.8ms.

### Module JDY-23

- Tên quảng bá `KhoLED-XXXX`. Service `FFE0` / characteristic `FFE1` (notify + write) là UUID chung của mọi module JDY, chưa chắc có trong gói quảng bá, nên app dò theo **tên** (`ScanFilter(withNamePrefix: ["KhoLED"])`), không dò theo service.
- Module chỉ giữ 1 kết nối. Quảng bá 400ms; thời gian kết nối dự kiến 2–4s (ước tính theo chu kỳ quảng bá, chưa đo) nên app giữ timeout kết nối 8s và giữ kết nối 6s sau lệnh cuối (`idleDisconnect`).
- Module tự ngủ giữa các lần quảng bá nhờ `AT+STARTEN0`. Số dòng chờ lấy từ tài liệu, chưa đo.
- Thiết bị đã ghép trước đây (ESP32-C3, UUID riêng) cần ghép lại trong app.

## 3. Mô hình dữ liệu (ObjectBox)

Chỉ **thêm** entity / property (đã kiểm `objectbox-model.json`: 4 entity mới, không retire gì).

| Entity | Trường chính | Ghi chú |
| :-- | :-- | :-- |
| `TrayType` (Loại khay) | `name`, `widthMm`, `depthMm`, `heightMm`, `stackGapMm` (thanh kê giữa 2 tầng), `compartmentCount`, `compartmentVertical`, `allowedColorsJson` (rỗng = màu tự do), `defaultColor`, `minBrightness`, `maxBrightness`, `note` | Seed v4: **Khay A6** 200×150×120, kê 30mm, 1 ngăn, chỉ xanh dương, sáng tối thiểu 120; **Khay F0** 140×93×34, 3 ngăn, màu tự do |
| `PowerSupply` (Nguồn) | `name`, `voltage`, `currentA`, `derate` (0.8) | Seed: Adapter 5V 2.4A, Adapter 5V 2A |
| `Storage` (Kho) | `name`, `widthMm`, `heightMm`, `gridMm`, `ledCount`, `colorOrder`, `mAPerChannel`, `idleMaPerLed`, `mcuMa`, `lightTimeoutS`, `bleDeviceId`, `bleName`, `powerSupply` → `PowerSupply` | Gộp luôn thông số bộ điều khiển LED vào kho (1 kho = 1 bộ điều khiển). Seed: "Kho chính" 1000×800 |
| `StorageTray` (Khay trong kho) | `storage`, `trayType`, `xMm`, `yMm`, `rotated`, `label` (tự đặt `A6-01`, `F0-02`…), `ledIndex` (−1 = chưa gắn), `removedDividers` | 1 khay = 1 LED |
| `ComponentVariant` (đã có) | + `tray = ToOne<StorageTray>()`, `compartmentIndex` | Không làm entity `Compartment` riêng: ngăn = số thứ tự trong khay. Giữ `location` (chữ tự do) làm ghi chú cũ |

**Vách ngăn tháo được** (`TrayType.removableDividers`, khay F0): loại khay khai số khe (F0 = 3), mỗi khay trong kho tự chọn tháo vách nào — `removedDividers` là mặt nạ bit, bit i = vách giữa khe i và i+1 đã tháo (`lib/util/compartments.dart`). F0: `0` = 3 ngăn, `1` = to | nhỏ, `2` = nhỏ | to, `3` = 1 ngăn. Đổi cách chia ngăn: linh kiện chuyển sang ngăn mới chứa khe đầu của ngăn cũ. Nhãn ngăn ghi "(to)" / "(nhỏ)"; sơ đồ vẽ ngăn theo độ rộng thật; "nháy N lần" theo số thứ tự ngăn hiện tại.

Sao lưu: `DataTransferService` v8 (v6 + vách ngăn ở v7 + màu báo ngăn ở v8) (4 bảng mới + chỗ cất của biến thể), hoàn tác xoá kho / khay nối lại chỗ cất. Lọc "Chưa có chỗ cất" ở trang Linh kiện (`ComponentSearchParams.missingPlace`).

Kích thước F0 bạn ghi "14x9.3.4cm": mình đang hiểu là 140 × 93 × 34mm, sai thì sửa trong app. A6: mình đang hiểu cao 120mm (cộng 30mm kê = 150mm mỗi tầng).

### Thứ tự LED do bạn tự sắp

Trình sửa kho có **chế độ "Nối dây LED"**: bấm lần lượt từng khay theo đúng đường đi thật của dải → khay nhận LED 1, 2, 3… (nút −/+ để lùi / bỏ qua LED, "Từ đầu"). LED đã có chủ thì 2 khay đổi LED cho nhau. Menu "Đánh số LED" điền nhanh theo hàng / cột / zig-zag; sửa tay từng khay ở panel phải. Nút **"Sáng thử tất cả"** / "Sáng khay này" để đối chiếu với dây thật.

## 4. Màu & độ sáng

- **Màu báo ngăn** (`TrayType.compartmentColorsJson`, sửa trong hộp thoại Loại khay): khay màu tự do đang chia nhiều ngăn → ngăn 1 **đỏ**, ngăn 2 **xanh lá**, ngăn 3 **xanh dương** (thuần, mặc định), LED sáng liên tục. Khay gộp còn 1 ngăn → `defaultColor`.
- Vì sao màu thuần: WS2812 có 3 LED con R/G/B, dòng ≈ (R + G + B) / 255 × `mAPerChannel`. Màu thuần chỉ bật 1 kênh → ~20mA ở 255; màu trộn bật 2–3 kênh (đỏ 1744 cũ ~27mA, vàng ~38mA, trắng ~60mA). Cùng mức sáng, xanh lá trông sáng nhất, xanh dương tối nhất.
- Khay màu cố định (A6 chỉ xanh dương): màu không báo được ngăn → khay nhiều ngăn **nháy N lần rồi nghỉ** (N = số ngăn).
- Tìm nhiều linh kiện một lúc: màu vẫn báo ngăn, linh kiện phân biệt bằng kiểu nháy theo thứ tự (sáng / nháy chậm / nháy nhanh); sơ đồ trong app ghi tên từng khay.
- Màu chọn tay khi tìm (nếu khay cho phép) được ưu tiên hơn màu báo ngăn.
- Seed v6: màu seed cũ trộn kênh (A6 `0050FF`, F0 `00E676`) đổi sang thuần (`0000FF`, `00FF00`) nếu người dùng chưa sửa. Bảng màu chọn nhanh xếp màu 1 kênh lên đầu.
- `minBrightness` theo loại khay (nhựa A6 dày cần sáng hơn). Áp gamma 2.2 trước khi gửi.

## 5. Giới hạn dòng theo nguồn

```
ngân sách  = currentA × derate × 1000 − mcuMa − idleMaPerLed × ledCount   (mA)
cần        = Σ_LED đang sáng (R + G + B) / 255 × mAPerChannel
hệ số      = min(1, ngân sách / cần)      → nhân vào độ sáng mọi LED
```

- Với 60 LED và nguồn 5V 2.4A: ngân sách ≈ 2400 × 0.8 − 120 − 36 ≈ 1760mA. Sáng cả 60 khay A6 xanh dương max (~1.2A) vẫn không bị giới hạn. Chỉ bị giới hạn khi F0 sáng trắng nhiều khay (60mA/LED) hoặc khi dùng nguồn nhỏ (mini360 ~1.8A, pin yếu).
- Nếu độ sáng sau giới hạn < `minBrightness` của khay → **chia lượt** (sáng lần lượt từng nhóm) thay vì sáng mờ hết.
- Hàm tính thuần Dart `LedPlanner` (`lib/util/led_plan.dart`) + unit test. Firmware CH32 nhận `maxMa` qua lệnh CONFIG và tự cắt thêm lần nữa.

## 6. Giao thức

Định nghĩa chung: `smart-storage/include/storage_protocol.h` (firmware) ↔ `lib/util/led_protocol.dart` (app).

### BLE (App ↔ JDY-23 ↔ CH32)

- Service `0000ffe0-0000-1000-8000-00805f9b34fb`, characteristic `0000ffe1-0000-1000-8000-00805f9b34fb` (notify + write, dùng chung cho lệnh và trạng thái).
- Khung: `[ver=1][cmd][seq][payload…][crc8]`, crc8 đa thức 0x07 (CRC-8/SMBUS).
- Trên dây: `[0xA5][độ dài khung][khung]`. Tổng số byte (khung SHOW 38 LED = 237 + 2 = 239 byte) chia thành các lần ghi ≤ 20 byte, ghi có phản hồi, tuần tự (không dùng MTU).

| cmd | Tên | Payload |
| :-: | :-- | :-- |
| 0x01 | PING | — → trạng thái kèm `fw major, minor, ledCount` |
| 0x02 | CONFIG | `ledCount u8`, `colorOrder u8`, `maxMa u16`, `mAPerChannel u8` |
| 0x10 | SHOW | `timeoutS u16`, `rotateMs u16`, `n`, rồi n × `led, r, g, b, effect, group` (6 byte) |
| 0x11 | OFF | — |
| 0x12 | APPEND | `n`, n × 6 byte — thêm vào SHOW trước (1 khung chứa tối đa 38 LED) |

- `effect`: 0 sáng, 1 nháy chậm (1s), 2 nháy nhanh (0.3s), 3–5 nháy 1–3 lần rồi nghỉ 1s. `group`: lượt sáng khi nguồn không đủ, firmware luân phiên mỗi `rotateMs`. App (giả lập) và firmware dùng chung công thức nhịp (`LedEffect.isOnAt` ↔ `spEffectIsOn`).
- Trạng thái (CH32 → JDY TX → notify): `[0xA5][độ dài][ver][0x80|cmd][seq][code][extra…][crc8]`, code 0 OK, 1 khung hỏng (sai crc), 3 lệnh lạ (mã 2 NO_ACK đã bỏ vì không còn cầu nối). PING có extra `[major][minor][ledCount]`. Notify có thể bị chia nhỏ hoặc gộp, có thể có byte rác đằng trước: app ghép bằng `LedStatusParser` (chờ `0xA5`, độ dài hợp lệ 4–240, nhận đủ, kiểm crc, tự hồi phục khi độ dài sai).
- App: kết nối → tìm dịch vụ → đăng ký notify → ghi từng khung (chia ≤ 20 byte), chờ trạng thái đúng `seq` (2s, tính từ khi ghi xong byte cuối) → ngắt kết nối sau 6s rảnh. Lỗi tầng BLE thử lại 1 lần. Linux: lần đầu đánh dấu thiết bị *Trusted* trong BlueZ.

### CH32

1. Có kết nối BLE thì JDY-23 in `+CONNECTED` ra TXD: sườn xuống trên PD6 (chân RX) đánh thức CH32 khỏi Standby, bật UART (nhận bằng ngắt, bộ đệm vòng).
2. CH32 ghép dòng byte: chờ `0xA5`, độ dài 4–240, nhận đủ, kiểm crc, rồi mới thi hành. Byte rác trước `0xA5` bị bỏ.
3. CH32 gửi khung trạng thái qua PC1 (TX open-drain) → JDY RX → notify về app.
4. CH32 tự lo nháy, luân phiên lượt, hẹn giờ; chặn dòng lần 2 bằng `ws2812SetBrightness`. Hết giờ / OFF → DIN `ANALOG`, tắt MOSFET, rảnh thì Standby.

## 7. Kiểm thử

| Bước | Phần | Trạng thái |
| :-: | :-- | :-- |
| 0 | App | ✅ 226 test (giới hạn dòng, chia lượt, khung + crc, thứ tự LED, kho / khay / chỗ cất, sao lưu + hoàn tác, gợi ý chỗ cất + đọc câu trả lời AI, trang Kho) |
| 1 | ESP32 BLE (cũ, bỏ) | ✅ Bản ESP-IDF + NimBLE trên dev module (env `esp32dev_bridge`, không lái chân nào vì GPIO16/17 của bàn test đang nối vào chip CH32). Test tự động `smart-storage/test/ble_bridge.py` (bleak, đóng vai app): kết nối, MTU 247, PING, CONFIG, SHOW 38 LED (237 byte), APPEND, sai crc, lệnh lạ, OFF, đọc trạng thái — 50/50 đạt qua 5 lượt. Kết nối lại 0.7–1.3s (bản Arduino 1.5–2.2s), mỗi lệnh ~30ms. Log Serial 115200, lệnh thử: `help`, `ping`, `demo`, `off`, `stat`, `pm`, `raw <hex>`. C3: mới build (chưa có board cắm vào máy) |
| 2 | CH32 | ✅ Test hộp đen `smart-storage/test/hil_kho.py` trên J4M6 của bàn HIL: **19/19 đạt, 3 lần liên tiếp** (sau khi chuyển sang đánh thức bằng PA2 + ACK open-drain; thêm bước "không có xung WAKE thì không thức") — đánh thức + UART + ACK (~17µs), crc sai / byte rác, nháy chậm đúng pha tắt / sáng, APPEND, OFF (cổng MOSFET LOW, DIN Hi-Z), chặn dòng (2 LED trắng, maxMa 100 → 212), luân phiên lượt, nháy theo ngăn, hẹn giờ tự tắt, thức 5 lần liên tiếp. Bàn test có lệnh mới `UTX <ch> <hex> [~ackCh] [breakMs] [wakeCh]`. Dòng Standby: bỏ qua (không đo) |
| 3 | Ghép (cũ, C3) | ✅ C3 SuperMini (env `esp32c3_bridge`: GPIO4 → chân 1, GPIO5 → chân 3, GPIO3 ← chân 5, nối thẳng) + J4M6 + IRLZ44N + dải thật (2026-10-23): `test/ble_bridge.py` 30/30 qua 3 lượt, CH32 ACK lần 1 mọi lệnh; màu / kiểu nháy (sáng, nháy 2 lần, nháy nhanh) đúng khi nhìn. ✅ Light sleep (bộ đếm `CONFIG_PM_PROFILING`, chạy adapter ~7 phút rồi cắm USB đọc lệnh `pm`, chip không reset): ngủ ~92% thời gian lúc rảnh, 709 lần ngủ / 0 lần bị từ chối; phần thức chủ yếu do BLE (khóa `bt` 9%, ~39ms mỗi lần) → ước tính C3 ~2–3mA trung bình (chưa đo trực tiếp; đồng hồ USB chỉ đọc được ≥ ~15mA). ⬜ App ghép lại thiết bị mới `KhoLED-2B52` |

## 8. Lộ trình

- [x] **P1. Loại khay & nguồn** — tab Loại khay / Nguồn ở trang "Kho thông minh", seed v4, sao lưu v6.
- [x] **P2. Trình sửa kho** — kéo thả (bắt dính lưới + mép khay khác, phím mũi tên dịch, Delete xoá, Shift/Ctrl chọn nhiều), thêm khay bằng kéo hoặc bấm (tự tìm chỗ trống), xoay, nhân bản, xoá có hoàn tác, báo khay chồng nhau (viền đỏ), nối dây LED + đánh số tự động.
- [x] **P3. Gán linh kiện** — kéo linh kiện "Chưa có chỗ" thả vào ngăn; panel khay thêm / bỏ linh kiện từng ngăn; cột Vị trí ở trang Linh kiện bấm để chọn chỗ; lọc "Chưa có chỗ cất".
- [x] **P4. Tìm & chiếu sáng** — nút 💡 ở dòng biến thể, "Sáng cả BOM" ở chi tiết dự án, LED nhấp nháy giả lập trên sơ đồ (đúng nhịp firmware), thanh "Đang sáng … còn Xs · mA" + Tắt LED, giới hạn dòng / chia lượt.
- [x] **P5. Gợi ý chỗ cất** — chấm điểm theo luật (ngăn trống, cồng kềnh ↔ khay to, gần linh kiện cùng loại / danh mục, có LED) + nút "Hỏi AI" chọn trong 30 ngăn điểm cao nhất.
- [x] **P6. Firmware ESP32 BLE** — bản Arduino chạy trên dev module (đã thay bằng P9).
- [x] **P7a. Firmware CH32** — viết xong, build sạch.
- [x] **P7b.** `UTX` cho bàn test + test hộp đen trên J4M6 (18/18). Sửa theo kết quả test: CH32 chỉ phát đúng `ledCount` LED (trước luôn phát 60), ACK gửi trước khi phát LED (SHOW từ 4ms xuống ~40µs), chân ACK / MOSFET về Hi-Z khi ngủ.
- [x] Vách ngăn tháo được cho khay F0 (app 1.13.0).
- [x] **P8a. BLE trong app** — ghép thiết bị, "Thử kết nối", gửi lệnh thật.
- [x] **P8b.** Ghép thật C3 + CH32 + dải LED (bước test 3).
- [x] **P9. Firmware C3 tiết kiệm điện** — viết lại tầng BLE bằng ESP-IDF 6 + NimBLE + light sleep; test BLE trên dev module 50/50. Chưa chạy trên C3 thật.
- [x] Nạp `esp32c3_bridge` lên C3 SuperMini, chạy với CH32 + dải thật.
- [x] Kiểm tra C3 light sleep khi chạy adapter: ngủ ~92% thời gian lúc rảnh.
- [ ] **P10. Đo & tinh chỉnh** — `mAPerChannel`, `idleMaPerLed` thật, `minBrightness` qua nhựa A6.
- [ ] Còn lại từ đề xuất: sáng khay đề xuất ngay sau khi nhập hàng từ Shopee; trừ kho sau khi nhặt theo BOM; số biến thể chưa có chỗ trên Tổng quan.

## 9. Còn cần chốt

1. Kích thước F0 đúng là 140 × 93 × 34mm? A6: chiều cao là 120 hay 150mm? (sửa trong tab Loại khay)

## 10. Chuyển sang JDY-23 (app 1.17.0)

App đã đổi sang giao thức JDY-23 (UUID FFE0/FFE1, khung bọc `0xA5`, ghi ≤ 20 byte, `LedStatusParser`); test thuần Dart ở `test/util/led_protocol_test.dart`. Firmware CH32 theo đặc tả này do repo firmware làm. ⬜ Chưa thử trên phần cứng JDY-23 thật; thời gian kết nối và dòng chờ chưa đo.
