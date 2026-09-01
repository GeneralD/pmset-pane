#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
build_dir="$root_dir/dist"
bundle_dir="$build_dir/PMSetPane.prefPane/Contents"
version="${VERSION:-0.1.1}"
icon_dir="$build_dir/PMSetPane.iconset"

rm -rf "$build_dir"
swift build --package-path "$root_dir" --configuration release --arch arm64
swift build --package-path "$root_dir" --configuration release --arch x86_64

mkdir -p "$bundle_dir/MacOS"
mkdir -p "$bundle_dir/Resources" "$icon_dir"
cp "$root_dir/Resources/Info.plist" "$bundle_dir/Info.plist"
lipo -create \
    "$root_dir/.build/arm64-apple-macosx/release/libPMSetPane.dylib" \
    "$root_dir/.build/x86_64-apple-macosx/release/libPMSetPane.dylib" \
    -output "$bundle_dir/MacOS/PMSetPane"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$bundle_dir/Info.plist"

for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$root_dir/Assets/pmset-pane.svg" --out "$icon_dir/icon_${size}x${size}.png" >/dev/null
    doubled_size=$((size * 2))
    sips -s format png -z "$doubled_size" "$doubled_size" "$root_dir/Assets/pmset-pane.svg" --out "$icon_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$icon_dir" -o "$bundle_dir/Resources/PMSetPane.icns"

codesign --force --sign - "$bundle_dir/MacOS/PMSetPane"

ditto -c -k --sequesterRsrc --keepParent "$build_dir/PMSetPane.prefPane" "$build_dir/PMSetPane.zip"
printf 'Created %s\n' "$build_dir/PMSetPane.zip"
