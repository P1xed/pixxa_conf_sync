#!/usr/bin/env bash
# sync.sh — Back up configs from ~/.config into this repo, overwriting existing copies.
#
#   ./sync.sh          back up and overwrite
#   ./sync.sh -n       preview only, write nothing

set -euo pipefail

SRC="$HOME/.config"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.config"

# Entries to back up, relative to ~/.config. Directories are copied recursively.
ITEMS=(
  nvim
  hypr
  kitty
  fuzzel
  mise
  jj/config.toml
)

# Paths to skip (POSIX ERE, matched against the path relative to an entry, e.g. nvim/xxx)
EXCLUDES='(^|/)\.git(/|$)|(^|/)\.jj(/|$)|(^|/)repos(/|$)|(^|/)logs(/|$)|\.log$|~$|\.swp$|metadata\.binpb$'

# Refuse to copy anything that looks like a credential
SECRETS='oauth_token|ghp_[A-Za-z0-9]|github_pat_|BEGIN.*PRIVATE KEY'

DRY=0
if [[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]]; then DRY=1; shift; fi

run() { if [[ $DRY -eq 1 ]]; then echo "[dry-run] $*"; else "$@"; fi; }

# Returns 0 when the given relative path should be skipped.
excluded() { [[ "$1" =~ $EXCLUDES ]]; }

copied=0 skipped=0

for item in "${ITEMS[@]}"; do
  from="$SRC/$item"

  if [[ ! -e "$from" ]]; then
    echo "skip (missing)    $item"
    skipped=$((skipped + 1))
    continue
  fi

  files=()
  if [[ -f "$from" ]]; then
    files=("$item")
  else
    while IFS= read -r -d '' p; do
      rel="$item/$p"
      excluded "$rel" && continue
      files+=("$rel")
    done < <(find "$from" -type f -printf '%P\0')
  fi

  [[ ${#files[@]} -eq 0 ]] && continue

  for rel in "${files[@]}"; do
    s="$SRC/$rel"
    d="$DST/$rel"

    if grep -qIE "$SECRETS" "$s" 2>/dev/null; then
      echo "refuse (secret)   $rel"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -e "$d" ]] && cmp -s "$s" "$d"; then
      continue   # identical, nothing to do
    fi

    if [[ -e "$d" ]]; then
      echo "overwrite         $rel"
    else
      echo "new               $rel"
    fi
    run mkdir -p "$(dirname "$d")"
    run cp -p "$s" "$d"
    copied=$((copied + 1))
  done
done

echo "---"
note=""; [[ $DRY -eq 1 ]] && note=" (preview, nothing written)"
echo "backed up: $copied copied/overwritten, $skipped skipped$note"
