# 🛠️ Component Companion

> **Slogan:** Vọc cho biết - Viết cho thông

**Component Companion** là một ứng dụng desktop trên nền tảng Windows được phát triển bằng **Flutter**, nằm trong hệ
sinh thái của kênh kĩ thuật **Vọc Vạch IoT**. Ứng dụng giúp các kỹ sư, sinh viên và người đam mê điện tử quản lý kho
linh kiện vi điều khiển (ESP32, Arduino, CH32V...), danh mục (Category) và các tùy chọn thuộc tính kèm theo một cách
trực quan, tối ưu và khoa học.

---

## ✨ Tính năng nổi bật

- **Quản lý Linh Kiện & Tùy Chọn:** Tổ chức linh kiện theo cấu trúc phân cấp (Component -> Options).
- **Giao diện Technical Dashboard:** Thiết kế trực quan, hỗ trợ hiển thị danh sách theo Grid/List linh hoạt.
- **Hệ thống Màu sắc Đồng nhất:** Sử dụng bảng màu Master Palette (Pastel) được ánh xạ trực tiếp từ danh mục sang thẻ
  linh kiện (Color-Coding) giúp nhận diện nhanh (Nguồn, Cảm biến, Vi điều khiển...).
- **Tìm kiếm & Phân trang Thông minh:** Bộ lọc kết hợp phân trang thời gian thực mượt mà.

## 🏗️ Kiến trúc & Công nghệ sử dụng

Dự án áp dụng các công nghệ hiện đại và tối ưu nhất trong hệ sinh thái Flutter:

- **State Management:** State Notifier kết hợp mã nguồn tự động sinh (**Riverpod Annotation** + **Flutter Hooks**).
- **Local Database:** **ObjectBox DB** — Hệ quản trị cơ sở dữ liệu NoSQL hiệu năng cao, hỗ trợ Reactive Stream tự động
  cập nhật UI khi dữ liệu thay đổi.
- **Architecture:** Mô hình llayered architecture phân tách rõ ràng giữa UI (Widgets), Logic xử lý trạng thái (
  Notifiers), và Tầng dữ liệu (Repositories).

---

## 🚀 Hướng dẫn cài đặt & Chạy dự án

### Yêu cầu hệ thống

- Flutter SDK (Phiên bản mới nhất hỗ trợ Windows Desktop).
- Visual Studio 2022 (Cài đặt gói "Desktop development with C++").

### Các bước thực hiện

1. **Clone dự án:**

   ```bash
   git clone [https://github.com/voc-vach-iot/component-companion.git](https://github.com/voc-vach-iot/component-companion.git)
   cd component-companion
   ```

2. **Cài đặt các gói phụ thuộc (Dependencies):**

   ```bash
   flutter pub get
   ```

3. **Sinh mã nguồn tự động (Build Runner):**
   Vì dự án sử dụng Riverpod Generator và ObjectBox, bạn cần chạy lệnh này để tạo các file `.g.dart`:

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Tạo tài nguyên Icon cho Windows:**
   Nếu đây là lần đầu chạy dự án, hãy build icon cho ứng dụng:

   ```bash
   dart run flutter_launcher_icons
   ```

5. **Chạy ứng dụng ở chế độ Phát triển (Debug):**

   ```bash
   flutter run -d windows
   ```

6. **Đóng gói ứng dụng (Release):**
   ```bash
   flutter build windows
   ```

---

## 📝 Đóng góp dự án (Contributing)

Mọi ý tưởng đóng góp, báo lỗi (issue) hoặc gửi bản vá (Pull Request) đều được chào đón nhằm phát triển cộng đồng **Vọc
Vạch IoT** ngày càng lớn mạnh.

1. Fork dự án.
2. Tạo branch tính năng mới (`git checkout -b feature/AmazingFeature`).
3. Commit thay đổi (`git commit -m 'Add some AmazingFeature'`).
4. Push lên branch (`git push origin feature/AmazingFeature`).
5. Mở một Pull Request.

---

## 📄 Giấy phép (License)

Dự án này được phân phối dưới giấy phép **MIT License** - xem file [LICENSE](LICENSE) để biết thêm chi tiết.

---

📬 **Liên hệ:** Kênh kỹ thuật **Vọc Vạch IoT** _Vọc cho biết - Viết cho thông!_

