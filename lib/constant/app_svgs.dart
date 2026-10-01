/// Các icon SVG dùng làm mặc định khi chưa có / SVG lỗi (style Lucide, ISC).
class AppSvgs {
  AppSvgs._();

  static const String _open =
      '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
      'fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round">';

  /// Hộp (lucide "box") - mặc định cho danh mục.
  static const String box =
      '$_open<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/>'
      '<path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/></svg>';

  /// Con chip - mặc định cho linh kiện / loại linh kiện.
  static const String chip =
      '$_open<rect x="6" y="3" width="12" height="18" rx="1"/><path d="M6 7H3"/><path d="M6 12H3"/>'
      '<path d="M6 17H3"/><path d="M18 7h3"/><path d="M18 12h3"/><path d="M18 17h3"/>'
      '<path d="M10.5 3a1.5 1.5 0 0 0 3 0"/></svg>';
}
