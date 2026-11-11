#!/usr/bin/env bash
# Fresh-machine entry point: run this before any `just`.
# .just/common.just and .just/jj.just are symlinks into ../kleinbem/, and a
# missing import fails the whole justfile, so `just` can't parse until kleinbem/
# is cloned. repos.nix lives inside kleinbem/, hence the hardcoded URL below.
# Not shared with nix/tools/bootstrap.sh: it must work before any shared file exists.
set -euo pipefail

# Two levels up from tools/: past openwrt/ itself, to the true workspace
# root where kleinbem/ is a sibling (matches {{ROOT}} in the shared justfiles).
# A jj workspace (openwrt.ws/<name>/) sits one level deeper. common.just walks
# up to kleinbem/repos.nix instead, which can't work before kleinbem/ is cloned.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_DIR="$SCRIPT_DIR/.."
if [[ "$(basename "$ROOT")" == openwrt.ws ]]; then
    ROOT="$(dirname "$ROOT")"
    # A workspace's .just symlinks point at openwrt.ws/kleinbem, which doesn't
    # exist, so run the shared bootstrap from the primary checkout.
    REPO_DIR="$ROOT/openwrt"
fi

if [ ! -d "$ROOT/kleinbem" ]; then
    echo "🌱 kleinbem/ missing — cloning it first (everything else depends on it)..."
    git clone git@github.com:kleinbem/kleinbem.git "$ROOT/kleinbem"
    (cd "$ROOT/kleinbem" && jj git init --colocate && jj bookmark track main --remote=origin)
else
    echo "✓ kleinbem/ already present."
fi

echo "▶ Continuing with the normal bootstrap (just jj::bootstrap)..."
cd "$REPO_DIR"
exec just jj::bootstrap "$@"
