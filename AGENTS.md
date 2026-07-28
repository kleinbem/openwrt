# AGENTS.md

Guidance for AI assistants (Claude Code, Gemini CLI, Codex, Aider, Antigravity, …) working in this repository. Tool-specific filenames (`CLAUDE.md`, `GEMINI.md`) are symlinks to this file.

## Overview

This is a **meta-workspace dir** — a tooling-only orchestrator for the OpenWrt router infrastructure, mirroring the `../nix` meta-workspace. **There is no `flake.nix` at the meta root.** The meta dir holds `just`, `.agent/`, and the `.envrc` that points direnv at `../nix/nix-devshells#openwrt`. The fleet-wide sub-repo manifest lives at `kleinbem/repos.nix`, not here.

**On a truly fresh clone of just this repo, run `bash tools/bootstrap.sh` first** — `just` itself won't parse until `kleinbem/` exists (the shared `.just/common.just` and `.just/jj.just` are symlinks into it), and `tools/bootstrap.sh` clones `kleinbem/` before handing off to the normal `just jj::bootstrap`. On any machine where `kleinbem/` already exists, `just jj::bootstrap` alone is enough.

## Key Commands

All common operations go through `just`. Run `just` (no args) to open an fzf-based interactive hub.

```bash
# Environment
direnv allow                            # Load the openwrt shell from nix-devshells
nix develop ../nix/nix-devshells#openwrt  # Pure fallback (no direnv)

# Firmware & provisioning
just build bpi-r4                 # Containerized ImageBuilder run → ./dist
just provision                    # Ansible playbooks against the live routers
just verify                       # Ansible check mode against the live routers

# Validation & linting (offline — never touches the routers)
just check-all                    # Linters + ansible syntax + justfile parse
just maintenance::lint-all        # shellcheck + yamllint + ansible-lint + nixfmt
just maintenance::format-all      # Format nix files
just maintenance::sync-inventory  # Regenerate inventory.ini from nix-config/inventory.nix

# Version Control (Jujutsu / jj operates across all sub-repos)
just jj::status-all               # Dashboard showing repo state + ahead-of-origin
just jj::save-all "message"       # Commit in all dirty repos + root
just jj::push-all                 # Push all repos
just jj::pull-all                 # Pull --rebase all repos
just jj::ship                     # Describe + sign + push (the everything button)

# Cleanup
just maintenance::clean-all       # Remove build artifacts, git gc all repos
```

## Repo Hierarchy

Sub-repos are **flat siblings of `openwrt/`** (under the workspace root, `~/Develop/github.com/kleinbem/`) — NOT nested inside `openwrt/`, and there's no compat symlink either, so every reference goes through `../` (or `{{ROOT}}` in justfiles):

```
~/Develop/github.com/kleinbem/  (workspace root)
├── kleinbem/         ← profile repo; fleet-wide repos.nix + shared .just/ modules live here
├── openwrt/          ← meta workspace dir — NO flake.nix; tooling only: just, .agent/
├── openwrt-builder   ← firmware image generation (OpenWrt ImageBuilder, profile bpi-r4)
├── openwrt-config    ← declarative runtime config of the routers via Ansible
└── openwrt-secrets   ← sops/age-encrypted secrets (wifi keys, vault password)
```

All sub-repos are **standalone git+jj repos** (NOT git submodules — see `kleinbem/repos.nix` for the fleet-wide manifest, `bash tools/bootstrap.sh` to set up a truly fresh machine or `just jj::bootstrap` once `kleinbem/` exists).

## Ground Truth

- **System reference**: `docs/SYSTEM_REFERENCE.md` — hardware, network map, services.
- **Inventory**: generated — the master is `../nix/nix-config/inventory.nix`. Never edit `openwrt-config/ansible/inventory.ini` by hand; run `just maintenance::sync-inventory`.
- **Agent rules**: `.agent/rules.md`.

## Code Standards

- **Firmware sources are pinned**: `openwrt-builder/profiles/*.conf` pin an exact OpenWrt release AND the ImageBuilder sha256. Bumps change both together; never point at `snapshots/`.
- **Secrets**: sops/age via `openwrt-secrets`. Never commit plaintext secrets — including Wi-Fi credentials in ansible `group_vars`.
- Shell scripts pass `shellcheck`; YAML passes `yamllint` + `ansible-lint` (`just check-all` before shipping).
- jj is the primary VCS verb; use git only for genuinely-git operations.
