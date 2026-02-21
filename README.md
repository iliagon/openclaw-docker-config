# OpenClaw Docker Config

Docker configuration and application setup for OpenClaw. Companion repository to [openclaw-terraform-hetzner](https://github.com/andreesg/openclaw-terraform-hetzner).

**Note:** This is a minimal, generic configuration. Skills live in your workspace repo and are managed through the agent at runtime — see [Working with Skills](#working-with-skills).

```
┌──────────────┐                        ┌──────────────────────┐
│   Laptop     │──── git push ─────────▶│   GitHub             │
│   (develop)  │                        │   (openclaw-config)  │
│              │                        └──────────────────────┘
│              │  build-and-push.sh
│              │───────────────────────▶ ┌──────────────────────┐
│              │                        │   GHCR               │
│              │                        │   :latest  :abc1234  │
│              │                        └──────────────────────┘
│              │
│              │  make push-env          ┌──────────────────────┐
│              │  make deploy            │   Hetzner VPS        │
│              │──── (infra repo) ──────▶│   ┌────────────────┐ │
│              │                        │   │ Docker         │ │
└──────────────┘                        │   │ openclaw-gw    │ │
                                        │   └────────────────┘ │
                                        │   :18789 (loopback)  │
                                        └──────────────────────┘
```

## Prerequisites

- Docker and Docker Compose on the VPS
- SSH access to the VPS (`ssh openclaw@VPS_IP`)
- The infra repo (`openclaw-terraform-hetzner`) set up with `config/inputs.sh` pointing `CONFIG_DIR` to this repo
- API keys (see `docker/.env.example` for the full list; secrets live in the infra repo's `secrets/openclaw.env`)

## How This Repo Connects to the VPS

This repo is **not cloned on the VPS**. Instead, the infra repo's scripts copy
specific files from your local checkout to the VPS:

| What | Pushed by | Lands at (VPS) |
|------|-----------|----------------|
| `docker/docker-compose.yml` | `make bootstrap` (once) | `~/openclaw/docker-compose.yml` |
| Docker image | `make deploy` (pulls from GHCR) | Docker image cache |
| Secrets | `make push-env` | `~/openclaw/.env` |

> **Config and state** (`openclaw.json`, skills, agents, etc.) live in the **workspace GitHub repo** and are cloned into the `openclaw_data` Docker volume on every container start. Edit config in the workspace repo and restart the container to apply.

## First-Time Setup

> Provisioning and bootstrap are handled by the infra repo. See its README.

1. **In the infra repo**, set `CONFIG_DIR` in `config/inputs.sh` to point to this repo's directory
2. **Log in to GHCR** (one-time, on your laptop):
   ```bash
   echo "$GHCR_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```
3. **Build and push the Docker image**:
   ```bash
   bash scripts/build-and-push.sh
   ```
4. Run `make bootstrap` from the infra repo — copies `docker-compose.yml` and secrets to VPS
5. Run `make deploy` from the infra repo — pulls the Docker image from GHCR and starts the container
6. **Complete Telegram pairing:** open Telegram, find your bot, send `/start`

## Change Workflows

### Changing config or state (openclaw.json, skills, memory)

Config and all runtime state live in the **workspace GitHub repo** — no SCP, no image rebuild needed.

```
edit in workspace repo → commit → push → restart container
```

On restart, `entrypoint.sh` clones/pulls the workspace repo into the `openclaw_data` volume.

### Changing the Docker image (Dockerfile, OpenClaw version)

Image changes require a rebuild and push to GHCR.

```
edit → commit → push → build-and-push.sh → make deploy (infra repo)
```

1. Edit `docker/Dockerfile` (e.g. bump `OPENCLAW_VERSION`, add a binary)
2. Commit and push to GitHub
3. Build and push image: `bash scripts/build-and-push.sh`
4. From the **infra repo**: `make deploy` (pulls new image from GHCR and restarts)

## Working with Skills

Skills live in your **workspace repo** under `skills/` and are loaded on every session. The workspace is cloned from GitHub on every container start, so skills survive restarts automatically.

### Adding a skill via the agent

The workspace includes a built-in `install-skill` skill that guides the agent through the full workflow. Just tell the bot:

> "add skill `<skill-name>`"

The agent will:
1. Read the skill's `SKILL.md` and identify required binaries
2. Install dependencies in the running container
3. Record the install commands in `skill_install.sh` (run on every container start for reproducibility)
4. Commit and push to your workspace repo via workspace-sync

Browse available skills at [clawhub.ai](https://clawhub.ai/).

### Writing a custom skill

Create a skill folder in your workspace repo under `skills/`:

```
skills/my-skill/
└── SKILL.md
```

Minimal `SKILL.md`:

```markdown
---
name: my-skill
description: What this skill does and when to use it.
---

# My Skill

Instructions for the agent...
```

See the [OpenClaw Skills docs](https://docs.openclaw.ai/tools/skills) for the full format (metadata gates, slash commands, binary requirements).

### Skill binary dependencies

Binary deps are tracked in `<workspace>/skill_install.sh`, which runs automatically on every container start. When the agent adds a skill it appends an idempotent install section to this file. The initial template lives in `workspace-templates/skill_install.sh`.

## Workspace Git Sync

The workspace (`~/.openclaw/workspace`) is stored in a Docker-managed volume and **cloned from your workspace GitHub repo on every container start**. Without this configured, any skills or customizations added at runtime are lost when the container restarts.

The `workspace-sync` sidecar pushes changes back to GitHub on a cron schedule.

### Setup

1. **Create a private GitHub repo** (e.g. `your-username/openclaw-workspace`)
2. Ensure `GHCR_TOKEN` (already in `.env`) has `repo` scope — it's reused for workspace git auth
3. **Add to your `.env`** (or infra repo's `secrets/openclaw.env`):
   ```
   GIT_WORKSPACE_REPO=your-username/openclaw-workspace
   GIT_WORKSPACE_BRANCH=auto
   GIT_WORKSPACE_SYNC_SCHEDULE=0 4 * * *
   ```
4. **Deploy** with the `sync` profile to enable the sidecar:
   ```bash
   # From infra repo:
   make push-env && make deploy
   ```

On start: gateway clones the workspace repo. Sidecar pushes changes on the configured schedule (default: daily at 4 AM UTC).

### Disable

Remove or clear `GIT_WORKSPACE_REPO` from your `.env` and redeploy. The workspace will still exist for the container's lifetime but won't persist across restarts.

## Accessing the Dashboard

The gateway binds to loopback only (`127.0.0.1:18789`). Access it via SSH tunnel:

```bash
ssh -N -L 18789:127.0.0.1:18789 openclaw@VPS_IP
```

Then open `http://localhost:18789` in your browser.

## Managing Secrets

Secrets (API keys, tokens) are managed by the **infra repo**, not this repo.
This repo only contains `docker/.env.example` as documentation of what
variables are required.

In the infra repo:
- Edit `secrets/openclaw.env`
- Run `make push-env` to push to VPS and restart

## Docker Image Versioning

Images are built locally and pushed to GHCR via `scripts/build-and-push.sh`:

- `ghcr.io/YOUR_USERNAME/openclaw-docker-config/openclaw-gateway:latest` — main gateway image
- `ghcr.io/YOUR_USERNAME/openclaw-docker-config/workspace-sync:latest` — workspace git sync sidecar
- Both images also get a `:<sha>` tag pinned to the git commit

**One-time GHCR login (laptop):**

```bash
# Create a PAT at github.com/settings/tokens with write:packages scope
echo "$GHCR_PAT" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

**Rollback to a previous version:**

```bash
# On the VPS, in ~/openclaw/:
# Edit docker-compose.yml, change :latest to the SHA tag (e.g. :abc1234)
docker compose pull && docker compose up -d
```

**Upgrade OpenClaw itself:** bump `OPENCLAW_VERSION` in `docker/Dockerfile`, commit, push, then run `scripts/build-and-push.sh` followed by `make deploy` from the infra repo.

## Troubleshooting

### Container won't start

```bash
# From the infra repo:
make logs
# Or SSH in:
cd ~/openclaw && docker compose logs openclaw-gateway
```

Check for missing environment variables or invalid config JSON.

### "Permission denied" errors

State is stored in a Docker-managed volume (`openclaw_data`) so there are no host directory ownership issues. If you see permission errors inside the container, recreate the volume:

```bash
docker compose down -v
docker compose up -d
```

### Telegram bot not responding

- Check secrets: `make push-env` from infra repo to re-push
- Check that no other process is polling the same bot token
- Restart: `make deploy` from infra repo

### Config validation fails

```bash
bash scripts/validate-config.sh
```

Common causes:
- Invalid JSON syntax (missing comma, trailing comma)
- Raw API key accidentally pasted into `openclaw.json`

### Check VPS health

```bash
# From the infra repo:
make status
```

## Enable Git Hooks

To activate the pre-commit validation hook:

```bash
git config core.hooksPath .githooks
```
