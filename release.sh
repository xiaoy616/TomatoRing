#!/bin/bash
#
# 打包发布物：编译通用二进制并压成 zip，同时输出校验值。
# 用法：./release.sh
#
set -euo pipefail
cd "$(dirname "$0")"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"

./build.sh

mkdir -p dist
ZIP="dist/TomatoRing-${VERSION}.zip"
rm -f "$ZIP" "$ZIP.sha256"

ditto -c -k --sequesterRsrc --keepParent build/TomatoRing.app "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"

echo "==> dist/TomatoRing-${VERSION}.zip  ($(du -h "$ZIP" | cut -f1))"
