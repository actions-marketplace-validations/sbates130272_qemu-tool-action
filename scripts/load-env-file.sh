#!/usr/bin/env bash
# Load a qemu-tool env-file (KEY=VALUE) into $GITHUB_ENV.
# Skips blank lines, comments, and variables that would corrupt runner state.
set -euo pipefail

ENV_FILE="$1"

if [ ! -f "$ENV_FILE" ]; then
  echo "::error::env-file not found: $ENV_FILE"
  exit 1
fi

echo "Loading $ENV_FILE into GITHUB_ENV"

while IFS= read -r line || [ -n "$line" ]; do
  # Skip blank lines and comment lines
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  KEY="${line%%=*}"
  # Protect runner/GitHub built-ins from being overwritten
  case "$KEY" in
    PATH | HOME | SHELL | USER | GITHUB_* | RUNNER_*)
      echo "  Skipping protected variable: $KEY"
      continue
      ;;
  esac

  echo "  Exporting: $KEY"
  echo "$line" >> "$GITHUB_ENV"
done < "$ENV_FILE"
