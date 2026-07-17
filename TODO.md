# Project Tasks

- [x] Establish architectural parity with Nix Meta-Workspace
- [x] Modularize Justfile orchestration and implement interactive fzf hub
- [x] Drop git submodule pointers → `repos.nix` manifest + `just jj::bootstrap` (2026-07-07)
- [x] Drop meta flake/devenv → shared `nix-devshells#openwrt` shell (2026-07-07)
- [x] Pin firmware source to a released OpenWrt version + sha256 (25.12.5, 2026-07-07)
- [x] Wi-Fi radio role — WPA3 SSID-per-VLAN, 802.11r + DAWN (2026-07-17)
- [x] Network/VLAN role — bridge-vlans, per-VLAN DHCP, firewall matrix (2026-07-17)
- [x] Native router services — NTP server, mDNS reflector, DNS hijack, mgmt-plane lockdown, split-trust DNS fallback (2026-07-18)
- [ ] Create `kleinbem/openwrt` on GitHub via github-config (terraform) and push the meta repo
- [ ] Flash + provision the BPI-R4 pair (see docs/SYSTEM_REFERENCE.md network map)

Dropped: ~~WireGuard VPN via Ansible~~ — NetBird already covers fleet remote
access; a second VPN plane on the router is complexity without a user. Native
WG is a quick add later if NetBird ever falls short (kmods are in the image).
