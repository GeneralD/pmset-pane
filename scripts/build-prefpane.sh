#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
build_dir="$root_dir/dist"
bundle_dir="$build_dir/PMSetPane.prefPane/Contents"
version="${VERSION:-0.1.0}"

rm -rf "$build_dir"
swift build --package-path "$root_dir" --configuration release --arch arm64
swift build --package-path "$root_dir" --configuration release --arch x86_64

mkdir -p "$bundle_dir/MacOS"
cp "$root_dir/Resources/Info.plist" "$bundle_dir/Info.plist"
lipo -create \
    "$root_dir/.build/arm64-apple-macosx/release/libPMSetPane.dylib" \
    "$root_dir/.build/x86_64-apple-macosx/release/libPMSetPane.dylib" \
    -output "$bundle_dir/MacOS/PMSetPane"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$bundle_dir/Info.plist"
codesign --force --sign - "$bundle_dir/MacOS/PMSetPane"

ditto -c -k --sequesterRsrc --keepParent "$build_dir/PMSetPane.prefPane" "$build_dir/PMSetPane.zip"
printf 'Created %s\n' "$build_dir/PMSetPane.zip"
