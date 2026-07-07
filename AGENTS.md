# AGENTS.md

Guidance for AI assistants (Claude Code, Gemini CLI, Codex, Aider, Antigravity, …) working in this repository. Tool-specific filenames (`CLAUDE.md`, `GEMINI.md`) are symlinks to this file.

## Overview

This is a **meta-workspace dir** — a tooling-only orchestrator for the OpenWrt router infrastructure, mirroring the `../nix` meta-workspace. **There is no `flake.nix` at the meta root.** The meta dir holds `just`, `repos.nix`, `.agent/`, and the `.envrc` that points direnv at `../nix/nix-devshells#openwrt`. Bootstrap a fresh checkout with `just jj::bootstrap`.

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

```
openwrt/ (meta workspace dir — NO flake.nix; tooling only: just, repos.nix, .agent/)
├── openwrt-builder  ← firmware image generation (OpenWrt ImageBuilder, profile bpi-r4)
├── openwrt-config   ← declarative runtime config of the routers via Ansible
└── openwrt-secrets  ← sops/age-encrypted secrets (wifi keys, vault password)
```

All sub-repos are **standalone git+jj repos** cloned under the meta dir (NOT git submodules — see `repos.nix` for the manifest, `just jj::bootstrap` to set up a fresh machine).

## Ground Truth

- **System reference**: `docs/SYSTEM_REFERENCE.md` — hardware, network map, services.
- **Inventory**: generated — the master is `../nix/nix-config/inventory.nix`. Never edit `openwrt-config/ansible/inventory.ini` by hand; run `just maintenance::sync-inventory`.
- **Agent rules**: `.agent/rules.md`.

## Code Standards

- **Firmware sources are pinned**: `openwrt-builder/profiles/*.conf` pin an exact OpenWrt release AND the ImageBuilder sha256. Bumps change both together; never point at `snapshots/`.
- **Secrets**: sops/age via `openwrt-secrets`. Never commit plaintext secrets — including Wi-Fi credentials in ansible `group_vars`.
- Shell scripts pass `shellcheck`; YAML passes `yamllint` + `ansible-lint` (`just check-all` before shipping).
- jj is the primary VCS verb; use git only for genuinely-git operations.
