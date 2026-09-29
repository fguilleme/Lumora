#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PROJECT="$ROOT/Lumora.xcodeproj"
OUTPUT="$ROOT/AppStore/Screenshots"
DERIVED="$ROOT/.build/AppStoreScreenshots"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-27-0"
IPHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro-Max"
IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"
BUNDLE_ID="com.guilleme.Lumora"
RAW_SOURCE="${LUMORA_EXIF_RAW:-/Volumes/XTRA/Pictures/IMG_9908.CR2}"
PANELS=(Light Color Effects Beauty EXIF)
NAMES=(01-development 02-color 03-creative 04-beauty 05-exif)
IMAGES=(PortraitEyes.jpg PortraitDarkSkin.jpg PortraitBeard.jpg PortraitPores.jpg "")
TARGET="${1:-all}"

mkdir -p "$OUTPUT" "$DERIVED"

device_id() {
  local name="$1" type="$2" id
  id=$(xcrun simctl list devices available | sed -n "s/^[[:space:]]*$name (\([0-9A-F-]*\)).*/\1/p" | head -1)
  [[ -n "$id" ]] || id=$(xcrun simctl create "$name" "$type" "$RUNTIME")
  print -r -- "$id"
}

prepare_device() {
  local id="$1" family="$2"
  xcrun simctl boot "$id" 2>/dev/null || true
  xcrun simctl bootstatus "$id" -b
  xcrun simctl status_bar "$id" override --time 9:41 --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 >/dev/null
  xcodebuild -quiet -project "$PROJECT" -scheme Lumora \
    -destination "platform=iOS Simulator,id=$id" \
    -derivedDataPath "$DERIVED/DerivedData-$family" build
  xcrun simctl install "$id" "/Volumes/XTRA/XCode-data/products/Debug-iphonesimulator/Lumora.app"
  local container
  container=$(xcrun simctl get_app_container "$id" "$BUNDLE_ID" data)
  cp "$RAW_SOURCE" "$container/Documents/AppStoreEXIF.CR2"
  cp "$ROOT/Validation/BeautyValidation/Sources/10_detailed_eyes.jpg" "$container/Documents/PortraitEyes.jpg"
  cp "$ROOT/Validation/BeautyValidation/Sources/02_dark_skin_texture.jpg" "$container/Documents/PortraitDarkSkin.jpg"
  cp "$ROOT/Validation/BeautyValidation/Sources/06_beard_moustache.jpg" "$container/Documents/PortraitBeard.jpg"
  cp "$ROOT/Validation/BeautyValidation/Sources/01_light_skin_pores.jpg" "$container/Documents/PortraitPores.jpg"
}

capture_locale() {
  local id="$1" family="$2" language="$3" region="$4" expected="$5"
  local directory="$OUTPUT/$language/$family"
  rm -rf "$directory"
  mkdir -p "$directory"

  for index in {1..5}; do
    local panel="${PANELS[$index]}" name="${NAMES[$index]}" image="${IMAGES[$index]}"
    local temporary="/tmp/lumora-${family}-${language}-${name}.png"
    if [[ "$panel" == "EXIF" ]]; then
      xcrun simctl launch --terminate-running-process "$id" "$BUNDLE_ID" \
        --app-store-raw --app-store-panel "$panel" \
        -AppleLanguages "($language)" -AppleLocale "${language}_${region}" >/dev/null
      sleep 12
    else
      xcrun simctl launch --terminate-running-process "$id" "$BUNDLE_ID" \
        --app-store-image "$image" --app-store-panel "$panel" \
        -AppleLanguages "($language)" -AppleLocale "${language}_${region}" >/dev/null
      sleep 7
    fi
    xcrun simctl io "$id" screenshot "$temporary" >/dev/null
    cp "$temporary" "$directory/$name.png"
    rm -f "$temporary"
  done

  python3 "$ROOT/AppStore/prepare_screenshots.py" "$directory" "$expected"
}

if [[ "$TARGET" == "all" || "$TARGET" == "iphone" ]]; then
  IPHONE_ID=$(device_id "Lumora App Store iPhone 6.5" "$IPHONE_TYPE")
  prepare_device "$IPHONE_ID" "iPhone-6.5"
  capture_locale "$IPHONE_ID" "iPhone-6.5" fr FR 1284x2778
  capture_locale "$IPHONE_ID" "iPhone-6.5" en US 1284x2778
fi

if [[ "$TARGET" == "all" || "$TARGET" == "ipad" ]]; then
  IPAD_ID=$(device_id "Lumora App Store iPad" "$IPAD_TYPE")
  prepare_device "$IPAD_ID" "iPad-13"
  capture_locale "$IPAD_ID" "iPad-13" fr FR 2064x2752
  capture_locale "$IPAD_ID" "iPad-13" en US 2064x2752
fi

echo "Screenshots ready in $OUTPUT"
