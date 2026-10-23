# Quy tắc lưu và quản lý linh kiện

Tài liệu này mô tả cách đặt tên, chia thuộc tính và nhập giá sao cho khớp với cách
Component Companion hoạt động: tồn kho, so giá và gợi ý mua đều dựa trên các quy tắc này.

## 1. App có 4 tầng

| Tầng | Dùng để | Ví dụ |
|---|---|---|
| **Danh mục** | Nhóm lớn | `Linh kiện thụ động` |
| **Loại** | Chủng loại cụ thể (có sẵn, khá chi tiết) | `Tụ hóa`, `Tụ gốm`, `Tụ dán (SMD)` |
| **Linh kiện** | Một dòng sản phẩm thuộc loại đó: tên, ảnh, mô tả, tìm kiếm | `Tụ hóa` |
| **Biến thể** | Một tổ hợp thông số cụ thể: **tồn kho, vị trí, chọn trong dự án, so giá** | `100uF · 16V` |

Bên dưới biến thể là **tuỳ chọn mua** (shop + quy cách gói + giá + link). Một tuỳ chọn có thể
gắn nhiều biến thể.

Hai điều app dựa vào:

- **Tồn kho nằm ở biến thể**, không nằm ở linh kiện.
- **Chỉ so giá giữa các tuỳ chọn gắn cùng một biến thể.**

Vậy những thứ khác giá, khác tồn kho hoặc khác cách dùng thì **không được gộp chung một biến thể**.

## 2. Chọn loại trước

1. Tìm loại có sẵn khớp nhất (bộ lọc "Loại" ở trang Linh kiện, hoặc để app tự nhận diện theo tên).
2. Không tạo loại mới theo thông số (`Tụ hóa 100uF` là sai).
3. Chỉ tạo loại mới khi đó là một chủng loại thật sự chưa có.

## 3. Tách thuộc tính hay tách linh kiện riêng?

Một khác biệt nên là **thuộc tính** khi cả 4 câu đều trả lời "có":

1. Khi mua, bạn chọn thông số này trên **cùng một trang sản phẩm** (hoặc shop bán như cùng một dòng hàng).
2. Mọi biến thể **dùng chung** loại, ảnh, mô tả.
3. Khác biệt chỉ là **giá trị** của một thông số: số + đơn vị, màu, kích thước, kiểu.
4. Các giá trị **có thể thay thế nhau** về cách lắp (cùng kiểu chân, cùng footprint).

Có câu trả lời "không" thì tạo **linh kiện riêng**.

| Khác biệt | Cách làm | Lý do |
|---|---|---|
| Tụ hóa và tụ gốm | 2 loại, 2 linh kiện | Khác chủng loại |
| Điện trở cắm và điện trở dán | 2 loại, 2 linh kiện | Khác cách hàn |
| Tụ dán 0805 và 0603 | 2 linh kiện cùng loại `Tụ dán (SMD)` | Khác footprint |
| ESP32 DevKit và ESP32-C3 SuperMini | 2 linh kiện cùng loại `Board ESP32` | Khác board |
| 100uF và 1000uF | Thuộc tính `Điện dung` | Chỉ khác giá trị |
| Còi Active và Passive, 3V và 5V | Thuộc tính `Kiểu`, `Điện áp` | Chọn trên cùng trang |
| Vít và đai ốc | 2 linh kiện `Vít`, `Đai ốc` | Khác chủng loại, khác bộ thông số (đai ốc không có chiều dài) |

**Giới hạn:**

- Nên 1–3 thuộc tính, mỗi thuộc tính dưới khoảng 15 giá trị.
- Mọi biến thể của 1 linh kiện có **cùng bộ thuộc tính**. Thuộc tính chỉ đúng với một phần biến
  thể (VD chiều dài chỉ có ở vít, không có ở đai ốc) là dấu hiệu nên **tách linh kiện riêng**.
- Thông số bạn không quan tâm khi chọn mua hoặc chọn dùng (VD nhiệt độ 85°C/105°C) thì
  **không tạo thuộc tính**, ghi vào mô tả.

## 4. Đặt tên linh kiện

- **Tên = tên dòng sản phẩm, không chứa giá trị thuộc tính.**
  - Đúng: `Tụ hóa`, `Còi chíp`, `Vít`
  - Sai: `Tụ hóa 100uF`, `Tụ hóa 100uF 16V`
- **Loại chỉ có một dòng sản phẩm** (hay gặp ở linh kiện thụ động): tên trùng hoặc gần trùng tên loại.
- **Loại có nhiều dòng sản phẩm:** thêm phần cố định giúp phân biệt.
  - Kiểu chân / package: `Tụ dán 0805`, `Điện trở dán 0603`
  - Công suất: `Điện trở 1/4W`
  - Model: `ESP32-C3 SuperMini`
- **Mã linh kiện cụ thể là tên**, không làm thuộc tính: `LM2596`, `Servo SG90`, `ESP32-WROOM-32`.
- **Có dấu tiếng Việt, viết hoa chữ đầu**: `Nút nhấn tact`, không viết `Nut nhan tact`.
  Tìm kiếm có tuỳ chọn bỏ dấu nên gõ không dấu vẫn ra.
- **Không đưa shop, giá, quy cách gói vào tên** (`... (Shopee)`, `... gói 100`). Những thứ
  này thuộc về tuỳ chọn mua.

> **Lưu ý:** ô tìm kiếm ở trang Linh kiện **chỉ tìm theo tên linh kiện**, không tìm theo giá trị
> thuộc tính. Gõ "100uF" sẽ không ra; hãy tìm `tụ hóa` rồi xem bảng biến thể. Đây là lý do tên
> phải là tên dòng sản phẩm, dễ đoán.

## 5. Thuộc tính và giá trị

### Đặt tên

- **Tên thuộc tính:** danh từ ngắn, dùng **giống nhau giữa các linh kiện**: `Điện dung`, `Điện áp`,
  `Điện trở`, `Màu`, `Chiều dài`, `Kích thước`, `Kiểu`.
- **Giá trị:** viết một kiểu thống nhất, có đơn vị, không dấu cách: `0.1uF`, `16V`, `10K`, `4.7K`, `5mm`.
  - Không trộn `10k`, `10 K`, `10KΩ` trong cùng một thuộc tính: app coi đó là các giá trị khác nhau.
  - Số thập phân dùng dấu chấm: `0.1uF`, không viết `0,1uF`.
  - Nên dùng một tiền tố cho cả dãy (`0.1uF, 1uF, 10uF`), không trộn `100nF` với `1uF`. App vẫn
    sắp đúng nếu trộn, nhưng nhìn sẽ khó đọc.

### Thứ tự

- **Thuộc tính:** thông số chính lên đầu (`Điện dung` trước `Điện áp`). Nhãn biến thể hiện theo
  thứ tự này: `100uF · 16V`. Dùng nút **↑ / ↓** bên trái mỗi thuộc tính để đổi thứ tự.
- **Giá trị:** tăng dần. App hiểu giá trị số có tiền tố:
  - `22pF < 100nF < 0.1uF < 0.22uF < 1uF`
  - `220R < 1K < 4K7 < 10K < 1M`
  - `5mm < 8mm < 10mm`, `M2 < M3 < M10`
- Danh sách **đang tăng dần** thì giá trị mới (VD `0.22uF`) **tự chèn đúng chỗ**. Danh sách đang lộn
  xộn thì bấm nút **Sắp xếp** (biểu tượng ≡) bên phải để xếp lại. Muốn thứ tự riêng (VD màu
  `Đỏ, Xanh, Vàng`) thì **kéo thả** giá trị.

### Sửa và xoá

- **Sửa cách viết** (VD `0.1u` thành `0.1uF`): **bấm vào giá trị** để sửa. Biến thể đang dùng giá trị
  đó đi theo tên mới, không mất tồn kho / giá. Sửa tên thuộc tính cũng vậy.
- **Đừng xoá rồi thêm lại** để sửa tên. Xoá một giá trị đang có biến thể dùng thì khi lưu, các biến
  thể đó bị **gộp vào giá trị đầu tiên còn lại** (cộng dồn tồn kho). App sẽ hỏi lại trước khi xoá.
- Xoá cả một thuộc tính: các biến thể chỉ khác nhau ở thuộc tính đó bị gộp lại.

## 6. Biến thể

- **Chỉ tạo biến thể bạn đang có hoặc hay mua.** Không cần tạo đủ mọi tổ hợp. Nút **Tạo nhiều**
  cho phép chọn một phần giá trị của từng thuộc tính.
- Cần thêm giá trị mới (VD mua thêm `0.22uF`): sửa linh kiện, thêm giá trị vào thuộc tính, rồi
  **Thêm biến thể** cho tổ hợp đó.
- Tồn kho để trống = chưa theo dõi. Đặt **Cảnh báo khi còn ≤** để biến thể hiện ở mục
  "Sắp hết" của trang Tổng quan.
- Ghi **vị trí cất** theo từng biến thể (VD `Khay A - ô 3`).

## 7. Tuỳ chọn mua

- **Tên tuỳ chọn = quy cách gói của shop**: `1 cái`, `Gói 10 cái`, `Gói 100 cái`. Không lặp lại
  thông số: phần "áp dụng cho biến thể" đã lo việc đó. Tên được phép trùng giữa các biến thể.
- **Cùng giá cho nhiều biến thể:** tạo **một** tuỳ chọn, gắn tất cả biến thể đó.
- **Giá khác nhau theo biến thể:** tạo tuỳ chọn riêng. Dùng **Nhân bản** để điền nhanh rồi đổi giá
  và biến thể. Bản nhân bản có lịch sử giá riêng, không kế thừa giá cũ.
- **Giá thay đổi:** sửa giá của tuỳ chọn đó, giá cũ được lưu vào lịch sử. Giá vẫn vậy thì chọn
  **Giá vẫn vậy** để cập nhật ngày kiểm tra.
- **Đổi shop / quy cách / số cái mỗi gói** = coi như chào giá khác, lịch sử giá bắt đầu lại.
- **Shop** chọn từ danh sách (gõ tên mới để tạo). Shop đổi tên thì sửa ở trang **Shop**; lỡ tạo
  trùng thì dùng **Gộp vào**.
- **Combo / bộ** (1 lần mua nhận nhiều linh kiện khác nhau): bật **Combo** trong dialog tuỳ chọn
  mua rồi liệt kê từng thành phần + số cái, VD `Combo LCD1602 + I2C` = LCD1602 ×1 + Module PCF8574
  ×1; `1 cặp` XT60 = đực ×1 + cái ×1; `Vít kèm ốc` = Vít M3 · 10mm ×100 + Đai ốc M3 ×100. Mỗi thứ vẫn là
  **linh kiện / biến thể riêng** (không tạo linh kiện "LCD1602 + I2C"). Combo hiện ở mọi linh kiện
  trong nó; trang Cần mua tự chọn combo khi rẻ hơn mua lẻ và nhập kho cộng cho cả bộ. Mua lẻ thì
  tạo thêm tuỳ chọn thường như bình thường. Khi **nhập từ Shopee**: gán dòng vào linh kiện chính
  (LCD, đầu đực, vít) rồi bấm biểu tượng combo trên dòng (dòng có chữ "combo", "+", "kèm", "cặp"
  được gợi ý sẵn) để thêm các thành phần còn lại, chọn tay hoặc **Nhờ AI tách combo**. Linh kiện
  mới chưa có biến thể thì bấm **+** cạnh ô thành phần để tạo biến thể ngay (VD đầu cái), rồi
  điền biến thể cho chính dòng (đầu đực). Ở trang Linh kiện có thể bấm **Ctrl+V** thay cho nút
  "Thêm từ Shopee".
- **Shop trên Shopee có hậu tố ` (Shopee)`** trong tên shop, VD `Flash Electric (Shopee)`, để
  phân biệt với cửa hàng ngoài cùng tên. Khi nhập từ bookmarklet / link `shopee.vn` app tự thêm hậu
  tố (không thêm 2 lần) và gợi ý đổi tên shop cũ còn thiếu hậu tố. Tên **linh kiện** vẫn không có
  `(Shopee)` (mục 4).

## 8. Bảng mẫu

| Loại | Tên linh kiện | Thuộc tính |
|---|---|---|
| Tụ hóa | Tụ hóa | Điện dung: 10uF, 100uF, 470uF, 1000uF · Điện áp: 16V, 25V, 50V |
| Tụ gốm | Tụ gốm | Điện dung: 22pF, 100nF, 1uF |
| Tụ dán (SMD) | Tụ dán 0805 | Điện dung: 100nF, 1uF, 10uF |
| Điện trở cắm (1/4W) | Điện trở 1/4W | Điện trở: 220R, 1K, 4.7K, 10K |
| Điện trở dán (SMD) | Điện trở dán 0805 | Điện trở: 0R, 1K, 10K |
| Còi / Buzzer | Còi chíp | Kiểu: Active, Passive · Điện áp: 3V, 5V, 12V |
| Nút nhấn tact | Nút nhấn tact | Kích thước: 6x6x5mm, 12x12mm · Màu: Đỏ, Xanh |
| Vít / Ốc / Đai ốc | Vít | Ren: M2, M3, M4 · Chiều dài: 6mm, 10mm, 20mm |
| Vít / Ốc / Đai ốc | Đai ốc | Ren: M2, M3, M4 |
| LED đơn (3mm/5mm) | LED 5mm | Màu: Đỏ, Xanh lá, Vàng, Trắng |
| Board ESP32 | ESP32-C3 SuperMini | (không có, chỉ có biến thể Mặc định) |

## 9. Nhập từ file đơn hàng

- Bấm **Tải file mẫu** ở trang Dữ liệu rồi điền theo các cột. Dữ liệu từ bookmarklet Shopee thì
  bấm **Thêm từ Shopee** ở trang Linh kiện.
- App gợi ý linh kiện có sẵn cho từng dòng: **trùng link** tuỳ chọn mua (chỉ cập nhật giá) →
  **trùng tên** → **đoán theo tên**. Kiểm tra lại các dòng "Khớp sẵn?" (đoán) trên màn xem trước
  và đổi linh kiện / biến thể nếu sai.
- Cột **Thuộc tính** ghi dạng `Điện dung=100uF; Điện áp=16V`. Tên thuộc tính và cách viết giá trị
  phải khớp mục 5, nếu không sẽ thành giá trị / biến thể mới.
- Cột **Phân loại** là tên tuỳ chọn mua (quy cách gói, mục 7).
- Cột **Trạng thái** (bookmarklet tự điền): đơn chưa giao => số lượng vào **Đang về**, đơn đã huỷ =>
  không cộng kho.

## 10. Checklist khi thêm linh kiện mới

1. Đã có loại phù hợp chưa? Chọn loại đó.
2. Linh kiện cùng dòng sản phẩm đã tồn tại chưa? Có rồi thì **thêm giá trị / biến thể** vào nó,
   không tạo linh kiện mới.
3. Tên không chứa giá trị thuộc tính, có dấu, đúng mục 4.
4. Thuộc tính đặt tên thống nhất, giá trị đúng cách viết, thông số chính lên đầu.
5. Chỉ tạo các biến thể đang có / hay mua; nhập tồn kho, vị trí.
6. Thêm tuỳ chọn mua: chọn shop, quy cách gói, giá, gắn đúng biến thể.
