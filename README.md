# OpenWrt Meta-Workspace

Entry point and conductor for the federated OpenWrt router infrastructure — a **tooling-only orchestrator** (no `flake.nix` here), mirroring the `../nix` meta-workspace. Sub-repos are standalone git+jj repos listed in `repos.nix` (not submodules).

## 📂 Structure

- **`openwrt-builder`**: Custom OpenWrt firmware image generation using the ImageBuilder (pinned release, profile: `bpi-r4`).
- **`openwrt-config`**: Declarative runtime configuration of OpenWrt routers via Ansible.
- **`openwrt-secrets`**: SOPS/Age encrypted secrets orchestration and host decryption mechanisms.
- **`docs`**: System ground truth, network maps, and hardware specifications.

## 🚀 Getting Started

1. **Bootstrap** (fresh machine):
   ```bash
   just jj::bootstrap   # Clone all sub-repos from repos.nix + init jj
   ```

2. **Enter the Workspace**:
   ```bash
   direnv allow                              # Recommended
   nix develop ../nix/nix-devshells#openwrt  # Pure fallback
   ```
   The shell comes from the shared `nix-devshells` repo and loads `just`, `ansible`, `ansible-lint`, `sops`, `age`, `gum`, `fzf`, and friends.

3. **Explore the Workspace Hub**:
   ```bash
   just
   ```
   *(fzf-based interactive hub for builds, provisioning, VCS, and maintenance.)*

4. **Build Firmware**:
   ```bash
   just build bpi-r4
   ```
   *(Containerized ImageBuilder run pinned to an exact OpenWrt release + sha256; images land in `./dist`.)*

5. **Provision Routers**:
   ```bash
   just provision
   ```
   *(Executes Ansible playbooks against the inventory generated from `../nix/nix-config/inventory.nix`.)*

## 🛠 Maintenance

- **Validate offline**: `just check-all` (linters + ansible syntax; never touches the routers)
- **Status**: `just status-all` (jj dashboard across all repos)
- **Pull / Push / Ship**: `just jj::pull-all` · `just jj::push-all` · `just jj::ship "msg"`
- **Verify live**: `just verify` (Ansible check mode against the routers)
- **Cleaning**: `just maintenance::clean-all`

## 🌐 Hardware Baseline

- **Model**: Banana Pi BPI-R4 (Filogic 880)
- **Architecture**: aarch64_cortex-a53 / MediaTek MT7988A
- **Network**: Wi-Fi 7 Tri-band, 10G SFP+, 2.5G Switch
- **Firmware**: OpenWrt 25.12.x (pinned in `openwrt-builder/profiles/bpi-r4.conf`)
