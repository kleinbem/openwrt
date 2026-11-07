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
    (cd "{{ROOT}}/openwrt-config" && ansible-playbook -i ansible/inventory.ini ansible/site.yml --syntax-check)
    echo "📜 Justfile parse (meta + sub-repos)..."
    just --list >/dev/null
    for repo in {{REPOS}}; do
        rpath="{{ROOT}}/$repo"
        if [ -f "$rpath/Justfile" ] || [ -f "$rpath/justfile" ]; then
            # `|| exit` because set -e ignores a failure on the left of `&&`.
            (cd "$rpath" && just --list >/dev/null) || exit 1
            echo "  ✓ $repo"
        fi
    done
    echo "✅ check-all passed."

# Lint every repo in scope: shellcheck on tracked shell scripts, plus
# yamllint + ansible-lint on the config repo.
[group('Maintenance')]
lint-all:
    #!/usr/bin/env bash
    set -e
    echo "🐚 shellcheck..."
    list=$(mktemp)
    trap 'rm -f "$list"' EXIT
    for repo in {{REPOS}}; do
        rpath="{{ROOT}}/$repo"
        [ -d "$rpath" ] || continue # not cloned here
        git -C "$rpath" ls-files -z '*.sh' >"$list" || exit 1
        mapfile -d '' files <"$list"
        [ "${#files[@]}" -eq 0 ] && continue
        # -x -P SCRIPTDIR: follow sourced helpers next to each script.
        (cd "$rpath" && shellcheck -x -P SCRIPTDIR "${files[@]}") || exit 1
        echo "  ✓ $repo"
    done
    echo "📐 yamllint (openwrt-config)..."
    yamllint -c "{{ROOT}}/openwrt-config/.yamllint" "{{ROOT}}/openwrt-config/ansible"
    echo "🎭 ansible-lint (openwrt-config)..."
    (cd "{{ROOT}}/openwrt-config" && ansible-lint ansible/site.yml)
    echo "✅ lint-all passed."

# Nothing to format locally — openwrt/ owns no .nix files (repos.nix moved to
# kleinbem/, formatted as part of the fleet-wide manifest there) and the
# per-repo shell/yaml/ansible linters above are check-only.
[group('Maintenance')]
format-all:
    @echo "✅ format-all done (nothing to format in openwrt/ itself)."

# Regenerate ansible inventory from the master source of truth
# (nix-config/inventory.nix). Written to a temp file first, so a failed
# generator leaves the old inventory.ini in place.
[group('Maintenance')]
sync-inventory:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Syncing Ansible inventory from Nix source of truth..."
    out="{{ROOT}}/openwrt-config/ansible/inventory.ini"
    tmp=$(mktemp "$out.XXXXXX")
    trap 'rm -f "$tmp"' EXIT
    "{{ROOT}}/nix-config/scripts/gen-ansible-inventory.sh" > "$tmp"
    mv "$tmp" "$out"
    echo "✅ inventory.ini updated."

# Remove build artifacts here and in openwrt-builder, and repack every repo.
[group('Maintenance')]
clean-all:
    #!/usr/bin/env bash
    set -e
    echo "🧹 Cleaning artifacts..."
    rm -rf result dist bin
    (cd "{{ROOT}}/openwrt-builder" && just clean) || true
    for repo in {{REPOS}}; do
        rpath="{{ROOT}}/$repo"
        echo "  🗜  git gc: $repo"
        git -C "$rpath" gc --quiet || true
    done
    echo "✅ clean-all done."

# Show who holds the workspace lock (if anyone).
[group('Maintenance')]
who:
    @fuser -v {{LOCK_FILE}} 2>&1 || echo "🔓 No one holds the workspace lock."
