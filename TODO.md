# Project Tasks

- [x] Establish architectural parity with Nix Meta-Workspace
- [x] Modularize Justfile orchestration and implement interactive fzf hub
- [x] Drop git submodule pointers → `repos.nix` manifest + `just jj::bootstrap` (2026-07-07)
- [x] Drop meta flake/devenv → shared `nix-devshells#openwrt` shell (2026-07-07)
- [x] Pin firmware source to a released OpenWrt version + sha256 (25.12.5, 2026-07-07)
- [x] Wi-Fi radio role — WPA3 SSID-per-VLAN, 802.11r + DAWN (2026-07-17)
- [x] Network/VLAN role — bridge-vlans, per-VLAN DHCP, firewall matrix (2026-07-17)
- [x] Native router services — NTP server, mDNS reflector, DNS hijack, mgmt-plane lockdown, split-trust DNS fallback (2026-07-18)
- [x] MPSK Wi-Fi (password→VLAN, W3/W2 tiers) + migration-safe 16CVG (WPA2 old-router copy) + work VLAN (2026-07-18)
- [x] QoS/SQM (cake, WAN bufferbloat) + banIP (edge threat-feed blocking) roles (2026-07-19)
- [x] Hardening/tuning — firewall (drop-invalid/synflood), IGMP snooping, 802.11k/v roaming, dnsmasq rebind-protection, remote syslog (2026-07-19)
- [x] UI — Material theme + per-service LuCI apps + network hub landing page; monitoring collectors (2026-07-19)
- [x] Native services — AdGuard Home (adguard_local DNS rework, moved off hass-pi), self-contained CrowdSec IPS, optional WireGuard break-glass (2026-07-19)
- [ ] Observability + AI-assisted analysis — see docs/OBSERVABILITY_AI.md (design; needs your decisions)
- [ ] Both routers: mount NVMe at bench (format is manual) — gateway=logs/data, ap=LXC
- [ ] Create `kleinbem/openwrt` on GitHub via github-config (terraform) and push the meta repo
- [ ] Flash + provision the BPI-R4 pair (see docs/SYSTEM_REFERENCE.md network map)

Deferred (need a design decision or runtime prereq, see docs / session notes):
- **CrowdSec firewall bouncer** — would enforce the fleet's CrowdSec decisions
  at the router edge, but the LAPI (`10.85.48.119`, container bridge) isn't
  reachable from the gateway's LAN as-is; needs a published/NetBird endpoint
  first. banIP covers the self-contained edge-blocking case meanwhile.
- **SQM line speeds** — `wan_down_mbit`/`wan_up_mbit` are 0 (SQM no-op) until
  set to a measured speedtest at the bench.
- **MPSK WPA3-SAE VLANs** — `wpa_psk_file` is WPA2-side; true SAE per-VLAN
  routing may need `sae_password`+`vlanid` in roles/wifi (bench-decide).

Dropped: ~~WireGuard VPN via Ansible~~ — NetBird already covers fleet remote
access; a second VPN plane on the router is complexity without a user. Native
WG is a quick add later if NetBird ever falls short (kmods are in the image).
