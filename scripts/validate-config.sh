#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/config/openclaw.json"

echo "Validating $CONFIG ..."

# 1. Check valid JSON
if ! jq empty "$CONFIG" 2>/dev/null; then
  echo "ERROR: $CONFIG is not valid JSON"
  exit 1
fi

# 2. Check for raw API key patterns that should never appear in config
PATTERNS='sk-ant-|sk-proj-|bot[0-9]|bsc_|xai-|gsk_'
if grep -qE "$PATTERNS" "$CONFIG"; then
  echo "ERROR: Raw API key pattern detected in $CONFIG"
  echo "Use \${ENV_VAR} references instead of plaintext keys."
  grep -nE "$PATTERNS" "$CONFIG"
  exit 1
fi

echo "✓ Config validation passed"
