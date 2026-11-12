#!/bin/bash
#
# 只用 Command Line Tools 构建番茄环（不需要完整 Xcode）。
# 用法：./build.sh            构建到 build/TomatoRing.app
#      ./build.sh --install  构建并安装到 ~/Applications
#
set -euo pipefail
cd "$(dirname "$0")"

APP_PATH="build/TomatoRing.app"
BIN_NAME="TomatoRing"
MIN_MACOS="13.0"
SDK="$(xcrun --show-sdk-path)"

echo "==> 清理"
rm -rf build
mkdir -p build/bin

echo "==> 编译 (universal)"
for arch in arm64 x86_64; do
  echo "    - $arch"
  swiftc -O \
    -sdk "$SDK" \
    -target "$arch-apple-macos$MIN_MACOS" \
    -o "build/bin/$BIN_NAME-$arch" \
    Sources/*.swift
done

lipo -create "build/bin/$BIN_NAME-arm64" "build/bin/$BIN_NAME-x86_64" -output "build/bin/$BIN_NAME"

echo "==> 组装 app bundle"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "build/bin/$BIN_NAME" "$APP_PATH/Contents/MacOS/$BIN_NAME"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
fi
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

echo "==> ad-hoc 签名"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH" 2>&1 | tail -2

echo "==> 完成: $(pwd)/$APP_PATH"

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/TomatoRing.app"
  cp -R "$APP_PATH" "$HOME/Applications/TomatoRing.app"
  echo "==> 已安装到 ~/Applications/TomatoRing.app"
fi
