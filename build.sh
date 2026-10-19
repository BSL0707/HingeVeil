#!/bin/sh
set -eu
VEIL_PROJECT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -d /Applications/Xcode.app/Contents/Developer ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
else
    DEVELOPER_DIR=$(xcode-select -p)
fi
CLANG_MODULE_CACHE_PATH="$VEIL_PROJECT/.build/module-cache"
export DEVELOPER_DIR CLANG_MODULE_CACHE_PATH
cd "$VEIL_PROJECT"
VEIL_SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
"$VEIL_SWIFT" test --disable-sandbox --cache-path .build/cache --scratch-path .build --manifest-cache local
"$VEIL_SWIFT" build -c release -debug-info-format none --disable-sandbox --cache-path .build/cache --scratch-path .build --manifest-cache local -Xswiftc -DVEIL_PACKAGED -Xswiftc -file-prefix-map -Xswiftc "$VEIL_PROJECT=HingeVeil"
VEIL_BIN=$("$VEIL_SWIFT" build -c release --show-bin-path --disable-sandbox --scratch-path .build --manifest-cache local)
VEIL_APP=${1:-"$VEIL_PROJECT/Build/HingeVeil.app"}
mkdir -p "$VEIL_APP/Contents/MacOS" "$VEIL_APP/Contents/Resources"
cp "$VEIL_BIN/HingeVeil" "$VEIL_APP/Contents/MacOS/HingeVeil"
cp Info.plist "$VEIL_APP/Contents/Info.plist"
cp Sources/HingeVeil/Resources/PreviewTiger.png "$VEIL_APP/Contents/Resources/PreviewTiger.png"
for VEIL_LANGUAGE in en ko; do
    ditto "Sources/HingeVeilCore/Resources/$VEIL_LANGUAGE.lproj" "$VEIL_APP/Contents/Resources/$VEIL_LANGUAGE.lproj"
    cp "Sources/HingeVeilCore/Resources/Manual.$VEIL_LANGUAGE.txt" "$VEIL_APP/Contents/Resources/Manual.$VEIL_LANGUAGE.txt"
done
mkdir -p .build/metal-cache
xcrun -sdk macosx metal -fmodules-cache-path="$VEIL_PROJECT/.build/metal-cache" -c Sources/HingeVeil/Resources/Veil.metal -o .build/Veil.air
xcrun -sdk macosx metallib .build/Veil.air -o "$VEIL_APP/Contents/Resources/Veil.metallib"
"$VEIL_BIN/HingeVeil" --make-icon "$VEIL_PROJECT/.build/HingeVeil.iconset"
iconutil -c icns "$VEIL_PROJECT/.build/HingeVeil.iconset" -o "$VEIL_APP/Contents/Resources/HingeVeil.icns"
for VEIL_DOC in README.md README.ko.md LICENSE LICENSE-STATUS.md PROVENANCE.md; do
    cp "$VEIL_DOC" "$VEIL_APP/Contents/Resources/$VEIL_DOC"
done
codesign --force --sign - --identifier com.bsl0707.hingeveil.preview "$VEIL_APP"
codesign --verify --deep --strict "$VEIL_APP"
plutil -lint "$VEIL_APP/Contents/Info.plist"
"$VEIL_APP/Contents/MacOS/HingeVeil" --check-localizations
printf '%s\n' "$VEIL_APP"
