# Workflow: Verify OpenWrt Configuration

Use this workflow to ensure that the current configuration is valid and the router is reachable.

## Steps

1. **Check workspace status**
   - Run `just jj::status-all` to ensure no uncommitted changes are blocking you.

2. **Verify Offline**
   - Run `just check-all` (linters + ansible syntax; never touches the routers).

3. **Check Connectivity**
   - Run `just config::ping` (or ping the management IPs in `docs/SYSTEM_REFERENCE.md`).

4. **Verify Live (check mode)**
   - Run `just verify` — Ansible `--check --diff` against the live routers.

5. **Review Secrets**
   - Ensure all necessary secrets are accessible via `sops` (YubiKey present).
