# Network Transition Plan — flat → VLAN-segmented 10.x

**Decision (2026-07-08):** stay on `10.x` long-term, segment it into per-purpose
VLANs, and bring the BPI-R4 in as the gateway by **bench-provisioning then
swapping** it for the current 10.x router. Rationale: many devices + IoT — a
flat `/16` gives addresses but no isolation; VLANs stop a compromised IoT
device from reaching infra/servers.

## Addressing

Gateway owns `.1` in every subnet. The fleet compute (Tang, AdGuard, servers)
stays in the **infra** VLAN so headless LUKS unlock keeps working within-zone.

| VLAN | Subnet         | Zone     | Purpose                                   |
|-----:|----------------|----------|-------------------------------------------|
| 1    | 10.0.0.0/24    | infra    | fleet servers: Tang `.5`, AdGuard `.21`, core-pi `.22`, orin `.12`, gateway `.1` |
| 10   | 10.0.10.0/24   | trusted  | laptops, phones, workstations             |
| 20   | 10.0.20.0/24   | iot      | smart-home gear — internet + DNS only     |
| 30   | 10.0.30.0/24   | cameras  | cameras/NVR — no internet                 |
| 40   | 10.0.40.0/24   | guest    | guest devices — internet only             |

Room to grow: each is a `/24` (254 hosts) carved from `10.0.0.0/8`; bump any to
a `/16` (e.g. `10.20.0.0/16` for IoT) later without renumbering the others.

### Infra VLAN 1 fixed addresses (`10.0.0.0/24`)

The whole fleet is 10.x — no `192.168.x` remains. Network layer in `.1–.9`,
servers/fleet keep their established octets, DHCP pool is `.100–.199`.

| IP        | Host          | Role                                   |
|-----------|---------------|----------------------------------------|
| 10.0.0.1  | core-gateway  | BPI-R4 main gateway (downstairs)       |
| 10.0.0.2  | ap-upstairs   | BPI-R4 AP / LXC host (upstairs)        |
| 10.0.0.3  | router-1      | NixOS LXC brain                        |
| 10.0.0.4  | router-2      | NixOS LXC brain                        |
| 10.0.0.5  | nixos-nvme    | workstation + Tang (LUKS unlock anchor)|
| 10.0.0.6  | *(free)*      | reserved for the next `ap-<location>`  |
| 10.0.0.7  | net-brain     | NixOS LXC on ap-upstairs (was `.5`¹)   |
| 10.0.0.12 | orin-nano     | AI edge + Tang                         |
| 10.0.0.21 | hass-pi       | Home Assistant + AdGuard + Tang        |
| 10.0.0.22 | core-pi       | cache entrypoint + Tang                |
| 10.0.0.30 | nasbook       | NAS + Tang                             |

¹ net-brain moved off `.5` — that octet is nixos-nvme/Tang, which can't move
  (the clevis LUKS binding is anchored there). Source of truth:
  `../nix/nix-config/inventory.nix`.

> Bench bootstrap: the BPI-R4 firmware still first-boots at `192.168.1.1` (the
> ImageBuilder default). For the one-time bench provisioning, reach it there
> (`-e ansible_host=192.168.1.1`); the role then moves it to `10.0.0.1`, after
> which the inventory address is correct for all subsequent runs.

## Firewall zone matrix

| From → To | infra | trusted | iot | cameras | guest | wan |
|-----------|:-----:|:-------:|:---:|:-------:|:-----:|:---:|
| infra     |  —    |   ✓     |  ✓  |   ✓     |  ✗    |  ✓  |
| trusted   |  ✓    |   —     |  ✓  |   ✓     |  ✗    |  ✓  |
| iot       | DNS¹  |   ✗     |  —  |   ✗     |  ✗    |  ✓  |
| cameras   | DNS¹  |   ✗     |  ✗  |   —     |  ✗    |  ✗² |
| guest     | DNS¹  |   ✗     |  ✗  |   ✗     |  —    |  ✓  |

¹ **DNS exception:** allow UDP/TCP 53 (+853) from iot/cameras/guest to AdGuard
  `10.0.0.21` only — so every VLAN resolves via AdGuard without opening infra.
² cameras get **no WAN** (no phone-home); a trusted host or NVR pulls streams.

**LUKS constraint (do not break):** headless hosts unlock via clevis SSS with
threshold **t=1** across a **Tang mesh** — every capable fleet host runs Tang
(nixos-nvme `.5`, orin `.12`, core-pi `.22`, hass-pi `.21`, nasbook, …), and
reaching **any one** of them unlocks. The mesh and the unlock hosts all live in
**infra VLAN 1**, so unlock is within-zone and gets *more* resilient as you add
fleet hosts — segmentation doesn't touch it. Rule: keep every headless-unlock
host in the same zone as at least one Tang server it's bound to. If a Tang
server ever sits in another VLAN, infra must allow `tcp/7654` to it
(infra↔trusted is already open in the matrix).

> Note: the current JWE binds only 3 of the Tang servers (`.5`/`.21`/`.12`),
> while 6 hosts run Tang. To fully realize "every device is a Tang server,"
> `generate-jwe.sh` should bind the inventory's full `tangServers` list and the
> JWEs be regenerated (ties into the parked clevis re-bind / rotation).

## Bench-provision → swap runbook

1. **Bench:** BPI-R4 on an isolated bench, laptop direct-connected to a LAN
   port. Firmware first-boot default stays `192.168.1.1/24` (bench-only address
   — laptop sits on `192.168.1.x`).
2. **RAM limit (both boards):** append `mem=2048M` to the kernel cmdline via
   the U-Boot environment (serial console at the bench). MT7988 hardware
   flow-offloading drops/blocks packets when the full 4 GiB is addressed —
   upstream-confirmed, unresolved; 2 GiB is the known-good state. Optional
   later experiment: ap-upstairs (no NAT/PPE role, WED off) back to 4 GiB for
   more LXC headroom — bench-soak first.
3. **Provision:** `just provision` (or `just config::configure core-gateway`). The
   network role builds the VLANs, firewall zones, per-VLAN DHCP, and Wi-Fi from
   the vars in `openwrt-config/ansible/group_vars/all.yml`. Applying it moves the
   router's management IP to `10.0.0.1` and drops the bench SSH session
   (expected — reconnect at `10.0.0.1` on an untagged infra port).
4. **Verify offline:** SSH at `10.0.0.1`; a client on each VLAN pulls a lease in
   the right subnet; Wi-Fi SSIDs up; `iot`/`guest` can reach the internet but not
   `trusted`; AdGuard resolves from every VLAN.
5. **Cut over (maintenance window):** power down the current router, move its WAN
   uplink + LAN trunk to the BPI-R4. It boots as `10.0.0.1`; devices renew leases
   into their VLANs and come back online.
6. **Post-swap:** point the inventory at `10.0.0.1` (it lists the bench address
   until now — see `../nix/nix-config/inventory.nix`, the generator source).

## Open items — status

All six pinned; the VLAN/switch config is authored as `roles/network`
(gated on `vlan_segmentation_live` in group_vars). One bench verification
remains: confirm the DSA port names (`lan1…`, `sfp2`) on the flashed board
(`ls /sys/class/net`) match `port_maps` in group_vars.

1. ~~**Port → zone map**~~ **Resolved 2026-07-17** — gateway + AP identical:
   lan1 = infra untagged (fleet/management), lan2 = trusted untagged,
   lan3 = cameras untagged (wired cams); SFP+ (`sfp2`) = tagged trunk
   carrying all VLANs between the two BPI-R4s. Map lives in
   `openwrt-config/ansible/group_vars/all.yml` (`port_maps`).
2. ~~**SSID → VLAN map + names**~~ **Resolved** — built as `roles/wifi`
   (spec locked 2026-07): main SSID keeps its current name+password
   (trusted, all bands), `<ssid>-IoT`→iot (2.4+5), `<ssid>-Cam`→cameras
   (2.4+5), `<ssid>-Guest`→guest (2.4+5, isolated). WPA3 `sae-mixed` (pure SAE on
   6 GHz), 802.11r + DAWN. Map lives in
   `openwrt-config/ansible/group_vars/all.yml` (`wifi_networks`); SSID base +
   passphrases in openwrt-secrets. `roles/network` is live
   (`vlan_segmentation_live: true`) — SSIDs attach to their VLANs.
3. ~~**Wi-Fi regulatory country code**~~ **Resolved** — `IE` (`wifi_country`).
4. ~~**Camera VLAN**~~ **Resolved 2026-07-08** — kept; Frigate on orin-nano
   (infra) pulls RTSP via the infra→cameras allow. Wired cams on lan3,
   Wi-Fi cams on the `-Cam` SSID.
5. ~~**WAN uplink**~~ **Resolved 2026-07-17** — `eth1` (matches
   `uci-defaults` + inventory `wan_iface`); not an SFP port.
6. ~~**Preserve list**~~ **Resolved 2026-07-17** — nothing beyond the fleet's
   static leases (already in openwrt-secrets ansible-vars); no port-forwards
   or custom DNS entries carry over.
