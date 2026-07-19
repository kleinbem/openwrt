# Observability + AI-assisted network analysis — design (2026-07-19)

Draft plan tying together monitoring, the SSDs, and the fleet's AI (Orin Nano
local + Claude/Gemini subscriptions). **Nothing here is built yet** — it needs
your review because most of it lands on the fleet (nix-config), which
auto-deploys. The OpenWrt side already emits everything this needs.

## The data the routers already produce (done)
- **Metrics** → `prometheus-node-exporter-lua` (+ conntrack/thermal/load/wifi
  collectors), scraped by the fleet Prometheus (`nix-config` monitoring
  `nodeTargets` include core-gateway + ap-upstairs). Local RRD via collectd +
  `luci-app-statistics`; per-host bandwidth via `nlbwmon`.
- **Logs** → remote syslog (`roles/common`, set `remote_syslog_ip`), so router
  logs land in a fleet collector and survive reboots.
- **Security events** → banIP (edge blocks) + (future) CrowdSec, both to syslog.

## Where the SSDs fit
- **core-gateway NVMe** = storage: persistent local logs, banIP data, swap —
  keeps the RAM-constrained (2 GiB) routing box light while not losing history.
- **ap-upstairs NVMe** = compute: LXC host. This is the natural place to run a
  *local* lightweight collector/agent if you don't want everything centralised.

## The pipeline (proposed)
```
routers ──(prometheus)──▶ fleet Prometheus ──▶ Grafana dashboards
        └─(syslog)──────▶ fleet Loki/collector ─┐
banIP/CrowdSec ─────────────────────────────────┤
                                                 ▼
                              AI analysis (scheduled)
                     ┌── Orin Nano (Ollama) — routine/cheap/private:
                     │     summarise last 24h, flag obvious anomalies
                     └── Claude/Gemini — escalation for deep reasoning:
                           "explain this traffic spike / correlate these events"
                                                 ▼
                        Actions: ntfy alert (wired) · Grafana annotation ·
                        (opt) CrowdSec/banIP block · (opt) quarantine recipe
```

## Two-tier AI (matches your fragility-averse, €0 style)
- **Local first (Orin/Ollama):** runs on the fleet, no per-token cost, private,
  works offline. Handles the routine pass — "anything weird in the last hour?"
- **Cloud escalation (Claude/Gemini):** only when the local model flags
  something or you ask a hard question. Keeps cost near zero, privacy high.
- Ties into existing tooling: `workspace-atlas` MCP already has `analyze_logs`
  / `get_system_telemetry` / `check_ai_stack_health`; n8n can schedule/route.

## Concrete, safe first steps (when you want them)
1. **Fleet log sink** — stand up a syslog receiver (promtail→Loki, or rsyslog)
   on the fleet, then set `remote_syslog_ip` on the routers. Pure additive.
2. **Grafana dashboards** for the routers (they're already scraped) — a
   "network" board: throughput, conntrack, temp, Wi-Fi clients, banIP hits.
3. **Scheduled AI digest** — a nightly job (n8n or a systemd timer) that feeds
   the day's router logs+metrics to the Orin, posts a short digest to ntfy,
   and only pings Claude/Gemini when the local model raises a flag.
4. **Closed loop (later)** — AI flags a device → the quarantine recipe (see the
   "dynamic per-device control" notes) firewall-isolates it. Keep human-in-loop
   at first.

## Decisions needed from you
- Central vs. local: run the AI digest on the fleet (core-pi/nvme) or in the
  ap-upstairs LXC? (Central is simpler; local survives fleet issues.)
- Log sink: Loki (fits Grafana) vs. plain rsyslog files on an SSD.
- How autonomous: digest-only (safe) → alert → auto-act (quarantine/block).
- Privacy line: which logs may go to cloud AI vs. Orin-only.

---

# Control layer (2026-07-19)

Monitoring is only half of it — you also need to *act*. Two levers (see the
"dynamic per-device control" discussion):
- **Membership (L2, where a device lives)** — set by MPSK password; changing it
  needs a reconnect. Static classification, rarely touched.
- **Policy (L3, what a device may do)** — firewall/DNS, keyed on MAC/IP, applied
  to the live connection instantly. **This is where control lives.**

## Built now
- **Device quarantine** — `just quarantine MAC [name]` / `just release MAC` /
  `just quarantine-list` (openwrt-config). A gateway firewall DROP on the MAC,
  live, no VLAN move. The first real control primitive.
- **Per-service control surfaces** — LuCI (Material) with an app per service
  (banIP, DAWN, nlbwmon, SQM), the network hub landing page, and AdGuard's own
  UI (now local on the gateway) for per-client DNS policy.

## Roadmap (each a small, self-contained add)
- **Time-based policy** — nftables time-match / cron-toggled rules (bedtime,
  IoT curfew, guest-hours). Parental controls via AdGuard per-client + firewall.
- **Bandwidth caps** — per-VLAN/per-device via cake (SQM) or tc.
- **Closed loop** — monitoring detects (CrowdSec/banIP/anomaly) → control acts
  (quarantine/block). Human-in-loop first, then optionally automated via n8n.

## The full monitoring+control loop (the target)
```
  SEE                         DECIDE                    ACT
  ───                         ──────                    ───
  Prometheus (metrics) ─┐
  Loki (logs, via        ├─▶ Grafana dashboards ─┐
     remote-syslog)      │   Alertmanager rules  ├─▶ ntfy alert (human)
  banIP / CrowdSec ──────┘   AI digest (Orin/     │   just quarantine / block
  nlbwmon (per-device)       Claude/Gemini)       └─▶ n8n automation (auto)
```
Most of SEE emits already (router side done). DECIDE + ACT is where the next
value is: **Grafana "network" dashboard**, **router alert rules** (WAN down,
SoC temp, conntrack pressure, banIP spikes), and wiring **remote-syslog → Loki**
(needs a syslog receiver in front of Loki). These land on the fleet (nix-config,
deploys live) — additive and low-risk, but your call to build.

## Decisions needed (to build the fleet side)
- Grafana dashboard + alert rules: build now (additive) or review first?
- Log sink: promtail-with-syslog-receiver → Loki, vs rsyslog on an SSD.
- Automation autonomy: alert-only → one-click quarantine → AI auto-act.
