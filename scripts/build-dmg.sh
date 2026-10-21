#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version=${1:-1.0.0}
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo 'error: Expected a semantic version such as 1.0.0.' >&2; exit 1
fi
output_dir=${OUTPUT_DIR:-"$PWD/build/dist"}
derived_data=${DERIVED_DATA:-"$PWD/build/ReleaseData"}
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd)
# CREDENTIALS: configure all six secrets, or none. Never silently downgrade broken signing.
names=(DEVELOPER_ID_P12_BASE64 DEVELOPER_ID_P12_PASSWORD DEVELOPER_ID_IDENTITY APPLE_ID APPLE_APP_PASSWORD APPLE_TEAM_ID)
configured=0
for name in "${names[@]}"; do if [[ -n "${!name:-}" ]]; then configured=$((configured + 1)); fi; done
if (( configured != 0 && configured != ${#names[@]} )); then
  echo 'error: Signing requires every documented signing/notarization secret, or none.' >&2; exit 1
fi
signed=false
if (( configured == ${#names[@]} )); then signed=true; fi
suffix='-unnotarized'
if $signed; then suffix=''; fi
filename="LiteShelf-${version}-macOS-arm64${suffix}.dmg"
dmg="$output_dir/$filename"
if [[ -e "$dmg" || -e "$dmg.sha256" ]]; then
  echo "error: Refusing to overwrite existing package: $dmg" >&2; exit 1
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/liteshelf-package.XXXXXX")
keychain=''
cleanup() {
  if [[ -n "$keychain" ]]; then security delete-keychain "$keychain" >/dev/null 2>&1 || true; fi
  rm -rf "$work"
}
trap cleanup EXIT
./scripts/check-toolchain.sh
xcodebuild -project LiteShelf.xcodeproj -scheme LiteShelf -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="${BUILD_NUMBER:-1}" build
app="$derived_data/Build/Products/Release/LiteShelf.app"
[[ -d "$app" && -x "$app/Contents/MacOS/LiteShelf" ]] || { echo 'error: Missing app executable.' >&2; exit 1; }
actual=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$actual" == "$version" ]] || { echo 'error: App and release versions differ.' >&2; exit 1; }
xcrun lipo -verify_arch arm64 "$app/Contents/MacOS/LiteShelf"
file "$app/Contents/MacOS/LiteShelf"
mkdir "$work/stage"
ditto "$app" "$work/stage/LiteShelf.app"
staged="$work/stage/LiteShelf.app"
if $signed; then
  keychain="$work/signing.keychain-db"
  keychain_password=$(openssl rand -hex 24)
  printf '%s' "$DEVELOPER_ID_P12_BASE64" | /usr/bin/base64 -D > "$work/certificate.p12"
  security create-keychain -p "$keychain_password" "$keychain"
  security set-keychain-settings -lut 21600 "$keychain"
  security unlock-keychain -p "$keychain_password" "$keychain"
  security import "$work/certificate.p12" -k "$keychain" -P "$DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
  codesign --force --options runtime --timestamp --keychain "$keychain" --sign "$DEVELOPER_ID_IDENTITY" "$staged"
else
  # ARM64 binaries require a signature; ad-hoc signing is explicitly not Developer ID or notarization.
  codesign --force --sign - "$staged"
  printf '%s\n' 'UNNOTARIZED TEST BUILD — no Developer ID or Apple notarization.' > "$work/stage/UNNOTARIZED.txt"
fi
codesign --verify --deep --strict --verbose=2 "$staged"
ln -s /Applications "$work/stage/Applications"
# Notarize a ZIP first so the app itself can be stapled before it is sealed inside the DMG.
if $signed; then
  ditto -c -k --keepParent "$staged" "$work/LiteShelf.zip"
  xcrun notarytool submit "$work/LiteShelf.zip" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" --wait --timeout 30m
  xcrun stapler staple "$staged"
  xcrun stapler validate "$staged"
fi
# macOS 27 deprecated hdiutil's folder-image creation entry point. Use its native
# replacement there; retain the explicit HFS+ path for older build hosts.
os_version=$(sw_vers -productVersion)
os_major=${os_version%%.*}
if (( os_major >= 27 )); then
  diskutil image create from --volumeName LiteShelf --format UDZO "$work/stage" "$work/package.dmg"
else
  hdiutil create -volname LiteShelf -fs HFS+ -srcfolder "$work/stage" -ov -format UDZO "$work/package.dmg"
fi
if $signed; then
  codesign --timestamp --keychain "$keychain" --sign "$DEVELOPER_ID_IDENTITY" "$work/package.dmg"
  xcrun notarytool submit "$work/package.dmg" --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" --wait --timeout 30m
  xcrun stapler staple "$work/package.dmg"
  xcrun stapler validate "$work/package.dmg"
fi
hdiutil verify "$work/package.dmg"
file "$work/package.dmg"
mv "$work/package.dmg" "$dmg"
(cd "$output_dir" && shasum -a 256 "$filename" > "$filename.sha256")
# Expose only validated outputs to the caller/Actions.
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  printf 'dmg=%s\nchecksum=%s\nnotarized=%s\n' "$dmg" "$dmg.sha256" "$signed" >> "$GITHUB_OUTPUT"
fi
printf '\nPackage: %s\nNotarized: %s\n' "$dmg" "$signed"
