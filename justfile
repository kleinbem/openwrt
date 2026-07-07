# OpenWrt Meta-Workspace Justfile
import '.just/common.just'

# --- Modules ---
mod jj '.just/jj.just'
mod maintenance '.just/maintenance.just'
mod builder '.just/builder.just'
mod config '.just/config.just'
mod secrets '.just/secrets.just'

[group("Main")]
default:
    @just hub

[group("Main")]
build *args:
    @just builder::build {{args}}

[group("Main")]
provision *args:
    @just config::provision {{args}}

# Check-mode run against the live routers (needs SSH reachability).
[group("Main")]
verify:
    @just config::verify

# Offline validation: linters + ansible syntax + justfile parse.
[group("Main")]
check-all:
    @just maintenance::check-all

[group("Main")]
status-all:
    @just jj::status-all

[group("Main")]
ship *args="":
    @just jj::ship {{args}}

# Pass-through to any sub-repo's justfile from the meta root.
# Usage: just in openwrt-config check router-a
[group("Main")]
in repo *args:
    @cd {{repo}} && just {{args}}

# --- Workspace Hub (Premium Interactive Menu) ---

[group("Main")]
hub:
    #!/usr/bin/env bash
    set -e
    # Categorize recipes with icons for a premium feel
    LIST=$(just --summary | tr ' ' '\n' | sort | awk '{
        icon="🛠️";
        if ($1 ~ /^builder::/) icon="🏗️";
        else if ($1 ~ /^config::/) icon="⚙️";
        else if ($1 ~ /^secrets::/) icon="🔐";
        else if ($1 ~ /^jj::/) icon="🔄";
        else if ($1 ~ /^maintenance::/) icon="🧹";
        else if ($1 ~ /^(status|build|provision|verify|check|ship)/) icon="🌐";
        print icon " " $1
    }')

    SELECTED=$(echo "$LIST" | fzf \
        --header "🌐 OpenWrt Hub | [Enter] Run | [Ctrl-E] Edit | [Ctrl-H] Help" \
        --height 25 --reverse --ansi --info=inline --border --margin=1,2 --padding=1 \
        --preview "just --show {2}" --preview-window "right:60%:wrap" \
        --prompt "🔍 Search: " --pointer "➜" --marker "✓" \
        --color "header:italic:cyan,info:blue,prompt:yellow,pointer:red" \
        --bind "ctrl-e:execute($EDITOR justfile --line \$(grep -n \"^{2}:\" justfile | cut -d: -f1))+abort" \
        --bind "ctrl-h:execute(just --list {2} | less)+reload(echo \"$LIST\")"
    )

    [ -n "$SELECTED" ] && just $(echo "$SELECTED" | awk '{print $2}')
