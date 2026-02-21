#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_DIR="/home/node/.openclaw"

###############################################################################
# Pull openclaw state from GitHub (if configured)
###############################################################################
if [[ -n "${GIT_WORKSPACE_REPO:-}" && -n "${GHCR_TOKEN:-}" ]]; then
  REMOTE_URL="https://${GHCR_TOKEN}@github.com/${GIT_WORKSPACE_REPO}.git"
  BRANCH="${GIT_WORKSPACE_BRANCH:-auto}"

  git config --global --add safe.directory "$OPENCLAW_DIR" 2>/dev/null || true

  if [[ -d "$OPENCLAW_DIR/.git" ]]; then
    echo "[entrypoint] Pulling openclaw state from GitHub ..."
    git -C "$OPENCLAW_DIR" pull origin "$BRANCH" --rebase --quiet 2>/dev/null || \
      echo "[entrypoint] WARNING: git pull failed — using existing state"
  else
    echo "[entrypoint] Cloning openclaw state from GitHub ..."
    git clone --branch "$BRANCH" --single-branch --quiet "$REMOTE_URL" "$OPENCLAW_DIR" 2>/dev/null || \
      git clone --quiet "$REMOTE_URL" "$OPENCLAW_DIR" 2>/dev/null || \
      echo "[entrypoint] WARNING: git clone failed — starting with empty state"
  fi
else
  echo "[entrypoint] GIT_WORKSPACE_REPO not set — skipping state pull."
fi

###############################################################################
# Run skill dependency installer (if present)
###############################################################################
INSTALL_SCRIPT="$OPENCLAW_DIR/skill_install.sh"
if [[ -f "$INSTALL_SCRIPT" ]]; then
  echo "[entrypoint] Running skill_install.sh ..."
  bash "$INSTALL_SCRIPT"
else
  echo "[entrypoint] No skill_install.sh found — skipping."
fi

###############################################################################
# Hand off to the real command (CMD from docker-compose)
###############################################################################
exec "$@"
