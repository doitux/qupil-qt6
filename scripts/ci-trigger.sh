#!/usr/bin/env bash
# QUPIL_CI_MANAGED
set -Eeuo pipefail
TARGET="${1:-all}"
SOURCE_REF="${2:-$(git branch --show-current)}"
case "$TARGET" in all|windows|macos|android|ios) ;; *) echo "Ziel: all|windows|macos|android|ios" >&2; exit 2;; esac
command -v gh >/dev/null 2>&1 || { echo "gh fehlt: sudo apt install gh && gh auth login"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Bitte einmal: gh auth login"; exit 1; }
REMOTE="${QUPIL_CI_REMOTE:-origin}"
git remote set-head "$REMOTE" -a >/dev/null 2>&1 || true
DEFAULT_BRANCH="$(git symbolic-ref -q --short "refs/remotes/$REMOTE/HEAD" 2>/dev/null | sed "s#^$REMOTE/##")"
[[ -n "$DEFAULT_BRANCH" ]] || DEFAULT_BRANCH="$(git remote show "$REMOTE" | sed -n 's/^[[:space:]]*HEAD branch: //p' | head -n1)"
[[ -n "$DEFAULT_BRANCH" ]] || { echo "Default-Branch unbekannt" >&2; exit 1; }
echo "Starte: target=$TARGET source_ref=$SOURCE_REF workflow_branch=$DEFAULT_BRANCH"
gh workflow run qupil-build-on-demand.yml --ref "$DEFAULT_BRANCH" -f "target=$TARGET" -f "source_ref=$SOURCE_REF"
sleep 2
gh run list --workflow qupil-build-on-demand.yml --limit 5
echo "Live verfolgen: gh run watch"
