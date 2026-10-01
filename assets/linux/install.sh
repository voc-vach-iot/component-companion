#!/bin/bash

# Kiểm tra nếu người dùng lỡ chạy bằng sudo thì cảnh báo/chuyển về USER thực sự
if [ "$EUID" -eq 0 ] && [ -n "$SUDO_USER" ]; then
    USER_HOME=$(eval echo "~$SUDO_USER")
    TARGET_DIR="$USER_HOME/.local/share/applications"
else
    TARGET_DIR="$HOME/.local/share/applications"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
APP_BINARY="$SCRIPT_DIR/component_companion"
APP_ICON="$SCRIPT_DIR/component-companion.png"
DESKTOP_SRC="$SCRIPT_DIR/component-companion.desktop"
DESKTOP_DEST="$TARGET_DIR/component-companion.desktop"

if [ ! -f "$DESKTOP_SRC" ]; then
    echo "❌ Lỗi: Không tìm thấy file component-companion.desktop tại $SCRIPT_DIR"
    exit 1
fi

if [ ! -f "$APP_BINARY" ]; then
    echo "❌ Lỗi: Không tìm thấy file chạy component_companion tại $SCRIPT_DIR"
    exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$DESKTOP_SRC" "$DESKTOP_DEST"

# Nếu chạy bằng sudo thì phải đổi lại chủ sở hữu file cho user thường
if [ -n "$SUDO_USER" ]; then
    chown "$SUDO_USER:$SUDO_USER" "$TARGET_DIR" "$DESKTOP_DEST"
fi

# Exec được đặt trong ngoặc kép nên đường dẫn có dấu cách vẫn chạy được
sed -i "s|AppPath/component_companion|$APP_BINARY|g" "$DESKTOP_DEST"
sed -i "s|AppPath/component-companion.png|$APP_ICON|g" "$DESKTOP_DEST"

chmod +x "$DESKTOP_DEST"
chmod +x "$APP_BINARY"

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$TARGET_DIR" &> /dev/null
fi

echo "================================================="
echo "✅ Đã cài đặt Component Companion vào System Menu thành công!"
echo "📌 File launcher tại: $DESKTOP_DEST"
echo "⚠️  Ứng dụng chạy trực tiếp từ thư mục này, đừng xoá/di chuyển:"
echo "   $SCRIPT_DIR"
echo "================================================="
