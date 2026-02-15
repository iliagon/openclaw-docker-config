# OpenClaw Docker Config

Docker configuration and application setup for OpenClaw. Companion repository to [openclaw-terraform-hetzner](https://github.com/YOUR_USERNAME/openclaw-terraform-hetzner).

**Note:** This is a minimal, generic configuration with only essential skills activated. You're encouraged to customize it by adding [ClawHub skills](https://clawhub.ai/) or creating your own custom skills (see [Working with Skills](#working-with-skills)).

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
│              │  make push-config       ┌──────────────────────┐
│              │  make push-env          │   Hetzner VPS        │
│              │──── (infra repo) ──────▶│   ┌────────────────┐ │
│              │  make deploy            │   │ Docker         │ │
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
| `config/*` (openclaw.json, etc.) | `make push-config` | `~/.openclaw/` |
| Docker image | `make deploy` (pulls from GHCR) | Docker image cache |
| Secrets | `make push-env` | `~/openclaw/.env` |

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
4. Run `make bootstrap` from the infra repo — copies `docker-compose.yml`, config, and secrets to VPS
5. Run `make deploy` from the infra repo — pulls the Docker image from GHCR and starts the container
6. **Complete Telegram pairing:** open Telegram, find your bot, send `/start`

## Config Change Workflow

There are two types of changes, and they have different workflows:

### Changing config (openclaw.json, skills, hooks)

Config files are pushed to the VPS via SCP — no image rebuild needed.

```
edit → validate → commit → push → make push-config (infra repo)
```

1. Edit files in `config/`, `skills/`, or `hooks/`
2. Validate: `bash scripts/validate-config.sh`
3. Commit and push to GitHub
4. From the **infra repo**: `make push-config` (SCPs config to VPS and restarts)

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

This repository includes a minimal set of generic skills in `config/skills-manifest.txt`. You can extend OpenClaw by adding ClawHub skills or creating custom skills.

### ClawHub Skills

[ClawHub](https://clawhub.ai/) is the community skill registry for OpenClaw. To add a ClawHub skill:

1. **Find the skill** at [clawhub.ai](https://clawhub.ai/) (e.g., `pdf`, `ms-office-suite`, `jira`)
2. **Add to manifest**: Edit `config/skills-manifest.txt` and add the skill name
   ```
   # PDF processing
   pdf
   ```
3. **Rebuild and deploy**:
   ```bash
   bash scripts/build-and-push.sh
   # Then from infra repo:
   make deploy
   ```

The `entrypoint.sh` script auto-installs skills from the manifest on container startup via `clawhub install`.

### Custom Skills

Custom skills are user-defined commands or workflows. To create one:

1. **Create the skill directory**:
   ```bash
   mkdir -p skills/my-skill
   ```

2. **Write the skill manifest** (`skills/my-skill/skill.json`):
   ```json
   {
     "name": "my-skill",
     "version": "1.0.0",
     "description": "My custom skill",
     "commands": {
       "my-command": {
         "handler": "my-command.sh"
       }
     }
   }
   ```

3. **Write the handler** (`skills/my-skill/my-command.sh`):
   ```bash
   #!/bin/bash
   # Your custom logic here
   echo "Hello from my-skill!"
   ```

4. **Make it executable**:
   ```bash
   chmod +x skills/my-skill/my-command.sh
   ```

5. **Push to VPS**:
   ```bash
   # From the infra repo:
   make push-config
   ```

   Custom skills in `skills/` are copied to `~/.openclaw/workspace/skills/` on the VPS.

6. **Use in OpenClaw**:
   - Via chat: "Run my-command"
   - Via Telegram: `/my-command`

### Skill Structure Reference

OpenClaw skills can include:
- **Slash commands** — callable via `/command-name`
- **Hooks** — triggered on events (e.g., before tool execution)
- **Templates** — prompt templates for common workflows
- **Tools** — custom tool definitions

For detailed skill development documentation, see the [OpenClaw Skill Development Guide](https://docs.openclaw.ai/skills).

### Included Skills

The default configuration includes these generic ClawHub skills:

| Skill | Description | Use Case |
|-------|-------------|----------|
| `yt` | YouTube transcript fetching and video search | "Get transcript for youtube.com/watch?v=..." |
| `agent-browser` | Headless browser for JavaScript-heavy/paywalled pages | Access dynamic content |
| `system-monitor` | CPU/RAM/GPU status check | "What's my server's CPU usage?" |
| `conventional-commits` | Format commit messages per convention | Standardized commit messages |

These are intentionally minimal — add your own skills based on your workflows.

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

- `ghcr.io/YOUR_USERNAME/openclaw-docker-config/openclaw-gateway:latest` — default tag, what the VPS pulls
- `ghcr.io/YOUR_USERNAME/openclaw-docker-config/openclaw-gateway:<sha>` — pinned to a specific commit

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

### "Permission denied" on config directory

Ensure the host directories exist and are owned by the correct user:

```bash
sudo mkdir -p /home/openclaw/.openclaw/workspace
sudo chown -R 1000:1000 /home/openclaw/.openclaw
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
