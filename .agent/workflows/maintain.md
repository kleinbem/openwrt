# Workflow: Maintain OpenWrt Workspace

Use this workflow to keep the meta-repo and its components up to date.

## Steps

1. **Sync All Repositories**
   - Run `just jj::pull-all`.

2. **Verify Integrity**
   - Run `just check-all` (offline: linters + ansible syntax + justfile parse).

3. **Bump Firmware Source** (when a new OpenWrt release is out)
   - Update `BUILDER_URL` + `BUILDER_SHA256` in `openwrt-builder/profiles/bpi-r4.conf`
     (checksum from the release target's `sha256sums` file).
   - Rebuild with `just build bpi-r4`.

4. **Commit Changes**
   - Run `just jj::ship "chore: ..."` (describe + sign + push).
