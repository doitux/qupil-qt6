#!/usr/bin/env bash
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORKSPACE="$(cd -- "$HERE/.." && pwd -P)"
ENV_ROOT="${QUPIL_BUILD_ENV:-$WORKSPACE/qupil-build-env}"
mode="${1:-debug}"
case "${mode,,}" in
    debug)   BUILD_DIR="$ENV_ROOT/build/dev-linux-debug" ;;
    release) BUILD_DIR="$ENV_ROOT/build/dev-linux-release" ;;
    *) echo "Aufruf: $0 [debug|release]" >&2; exit 2 ;;
esac

BIN="$BUILD_DIR/qupil"
[[ -x "$BIN" ]] || { echo "Binary fehlt. Erst dev-tools/build-linux.sh $mode ausführen." >&2; exit 1; }

# Isolated developer data: never touch the normal Qupil database by accident.
DEV_ROOT="$ENV_ROOT/dev-runtime"
mkdir -p "$DEV_ROOT/data" "$DEV_ROOT/config" "$DEV_ROOT/cache"
export QUPIL_DATA_DIR="$DEV_ROOT/data"
export XDG_CONFIG_HOME="$DEV_ROOT/config"
export XDG_CACHE_HOME="$DEV_ROOT/cache"

printf 'Qupil Developer-Daten liegen unter:\n  %s\n\n' "$DEV_ROOT"
exec "$BIN"
