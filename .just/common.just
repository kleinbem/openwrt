# --- Shared Variables ---

# Get the absolute path to the project root (parent of this justfile)
ROOT := parent_directory(justfile())

# Identify openwrt-* repositories in the root (trimmed of any extra whitespace)
REPOS := shell("find " + ROOT + " -maxdepth 1 -name 'openwrt-*' -type d -printf '%f\n' | xargs echo -n")

TIMER := "time "
LOCK_FILE := "/tmp/openwrt-just.lock"
# Non-blocking lock command wrapper for better error messages
LOCK_CMD := "bash -c 'if ! flock -n 9; then echo \"❌ ERROR: Workspace locked by another process at " + LOCK_FILE + ".\"; exit 1; fi; \"$@\"' 9>>" + LOCK_FILE + " -- "
