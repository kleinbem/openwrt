# OpenWrt System Reference

This document serves as the ground truth for the OpenWrt router configuration.

## Hardware
- **Model**: Banana Pi BPI-R4 (Filogic 880)
- **Architecture**: aarch64_cortex-a53
- **CPU**: MediaTek MT7988A
- **RAM**: 4GB DDR4
- **Storage** (decided 2026-07-17: OS boots from **eMMC**; SD = installer/rescue only):
    - core-gateway: 8GB eMMC (OS)
    - ap-upstairs: 8GB eMMC (OS) + **NVMe (Crucial P3 1TB)** for LXC storage
    - SPI-NAND (128MB): bootloader + recovery fallback (written during install chain)
- **Interfaces**:
    - WAN: eth1 (SFP/2.5G)
    - LAN: eth0 (Switch/2.5G)

## Network Map
- **Primary Subnet**: 192.168.1.0/24
- **Gateway (core-gateway)**: 10.0.0.1 (bench bootstrap: 192.168.1.1)
- **Access Point (ap-upstairs)**: 10.0.0.2 (**LXC Host**, NVMe storage @ `/srv/lxc`)
- LXC "brain" containers dropped 2026-07-18 (never deployed; ap-upstairs keeps LXC capability + NVMe, dormant)
- Naming scheme: role + location — the single gateway is `core-gateway`, extenders are `ap-<location>`; source of truth `../nix/nix-config/inventory.nix`

## Wireless (Wi-Fi 7)
- **SSID / passphrase**: in `openwrt-secrets/ansible-vars.yaml` (sops)
- **Security**: WPA3 (SAE)
- **Band**: 2.4GHz / 5GHz / 6GHz (Tri-band)

## Services
- DNS: Dnsmasq
- DHCP: Dnsmasq
- VPN: WireGuard (Planned)
- Automation: Home Assistant (via NixOS LXC @ 192.168.1.5)

## Deployment
- **Firmware**: OpenWrt release pinned in `openwrt-builder/profiles/bpi-r4.conf` (currently 25.12.5, sha256-verified ImageBuilder)
- **Image Builder**: Located in `openwrt-builder/` (Profile: `bpi-r4`); `just build bpi-r4` → `./dist`
- **Configuration**: Applied via Ansible in `openwrt-config/`; inventory generated from `../nix/nix-config/inventory.nix` (`just maintenance::sync-inventory`)
- **NixOS Guest**: Managed in the `nix` repository; deployed via `just deploy-router-lxc`.
