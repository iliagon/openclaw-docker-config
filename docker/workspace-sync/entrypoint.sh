#!/bin/bash
set -euo pipefail

# If repo is not configured, idle forever (don't restart-loop)
if [[ -z "${GIT_WORKSPACE_REPO:-}" ]]; then
    echo "[workspace-sync] GIT_WORKSPACE_REPO not set — idling"
    exec sleep infinity
fi

# Volume is owned by host user (UID 1000), container runs as root
git config --global --add safe.directory /openclaw

SCHEDULE="${GIT_WORKSPACE_SYNC_SCHEDULE:-0 4 * * *}"

echo "[workspace-sync] Repo: $GIT_WORKSPACE_REPO"
echo "[workspace-sync] Branch: ${GIT_WORKSPACE_BRANCH:-auto}"
echo "[workspace-sync] Schedule: $SCHEDULE"
echo ""

# Run initial sync to verify credentials
echo "[workspace-sync] Running initial sync..."
workspace-sync.sh
echo ""

# Set up cron — pass env vars through to the cron job with proper shell quoting
# (plain `env >` produces unquoted KEY=VALUE lines; values with spaces like cron
#  schedules get word-split by the shell when injected inline, causing env to
#  treat the first space-separated token after KEY= as the command to run)
while IFS='=' read -r key value; do
    printf '%s=%q ' "$key" "$value"
done < <(env) > /tmp/workspace-sync.env
echo "$SCHEDULE /usr/bin/env - \$(cat /tmp/workspace-sync.env) /usr/local/bin/workspace-sync.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" > /etc/crontabs/root

echo "[workspace-sync] Cron configured, starting scheduler..."
exec crond -f -l 2
