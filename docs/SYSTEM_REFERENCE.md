# OpenWrt System Reference

This document serves as the ground truth for the OpenWrt router configuration.

## Hardware
- **Model**: Banana Pi BPI-R4 (Filogic 880)
- **Architecture**: aarch64_cortex-a53
- **CPU**: MediaTek MT7988A
- **RAM**: 4GB DDR4 — **run at 2 GiB** (`mem=2048M` in U-Boot): MT7988 hardware flow-offloading drops packets when the full 4 GiB is addressed (upstream-unresolved). See docs/NETWORK_PLAN.md.
- **Storage** (OS boots from **eMMC**; SD = installer/rescue; **both routers
  get an NVMe SSD**, 2026-07-19 — `kmod-nvme` is in the image):
    - core-gateway: 8GB eMMC (OS) + **NVMe** for *storage* — persistent local
      logs, banIP data, swap. Kept to storage (not heavy LXC): it's the
      routing box and runs at 2 GiB, so compute stays light.
    - ap-upstairs: 8GB eMMC (OS) + **NVMe** for *compute* — LXC storage
      (`/srv/lxc`) + data. The compute-capable router.
    - SPI-NAND (128MB): bootloader + recovery fallback (written during install chain)
    - ⚠️ SSDs are mounted at the bench (format is a **manual** step — the role
      never auto-formats a disk); smartmontools watches health once mounted.
- **Interfaces**:
    - WAN: eth1 (SFP/2.5G)
    - LAN: eth0 (Switch/2.5G)

## Network Map
- **Primary Subnet**: `10.0.0.0/16`, VLAN-segmented (infra/trusted/iot/cameras/guest/work — see docs/NETWORK_PLAN.md). `192.168.1.0/24` is bench-bootstrap only.
- **Gateway (core-gateway)**: 10.0.0.1 (bench bootstrap: 192.168.1.1)
- **Access Point (ap-upstairs)**: 10.0.0.2 (**LXC Host**, NVMe storage @ `/srv/lxc`)
- LXC "brain" containers dropped 2026-07-18 (never deployed; ap-upstairs keeps LXC capability + NVMe, dormant)
- Naming scheme: role + location — the single gateway is `core-gateway`, extenders are `ap-<location>`; source of truth `../nix/nix-config/inventory.nix`

## Wireless (Wi-Fi 7)
- **Layout** (migration-safe, MPSK — password picks the VLAN): `16CVG` (WPA2,
  exact old-router copy → trusted, for a seamless swap) · `16CVG-W3` (WPA3
  MPSK → trusted/work/iot/cameras) · `16CVG-W2` (WPA2 MPSK → iot/cameras only)
  · `16CVG-Guest` (WPA3, isolated). Details: docs/NETWORK_PLAN.md.
- **Security**: WPA3-SAE where it matters; WPA2 on `16CVG` (old-router match)
  and the `-W2` compat tier (low-trust VLANs only). 6 GHz forced pure WPA3.
- **Passphrases**: `openwrt-secrets/ansible-vars.yaml` (sops); one per VLAN.
- **Band**: 2.4 / 5 / 6 GHz (tri-band BE14000 / MT7996)
- ⚠️ MPSK dynamic-VLAN needs bench validation (25.12 ucode `wpa_psk_file` #20355).

## Services (all OpenWrt-native, configured by Ansible roles)
- **DNS / DHCP**: dnsmasq-full — per-VLAN DHCP pools; DNS policy per `dns` tier
  (trusted → AdGuard+gateway fallback, filtered → AdGuard+hijack, local → gateway)
- **VLAN segmentation** (`roles/network`): bridge-VLANs, firewall zone matrix,
  mgmt-plane lockdown (infra-only), DNS hijack for untrusted zones
- **Wi-Fi** (`roles/wifi`): MPSK (password→VLAN) on `16CVG-W3`/`-W2` + legacy
  `16CVG` (WPA2, old-router match) + `16CVG-Guest`; DAWN steering
- **QoS** (`roles/qos`): SQM/cake bufferbloat control on the WAN (set line speed)
- **Edge security** (`roles/banip`): threat-feed IP blocking at the WAN
- **NTP server**, **mDNS reflector** (trusted↔iot) — `roles/network`
- **Monitoring**: prometheus-node-exporter-lua (scraped by the fleet) + collectd
- **Remote access**: via NetBird on the fleet (no router-hosted VPN;
  WireGuard/Tailscale kmods present but unused)

## Deployment
- **Firmware**: OpenWrt release pinned in `openwrt-builder/profiles/bpi-r4.conf` (currently 25.12.5, sha256-verified ImageBuilder)
- **Image Builder**: Located in `openwrt-builder/` (Profile: `bpi-r4`); `just build bpi-r4` → `./dist`
- **Boot**: eMMC (SD = installer/rescue; NVMe on ap-upstairs = LXC data). See docs/NETWORK_PLAN.md.
- **Configuration**: Applied via Ansible in `openwrt-config/`; inventory generated from `../nix/nix-config/inventory.nix` (`just maintenance::sync-inventory`)
- **LXC on ap-upstairs**: capability retained (NVMe `/srv/lxc`) but dormant — the NixOS "brain" containers were dropped 2026-07-18 (fleet hosts the services).
