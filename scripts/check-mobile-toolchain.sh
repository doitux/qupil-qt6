#!/usr/bin/env bash
set -euo pipefail

mode="${1:-all}"
missing=0
check_cmd() {
  local name="$1"
  if ! command -v "$name" >/dev/null 2>&1; then
    printf 'MISSING: %s\n' "$name" >&2
    missing=1
  else
    printf 'OK: %s -> %s\n' "$name" "$(command -v "$name")"
  fi
}

if [[ "$mode" == "all" || "$mode" == "android" ]]; then
  check_cmd cmake
  check_cmd java
  check_cmd javac
  if [[ -z "${ANDROID_SDK_ROOT:-}" ]]; then
    echo 'MISSING: ANDROID_SDK_ROOT' >&2
    missing=1
  else
    echo "OK: ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
  fi
  if [[ -z "${ANDROID_NDK_ROOT:-}" ]]; then
    echo 'MISSING: ANDROID_NDK_ROOT' >&2
    missing=1
  else
    echo "OK: ANDROID_NDK_ROOT=$ANDROID_NDK_ROOT"
  fi
  if [[ -z "${QT_ANDROID_ROOT:-}" ]]; then
    echo 'MISSING: QT_ANDROID_ROOT (for example /opt/Qt/6.11.2/android_arm64_v8a)' >&2
    missing=1
  elif [[ ! -x "$QT_ANDROID_ROOT/bin/qt-cmake" ]]; then
    echo "MISSING: $QT_ANDROID_ROOT/bin/qt-cmake" >&2
    missing=1
  else
    echo "OK: QT_ANDROID_ROOT=$QT_ANDROID_ROOT"
  fi
fi

if [[ "$mode" == "all" || "$mode" == "ios" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo 'MISSING: macOS host (required for iOS/Xcode builds)' >&2
    missing=1
  else
    check_cmd xcodebuild
  fi
  if [[ -z "${QT_IOS_ROOT:-}" ]]; then
    echo 'MISSING: QT_IOS_ROOT (for example /opt/Qt/6.11.2/ios)' >&2
    missing=1
  elif [[ ! -x "$QT_IOS_ROOT/bin/qt-cmake" ]]; then
    echo "MISSING: $QT_IOS_ROOT/bin/qt-cmake" >&2
    missing=1
  else
    echo "OK: QT_IOS_ROOT=$QT_IOS_ROOT"
  fi
fi

exit "$missing"
