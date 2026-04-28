import 'package:flutter/material.dart';

class AppColors {
  // --- CORE COLORS ---
  static const Color primary = Color(0xFFB5C8D9);
  static const Color primarySoft = Color(0xFFB8E6D9);
  static const Color primaryLight = Color(0xFFF0FDFB);

  // --- SURFACE & BACKGROUND ---
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFAFBFC);
  static const Color surfaceVariant = Color(0xFFE8EAEF);

  // --- ACTION COLORS (Cập nhật theo yêu cầu) ---
  static const Color actionAdd = Color(0xFFB8E6D9);
  static const Color actionAddHover = Color(0xFFA5D6C8);

  // Edit: #213040 (Icon/Base), #c1d6e6 (Hover)
  static const Color actionEdit = Color(0xFF213040);
  static const Color actionEditHover = Color(0xFFC1D6E6);

  // Delete: #602020 (Icon/Base), #e3cbd1 (Hover)
  static const Color actionDelete = Color(0xFF602020);
  static const Color actionDeleteHover = Color(0xFFE3CBD1);

  // --- NEUTRAL & TEXT ---
  static const Color textMain = Color(0xFF1E242B);
  static const Color textMuted = Color(0xFF67727E);
  static const Color textDisabled = Color(0xFF94A3B8);

  static const Color border = Color(0xFFDDE1E8);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // --- STATUS ---
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFE11D48);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0284C7);

  // --- FUNCTIONAL ---
  static const Color inputBg = Color(0xFFDDE1E8);
  static const Color sidebarBg = Color(0xFFF6F8FA);
  static const Color sidebarHover = Color(0xFFEBEFF5);
  static const Color sidebarActive = Color(0xFFB5C8D9);
  static const Color sidebarBorder = Color(0xFFDDE2EA);
  static const Color sidebarHeader = Color(0xFFF8FAFC);

  // --- TOAST & ALERTS ---
  static const Color toastBackground = Colors.white;
  static const Color toastText = Color(0xFF1E242B);
  static const Color toastShadow = Color(0x14000000);

  // --- CÁC MÀU KHÁC ---
  static const Color searchBarHint = Color(0xFF67727E);
  static const Color textFieldFill = Color(0xFFDDE1E8);
  static const Color transparent = Colors.transparent;
  static const Color searchBarBg = Color(0xFFDDE1E8);
}
