import 'common.just'

set working-directory := ".."

# Workspace convention: recipes that fan out over all sub-repos end in `-all`.
# VCS operations (status/pull/push/save) live under jj:: — see .just/jj.just.

# Offline validation sweep: linters + ansible syntax + justfile parse.
# Does NOT touch the routers (that's `just config::verify`, check mode).
[group('Maintenance')]
check-all: lint-all
    #!/usr/bin/env bash
    set -e
    echo "🎭 Ansible playbook syntax..."
    (cd openwrt-config && ansible-playbook -i ansible/inventory.ini ansible/site.yml --syntax-check)
    echo "📜 Justfile parse (meta + sub-repos)..."
    just --list >/dev/null
    for repo in {{REPOS}}; do
        if [ -f "$repo/Justfile" ] || [ -f "$repo/justfile" ]; then
            (cd "$repo" && just --list >/dev/null) && echo "  ✓ $repo"
        fi
    done
    echo "✅ check-all passed."

# Lint every repo: shellcheck on tracked shell scripts, yamllint +
# ansible-lint on the config repo, nixfmt on meta nix files.
[group('Maintenance')]
lint-all:
    #!/usr/bin/env bash
    set -e
    echo "🐚 shellcheck..."
    for repo in {{REPOS}} .; do
        files=$(git -C "$repo" ls-files '*.sh' 2>/dev/null)
        [ -z "$files" ] && continue
        (cd "$repo" && shellcheck $files) && echo "  ✓ $repo"
    done
    echo "📐 yamllint (openwrt-config)..."
    yamllint -c openwrt-config/.yamllint openwrt-config/ansible
    echo "🎭 ansible-lint (openwrt-config)..."
    (cd openwrt-config && ansible-lint ansible/site.yml)
    echo "❄️  nixfmt..."
    nixfmt --check repos.nix
    echo "✅ lint-all passed."

# Format what we can format (nix files; linters above are check-only).
[group('Maintenance')]
format-all:
    nixfmt repos.nix
    @echo "✅ format-all done."

# Regenerate ansible inventory from the master source of truth
# (nix-config/inventory.nix in the sibling nix workspace).
[group('Maintenance')]
sync-inventory:
    @echo "🔄 Syncing Ansible inventory from Nix source of truth..."
    ../nix/nix-config/scripts/gen-ansible-inventory.sh > openwrt-config/ansible/inventory.ini
    @echo "✅ inventory.ini updated."

# Remove build artifacts everywhere and repack git repos.
[group('Maintenance')]
clean-all:
    #!/usr/bin/env bash
    set -e
    echo "🧹 Cleaning artifacts..."
    rm -rf result dist bin
    (cd openwrt-builder && just clean) || true
    for repo in {{REPOS}} .; do
        echo "  🗜  git gc: $repo"
        git -C "$repo" gc --quiet || true
    done
    echo "✅ clean-all done."

# Show who holds the workspace lock (if anyone).
[group('Maintenance')]
who:
    @fuser -v {{LOCK_FILE}} 2>&1 || echo "🔓 No one holds the workspace lock."
