#!/bin/zsh
set -eu
cd "${0:A:h:h}"
swift build -c release
binary_dir=$(swift build -c release --show-bin-path)
bundle_workspace=$(mktemp -d .build/parcel-pack-bundle.XXXXXX)
app_bundle="$bundle_workspace/Parcel Pack.app"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources" dist
cp "$binary_dir/ParcelPack" "$app_bundle/Contents/MacOS/ParcelPack"
cat > "$app_bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ParcelPack</string>
<key>CFBundleIdentifier</key><string>com.giofiore.parcelpack.mac</string>
<key>CFBundleName</key><string>Parcel Pack</string>
<key>CFBundleDisplayName</key><string>Parcel Pack</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_bundle"
if [[ -d "dist/Parcel Pack.app" ]]; then
  mv "dist/Parcel Pack.app" "$bundle_workspace/previous.app"
fi
mv "$app_bundle" "dist/Parcel Pack.app"
print "Built: $PWD/dist/Parcel Pack.app"
