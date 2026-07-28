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
    (cd {{ROOT}}/openwrt-config && ansible-playbook -i ansible/inventory.ini ansible/site.yml --syntax-check)
    echo "📜 Justfile parse (meta + sub-repos)..."
    just --list >/dev/null
    for repo in {{REPOS}} .; do
        rpath=$([ "$repo" = "." ] && echo "{{ROOT}}/openwrt" || echo "{{ROOT}}/$repo")
        if [ -f "$rpath/Justfile" ] || [ -f "$rpath/justfile" ]; then
            (cd "$rpath" && just --list >/dev/null) && echo "  ✓ $repo"
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
        rpath=$([ "$repo" = "." ] && echo "{{ROOT}}/openwrt" || echo "{{ROOT}}/$repo")
        files=$(git -C "$rpath" ls-files '*.sh' 2>/dev/null)
        [ -z "$files" ] && continue
        (cd "$rpath" && shellcheck $files) && echo "  ✓ $repo"
    done
    echo "📐 yamllint (openwrt-config)..."
    yamllint -c {{ROOT}}/openwrt-config/.yamllint {{ROOT}}/openwrt-config/ansible
    echo "🎭 ansible-lint (openwrt-config)..."
    (cd {{ROOT}}/openwrt-config && ansible-lint ansible/site.yml)
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
    @if [ -f {{ROOT}}/nix-config/scripts/gen-ansible-inventory.sh ]; then {{ROOT}}/nix-config/scripts/gen-ansible-inventory.sh > {{ROOT}}/openwrt-config/ansible/inventory.ini; else {{ROOT}}/nix/nix-config/scripts/gen-ansible-inventory.sh > {{ROOT}}/openwrt-config/ansible/inventory.ini; fi
    @echo "✅ inventory.ini updated."

# Remove build artifacts everywhere and repack git repos.
[group('Maintenance')]
clean-all:
    #!/usr/bin/env bash
    set -e
    echo "🧹 Cleaning artifacts..."
    rm -rf result dist bin
    (cd {{ROOT}}/openwrt-builder && just clean) || true
    for repo in {{REPOS}} .; do
        rpath=$([ "$repo" = "." ] && echo "{{ROOT}}/openwrt" || echo "{{ROOT}}/$repo")
        echo "  🗜  git gc: $repo"
        git -C "$rpath" gc --quiet || true
    done
    echo "✅ clean-all done."

# Show who holds the workspace lock (if anyone).
[group('Maintenance')]
who:
    @fuser -v {{LOCK_FILE}} 2>&1 || echo "🔓 No one holds the workspace lock."
