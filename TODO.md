# Project Tasks

- [x] Establish architectural parity with Nix Meta-Workspace
- [x] Modularize Justfile orchestration and implement interactive fzf hub
- [x] Drop git submodule pointers → `repos.nix` manifest + `just jj::bootstrap` (2026-07-07)
- [x] Drop meta flake/devenv → shared `nix-devshells#openwrt` shell (2026-07-07)
- [x] Pin firmware source to a released OpenWrt version + sha256 (25.12.5, 2026-07-07)
- [ ] Create `kleinbem/openwrt` on GitHub via github-config (terraform) and push the meta repo
- [ ] Implement WireGuard VPN provisioning via Ansible
- [ ] Flash + provision the BPI-R4 pair (see docs/SYSTEM_REFERENCE.md network map)
