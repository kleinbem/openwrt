# OpenWrt System Reference

This document serves as the ground truth for the OpenWrt router configuration.

## Hardware
- **Model**: Banana Pi BPI-R4 (Filogic 880)
- **Architecture**: aarch64_cortex-a53
- **CPU**: MediaTek MT7988A
- **RAM**: 4 GB DDR4, **used in full** since 2026-10-20 (no `mem=` in `uEnv.txt`). The earlier `mem=2048M` cap only guarded MT7988 hardware flow-offloading, which is off (SQM). `roles/common` asserts the kernel sees ~4 GiB and no `mem=` on the cmdline. See docs/NETWORK_PLAN.md runbook step 2 for what to watch on the first boot.
- **Storage** (OS boots from **eMMC**; SD = installer/rescue; **both routers
  get an NVMe SSD**, 2026-07-19 — `kmod-nvme` is in the image):
    - core-gateway: 8GB eMMC (OS) + **NVMe** for *storage* — persistent local
      logs, banIP data, swap. Kept to storage (not heavy LXC): it's the
      routing box, so compute stays light.
    - ap-upstairs: 8GB eMMC (OS) + **NVMe** for *compute* — LXC storage
      (`/srv/lxc`) + data. The compute-capable router.
    - SPI-NAND (128MB): bootloader + recovery fallback (written during install chain)
    - ⚠️ SSDs are mounted at the bench (format is a **manual** step — the role
      never auto-formats a disk); smartmontools watches health once mounted.
- **Interfaces**:
    - WAN: eth1 (SFP/2.5G)
    - LAN: eth0 (Switch/2.5G)

### Netgear Orbi RBR50 + 3× RBS50 (v1) — access points, reuse of the old mesh
- **Model**: Netgear Orbi RBK50 kit: 1× RBR50 ("router") + 3× RBS50 (satellites),
  all **hardware v1** (OpenWrt `ipq40xx/generic`, supported since 22.03).
  RBR50 verified 2026-10-20 via telnet on the Voxel firmware: `artmtd -r
  hw_revision` empty, 4 GB eMMC `mmcblk0`. **Each RBS50 still needs the same
  check before flashing**: USB port on the back = v1; no USB port = v2 (SPI
  NAND, `hw_revision` 02) — v2 is only an open upstream PR
  (openwrt/openwrt#22321) and the v1 image will not boot on it.
- **SoC**: Qualcomm IPQ4019 (4× Cortex-A7 @ 717 MHz), 512 MB RAM, 4 GB eMMC
- **Radios**: IPQ4019 2.4 GHz 2x2 · IPQ4019 5 GHz 2x2 · QCA9984 5 GHz 4x4 (the
  stock "backhaul" radio — a normal third AP radio under OpenWrt). Wi-Fi 5.
- **Ports**: lan1 lan2 lan3 + wan (1 GbE), USB 2.0. No SFP.
- **Role**: under OpenWrt there is no router/satellite distinction and no
  Orbi mesh — every unit is an AP (`ap-<location>`, board `orbi-rbr50` /
  `orbi-rbs50`) behind the BPI-R4s with the same SSIDs/VLANs and
  802.11r/k/v + DAWN roaming. Topology stays Orbi-like: the RBR50 is wired
  to a BPI-R4 (tagged trunk on its `wan` port, inventory tag `mesh-gate`),
  the three RBS50 are **free-standing** on an encrypted 802.11s backhaul
  (tag `mesh-node`) carried by the 4x4 QCA9984 radio on channel 36 (non-DFS,
  VHT80). The mesh netdev (`mesh0`) is a tagged trunk port of `br-lan`, so
  every VLAN + MPSK rides it unchanged; nodes get no wired trunk (loop
  guard) and STP is on wherever a backhaul exists. Needs
  `wifi_backhaul_key` in `kleinbem-secrets/openwrt/shared.yaml`.
  Multi-hop (node via node) works through 802.11s forwarding but costs
  throughput per hop; place nodes within reach of the gate where possible.
- **Why bother**: zero cost, already placed around the house, mature ath10k
  radios with whole-home range, and OpenWrt keeps patching them long after
  Voxel stops. Not a router: the A7 cores cap SQM at ~200–300 Mbit/s.
- **Install** (v1): `nmrpflash` with `dist/*-netgear_rbr50-squashfs-factory.img`
  (or `rbs50`) on the LAN port nearest the power button, device powered on
  after nmrpflash is listening. Alternative via the OEM/Voxel web UI only
  after `artmtd -w boot_part 02` + reboot (OpenWrt runs from boot partition 1;
  the UI always flashes the inactive one). **Order of operations**: the RBR50
  is today's gateway at 10.0.0.1 — flash it only after the BPI-R4 pair has
  taken over routing. Revert = nmrpflash with a stock Netgear `.img`.

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
- **Passphrases**: `kleinbem-secrets/openwrt/shared.yaml` (sops); one per VLAN.
- **Band**: 2.4 / 5 / 6 GHz (tri-band BE14000 / MT7996) on the BPI-R4s;
  2.4 / 5 / 5 GHz (Wi-Fi 5) on the Orbi APs — per-board widths + fixed
  channel plan in `openwrt-config/ansible/group_vars/board_<board>.yml`.
- **TX-power assertion**: `roles/wifi` fails the run if any AP radio reports
  < `wifi_min_txpower_dbm` (15) — the mt76/BE14000 EEPROM trap where every
  radio comes up at 6 dBm is the usual "R4 coverage is bad" root cause.
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
- **Firmware**: OpenWrt release pinned per profile in `openwrt-builder/profiles/` (currently 25.12.5, sha256-verified ImageBuilder) — `bpi-r4`, `orbi-rbr50`, `orbi-rbs50`; bump them together.
- **Image Builder**: Located in `openwrt-builder/`; `just build <profile>` → `./dist`
- **Inventory**: every OpenWrt host in `inventory.nix` carries `board = …`; the
  generator emits `[openwrt]` (+ per-host `mgmt_ip`) and `[board_<board>]`
  groups that select `group_vars/board_<board>.yml`.
- **Boot**: eMMC (SD = installer/rescue; NVMe on ap-upstairs = LXC data). See docs/NETWORK_PLAN.md.
- **Configuration**: Applied via Ansible in `openwrt-config/`; inventory generated from `../nix/nix-config/inventory.nix` (`just maintenance::sync-inventory`)
- **LXC on ap-upstairs**: capability retained (NVMe `/srv/lxc`) but dormant — the NixOS "brain" containers were dropped 2026-07-18 (fleet hosts the services).
