#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKSPACE="$(cd -- "$HERE/.." && pwd -P)"
ENV_ROOT="${QUPIL_BUILD_ENV:-$WORKSPACE/qupil-build-env}"
QT_VERSION="${QT_VERSION:-6.11.2}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-36.0.0}"
ANDROID_NDK_VERSION="${ANDROID_NDK_VERSION:-27.2.12479018}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
target="${1:-apk}"
case "$target" in apk|aab|all) ;; *) echo "Aufruf: $0 [apk|aab|all]" >&2; exit 2 ;; esac

QT_HOST="$ENV_ROOT/Qt/$QT_VERSION/gcc_64"
QT_ANDROID="$ENV_ROOT/Qt/$QT_VERSION/android_arm64_v8a"
SDK="$ENV_ROOT/android-sdk"
NDK="$SDK/ndk/$ANDROID_NDK_VERSION"
BUILD_DIR="$ENV_ROOT/build/dev-android-arm64"

[[ -x "$QT_ANDROID/bin/qt-cmake" ]] || { echo "Android qt-cmake fehlt" >&2; exit 1; }
[[ -d "$NDK" ]] || { echo "Android NDK fehlt: $NDK" >&2; exit 1; }
command -v javac >/dev/null || { echo "javac fehlt" >&2; exit 1; }
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export ANDROID_SDK_ROOT="$SDK"
export ANDROID_NDK_ROOT="$NDK"

KEYSTORE="$ENV_ROOT/keys/qupil-development.keystore"
if [[ -f "$KEYSTORE" ]]; then
    export QT_ANDROID_KEYSTORE_PATH="$KEYSTORE"
    export QT_ANDROID_KEYSTORE_ALIAS="qupil-development"
    export QT_ANDROID_KEYSTORE_STORE_PASS="qupil-development-only"
    export QT_ANDROID_KEYSTORE_KEY_PASS="qupil-development-only"
fi

mkdir -p "$BUILD_DIR"
"$QT_ANDROID/bin/qt-cmake" \
    -S "$HERE" -B "$BUILD_DIR" -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF \
    -DQT_HOST_PATH="$QT_HOST" \
    -DANDROID_SDK_ROOT="$SDK" \
    -DANDROID_NDK_ROOT="$NDK" \
    -DQT_ANDROID_SIGN_APK=ON \
    -DQT_ANDROID_SIGN_AAB=ON

case "$target" in
    apk) cmake --build "$BUILD_DIR" --target apk --parallel "$JOBS" ;;
    aab) cmake --build "$BUILD_DIR" --target aab --parallel "$JOBS" ;;
    all)
        cmake --build "$BUILD_DIR" --target apk --parallel "$JOBS"
        cmake --build "$BUILD_DIR" --target aab --parallel "$JOBS"
        ;;
esac

printf '\nAndroid-Ausgaben:\n'
find "$BUILD_DIR" -type f \( -name '*.apk' -o -name '*.aab' \) -path '*/outputs/*' -print | sort
