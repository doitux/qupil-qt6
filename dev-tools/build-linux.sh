#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKSPACE="$(cd -- "$HERE/.." && pwd -P)"
ENV_ROOT="${QUPIL_BUILD_ENV:-$WORKSPACE/qupil-build-env}"
QT_VERSION="${QT_VERSION:-6.11.2}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

mode="${1:-debug}"
case "${mode,,}" in
    debug)   BUILD_TYPE=Debug; DIR_NAME=dev-linux-debug ;;
    release) BUILD_TYPE=Release; DIR_NAME=dev-linux-release ;;
    *) echo "Aufruf: $0 [debug|release]" >&2; exit 2 ;;
esac

QT_ROOT="$ENV_ROOT/Qt/$QT_VERSION/gcc_64"
BUILD_DIR="$ENV_ROOT/build/$DIR_NAME"
[[ -x "$QT_ROOT/bin/qt-cmake" ]] || { echo "qt-cmake fehlt: $QT_ROOT/bin/qt-cmake" >&2; exit 1; }
command -v ninja >/dev/null || { echo "ninja fehlt" >&2; exit 1; }

mkdir -p "$BUILD_DIR"
"$QT_ROOT/bin/qt-cmake" \
    -S "$HERE" -B "$BUILD_DIR" -GNinja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_TESTING=ON

cmake --build "$BUILD_DIR" --parallel "$JOBS"
ctest --test-dir "$BUILD_DIR" --output-on-failure
printf '\nFertig. Binary:\n  %s\n' "$BUILD_DIR/qupil"
