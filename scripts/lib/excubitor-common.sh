#!/usr/bin/env bash
#
# excubitor-common.sh - shared state and helpers for excubitor (user
# commands) and domestikos (admin commands). Not meant to be run
# directly -- it is sourced by both.

LOCK_DIR="/var/lock/excubitor"
NUM_GPUS_TOTAL="${EXCUBITOR_GPU_TOTAL:-4}"

lock_file() { echo "${LOCK_DIR}/gpu${1}.lock"; }
meta_file() { echo "${LOCK_DIR}/gpu${1}.meta"; }

gpu_ids() {
    seq 0 $((NUM_GPUS_TOTAL - 1))
}

is_locked() {
    local gpu="$1"
    local lf; lf="$(lock_file "$gpu")"
    # try a non-blocking exclusive probe: if we can grab it, it was free
    if command -v flock >/dev/null; then
        exec {fd}>"$lf" 2>/dev/null || return 1
        if flock -n -x "$fd"; then
            flock -u "$fd"
            exec {fd}>&-
            return 1   # not locked
        else
            exec {fd}>&-
            return 0   # locked
        fi
    fi
}

# Best-effort: a regular user can only remove meta files they own, since
# LOCK_DIR is sticky (1777). Removing another user's stale meta requires
# `domestikos gc` running as root.
clear_meta() {
    local gpu="$1"
    rm -f "$(meta_file "$gpu")" 2>/dev/null || true
}

status() {
    printf "%-6s %-8s %-12s %-8s %-20s %s\n" "GPU" "STATE" "USER" "PID" "SINCE" "CMD"
    for gpu in $(gpu_ids); do
        local mf; mf="$(meta_file "$gpu")"
        if is_locked "$gpu"; then
            if [[ -f "$mf" ]]; then
                local luser lpid lsince lcmd
                luser=$(cut -d'|' -f1 "$mf")
                lpid=$(cut -d'|' -f2 "$mf")
                lsince=$(cut -d'|' -f3 "$mf")
                lcmd=$(cut -d'|' -f4- "$mf")
                if kill -0 "$lpid" 2>/dev/null; then
                    printf "%-6s %-8s %-12s %-8s %-20s %s\n" "$gpu" "BUSY" "$luser" "$lpid" "$lsince" "$lcmd"
                else
                    printf "%-6s %-8s %-12s %-8s %-20s %s\n" "$gpu" "STALE" "$luser" "$lpid" "$lsince" "(process gone)"
                fi
            else
                printf "%-6s %-8s %-12s %-8s %-20s %s\n" "$gpu" "BUSY" "?" "?" "?" "?"
            fi
        else
            printf "%-6s %-8s\n" "$gpu" "free"
        fi
    done
}

require_lock_dir() {
    if [[ ! -d "$LOCK_DIR" ]]; then
        echo "ERROR: ${LOCK_DIR} does not exist -- ask an admin to run 'domestikos init'" >&2
        exit 1
    fi
}
