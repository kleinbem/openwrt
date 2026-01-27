# Project Rules

This is a "Meta-Repository" that manages the OpenWrt project context.

## Structure

- `.` (Root): The control plane. Contains agent config and workspace settings.
- `openwrt-builder/`: Repository for building the OpenWrt image (logic, automation).
- `openwrt-config/`: Repository for router configuration (ansible, etc.).
- `openwrt-secrets/`: Private secrets repository.

## Agent Behavior

- When asked to "update repos", run the defined workflow.
- Always check `memory.md` for ongoing context.
