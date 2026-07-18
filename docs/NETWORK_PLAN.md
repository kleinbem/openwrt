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
| 50   | 10.0.50.0/24   | work     | WFH corporate laptop — internet only, isolated from the home LAN, **DNS not hijacked** (corporate VPN uses its own DNS). Reached via the MPSK SSID `16CVG-W3` with the work password. |

Room to grow: each is a `/24` (254 hosts) carved from `10.0.0.0/8`; bump any to
a `/16` (e.g. `10.20.0.0/16` for IoT) later without renumbering the others.

### Infra VLAN 1 fixed addresses (`10.0.0.0/24`)

The whole fleet is 10.x — no `192.168.x` remains. Network layer in `.1–.9`,
servers/fleet keep their established octets, DHCP pool is `.100–.199`.

| IP        | Host          | Role                                   |
|-----------|---------------|----------------------------------------|
| 10.0.0.1  | core-gateway  | BPI-R4 main gateway (downstairs)       |
| 10.0.0.2  | ap-upstairs   | BPI-R4 AP / LXC-capable (upstairs)     |
| 10.0.0.5  | nixos-nvme    | workstation + Tang (LUKS unlock anchor¹)|
| 10.0.0.3–.4, .6–.9 | *(free)* | network-layer range — next `ap-<location>` etc. (LXC "brain" containers dropped 2026-07-18: never deployed, tenants live on the fleet; ap-upstairs keeps the capability) |
| 10.0.0.12 | orin-nano     | AI edge + Tang                         |
| 10.0.0.21 | hass-pi       | Home Assistant + AdGuard + Tang        |
| 10.0.0.22 | core-pi       | cache entrypoint + Tang                |
| 10.0.0.30 | nasbook       | NAS + Tang                             |

¹ `.5` can't move — the clevis LUKS binding is anchored to nixos-nvme/Tang
  there. Source of truth: `../nix/nix-config/inventory.nix`.

> Bench bootstrap: the BPI-R4 firmware still first-boots at `192.168.1.1` (the
> ImageBuilder default). For the one-time bench provisioning, reach it there
> (`-e ansible_host=192.168.1.1`); the role then moves it to `10.0.0.1`, after
> which the inventory address is correct for all subsequent runs.

## Firewall zone matrix

| From → To | infra | trusted | iot | cameras | guest | work | wan |
|-----------|:-----:|:-------:|:---:|:-------:|:-----:|:----:|:---:|
| infra     |  —    |   ✓     |  ✓  |   ✓     |  ✗    |  ✗   |  ✓  |
| trusted   |  ✓    |   —     |  ✓  |   ✓     |  ✗    |  ✗   |  ✓  |
| iot       | DNS¹  |   ✗     |  —  |   ✗     |  ✗    |  ✗   |  ✓  |
| cameras   | DNS¹  |   ✗     |  ✗  |   —     |  ✗    |  ✗   |  ✗² |
| guest     | DNS¹  |   ✗     |  ✗  |   ✗     |  —    |  ✗   |  ✓  |
| work      |  ✗    |   ✗     |  ✗  |   ✗     |  ✗    |  —   |  ✓  |

The `dns` attribute on each VLAN (group_vars) drives DNS + input policy in
three tiers — the network role derives everything from it:

¹ **trusted tier** (infra, trusted — your devices): DHCP option 6 = AdGuard
  primary + the VLAN's own gateway IP as *unfiltered* fallback, so the LAN
  keeps resolving if hass-pi is down. Zone input ACCEPT. No hijack.
- **filtered tier** (iot, cameras, guest — untrusted): AdGuard only + a **DNS
  hijack** (DNAT every :53 → AdGuard `10.0.0.21`) so hardcoded-resolver gear
  can't bypass filtering. Trade-off: AdGuard down = degraded DNS (accepted).
- **local tier** (work — WFH corporate laptop): the router's own *unfiltered*
  dnsmasq only, **no hijack**, so her employer's VPN/DNS is respected. Fully
  isolated from the home LAN (internet only); reaches nothing in infra.
² cameras get **no WAN** (no phone-home); a trusted host or NVR pulls streams.

**Native router services (all OpenWrt-native, 2026-07-18):**
- **NTP server** on the gateway (`sysntpd enable_server`) — cameras have no
  WAN, so the router is their clock; restricted zones get an input allow on
  udp/123. IoT TLS also depends on correct time.
- **mDNS reflector** (avahi, gateway) — bridges service discovery
  **trusted↔iot only** (phones find Chromecast/HomeKit/printers across the
  VLAN edge); guest/cameras excluded. iot gets an input allow on udp/5353.
- **Management plane = infra only** — SSH/HTTP/HTTPS rejected from trusted
  (which keeps DNS/DHCP/NTP); iot/cameras/guest already blocked by zone
  policy. Admin from infra, where the workstation lives.

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
2. ~~**SSID → VLAN map + names**~~ **Resolved** — built as `roles/wifi`.
   Migration-safe layout (2026-07-18), **4 SSIDs** (→ 3 after `16CVG` retires).
   Because the PASSWORD picks the VLAN (not the SSID), the two MPSK SSIDs are
   just encryption tiers; a device joins whichever its radio likes and still
   lands in the right VLAN. Encryption strength matched to VLAN sensitivity:
   - `16CVG` → trusted (legacy/stable — existing devices, WPA3 single-PSK;
     the reliable WPA3 path for trusted, retire once migrated)
   - `16CVG-W3` → **MPSK, WPA3/sae-mixed.** Sensitive + modern: password
     picks trusted / work / iot / cameras. All bands.
   - `16CVG-W2` → **MPSK, WPA2/psk2.** Compatibility tier for cheap gear
     that chokes on WPA3 beacons. Carries **only low-trust VLANs (iot,
     cameras)** — never trusted/work, so its crackable WPA2 only ever exposes
     isolated VLANs. 2.4+5 GHz (no 6 GHz — that's WPA3-only).
   - `16CVG-Guest` → guest (plain, easy to hand a visitor; client-isolated)
   IoT/camera devices don't exist yet, so they're born on MPSK (no dedicated
   `-IoT`/`-Cam` SSIDs); onboard one at a time. DAWN steering; 802.11r on the
   discrete SSIDs (off on MPSK until proven). Map in `group_vars` (`wifi_networks`),
   passphrases in openwrt-secrets. `roles/network` live.
   **End state:** migrate onto `-W3`/`-W2`, then drop `16CVG` (3 SSIDs).
   ⚠️ **Bench-validate:** (a) 25.12 ucode `wpa_psk_file` dynamic-VLAN
   regression (#20355); (b) whether WPA3-SAE clients on `-W3` actually get a
   VLAN — `wpa_psk_file` is the WPA2 mechanism, so SAE clients may need
   `sae_password`+`vlanid` (else those devices ride `16CVG`/`-W2`). `16CVG` is
   the reliable WPA3 fallback for trusted throughout.
3. ~~**Wi-Fi regulatory country code**~~ **Resolved** — `IE` (`wifi_country`).
4. ~~**Camera VLAN**~~ **Resolved 2026-07-08** — kept; Frigate on orin-nano
   (infra) pulls RTSP via the infra→cameras allow. Wired cams on lan3,
   Wi-Fi cams on the `-Cam` SSID.
5. ~~**WAN uplink**~~ **Resolved 2026-07-17** — `eth1` (matches
   `uci-defaults` + inventory `wan_iface`); not an SFP port.
6. ~~**Preserve list**~~ **Resolved 2026-07-17** — nothing beyond the fleet's
   static leases (already in openwrt-secrets ansible-vars); no port-forwards
   or custom DNS entries carry over.
