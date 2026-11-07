# AI Assistant Rules (OpenWrt)

## Core Principles
1.  **Source of Truth**: The master inventory is located in the `nix` repository (`nix-config/inventory.nix`). Do not update `inventory.ini` manually; use `just maintenance::sync-inventory`.
2.  **Reproducibility**: Ensure the OpenWrt image build is as reproducible as possible.
3.  **Immutability where possible**: Treat the router as a target for declarative configuration (via Ansible).
4.  **Minimalism**: Keep the router image small. Only install necessary packages.
5.  **Monitoring**: All physical routers must run `prometheus-node-exporter-lua` to integrate with the central Nix monitoring stack.
6.  **Verify First**: Always validate Ansible syntax and build configs before deployment.

## Workflow
- **Use `just`**: Prefer `just <command>` for orchestration.
- **Namespaces**: Use namespaced commands for clarity (e.g., `just config::provision`, `just maintenance::check-all`).
- **jj-first**: VCS operations go through `just jj::*` (status-all, save-all, push-all, ship). Sub-repos are standalone git+jj repos from `repos.nix`, not submodules.
- **Secrets**: Never commit plain-text secrets. Use SOPS with age/ssh keys.
- **Cross-Workspace**: Note that `openwrt-config` and `openwrt-secrets` are also visible in the `nix.code-workspace` to allow for unified infrastructure management.

## Architecture
- **Control Plane**: This repo is the entry point for all router operations. Tooling-only — no `flake.nix` here; the devshell comes from `../nix/nix-devshells#openwrt`.
- **Sub-repos**:
    - `openwrt-builder`: Logic for generating the firmware image.
    - `openwrt-config`: Declarative state (Ansible) for the running router.
    - `openwrt-secrets`: Encrypted configuration values.

## System Context
- **Ground Truth**: Check `docs/SYSTEM_REFERENCE.md` for IP addresses, hardware specs, and VLAN maps.
- **Status Checks**: Run `just verify` to check the health of the router and configuration.
