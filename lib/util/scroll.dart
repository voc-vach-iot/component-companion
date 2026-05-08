import 'package:flutter/material.dart';

class ScrollUtils {
  static void scrollToBottom(ScrollController controller) {
    // Đợi UI render xong rồi mới cuộn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
