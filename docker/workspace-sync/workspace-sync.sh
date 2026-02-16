#!/bin/bash
# =============================================================================
# OpenClaw Workspace Git Sync
# =============================================================================
# Commits and pushes the workspace to a private GitHub repo.
# Reads config from environment variables (passed by Docker).
# =============================================================================

set -euo pipefail

WORKSPACE_DIR="/workspace"

GIT_WORKSPACE_REPO="${GIT_WORKSPACE_REPO:-}"
GIT_WORKSPACE_BRANCH="${GIT_WORKSPACE_BRANCH:-auto}"
GIT_WORKSPACE_TOKEN="${GIT_WORKSPACE_TOKEN:-}"

# -----------------------------------------------------------------------------
# Validate
# -----------------------------------------------------------------------------

if [[ -z "$GIT_WORKSPACE_REPO" ]]; then
    echo "[SKIP] GIT_WORKSPACE_REPO not set"
    exit 0
fi

if [[ -z "$GIT_WORKSPACE_TOKEN" ]]; then
    echo "[ERROR] GIT_WORKSPACE_TOKEN not set"
    exit 1
fi

if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "[SKIP] Workspace directory $WORKSPACE_DIR does not exist"
    exit 0
fi

# -----------------------------------------------------------------------------
# Git setup
# -----------------------------------------------------------------------------

REMOTE_URL="https://${GIT_WORKSPACE_TOKEN}@github.com/${GIT_WORKSPACE_REPO}.git"

echo "=== OpenClaw Workspace Sync ==="
echo "Repo: $GIT_WORKSPACE_REPO"
echo "Branch: $GIT_WORKSPACE_BRANCH"
echo ""

cd "$WORKSPACE_DIR"

if [[ ! -d ".git" ]]; then
    echo "[...] Initializing git repository..."
    git init -b "$GIT_WORKSPACE_BRANCH" --quiet
fi

if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi

git config user.name "OpenClaw Bot"
git config user.email "openclaw@noreply.local"

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "$GIT_WORKSPACE_BRANCH" ]]; then
    git branch -m "$CURRENT_BRANCH" "$GIT_WORKSPACE_BRANCH" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Commit and push
# -----------------------------------------------------------------------------

echo "[...] Checking for changes..."

git add -A

if git diff --cached --quiet; then
    echo "[SKIP] No changes to sync"
    echo "=== Sync Complete ==="
    exit 0
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
FILE_COUNT=$(git diff --cached --numstat | wc -l | tr -d ' ')

echo "[...] Committing $FILE_COUNT changed file(s)..."
git commit -m "workspace sync $TIMESTAMP" --quiet

echo "[...] Pushing to $GIT_WORKSPACE_REPO ($GIT_WORKSPACE_BRANCH)..."

if git ls-remote --exit-code origin "$GIT_WORKSPACE_BRANCH" &>/dev/null; then
    git pull origin "$GIT_WORKSPACE_BRANCH" --rebase --allow-unrelated-histories --quiet 2>/dev/null || true
fi

git push -u origin "$GIT_WORKSPACE_BRANCH" --quiet 2>&1
echo "[OK] Workspace synced successfully"
echo "=== Sync Complete ==="
