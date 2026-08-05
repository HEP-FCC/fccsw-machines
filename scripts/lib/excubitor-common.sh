#!/usr/bin/env bash
#
# excubitor-common.sh - shared state and helpers for excubitor (user
# commands) and domestikos (admin commands). Not meant to be run
# directly -- it is sourced by both.

LOCK_DIR="/var/lock/excubitor"

# Shared by excubitor and domestikos -- both live in this repo and are
# always installed/updated together (see scripts/Makefile), so one
# version number for the pair is enough. Bump by hand on notable changes.
EXCUBITOR_VERSION="0.1.1"

# Always detect the real GPU count so the same install works unmodified
# across hosts with different GPU counts (e.g. 4x A100 vs. Tesla T4
# boxes). Deliberately not overridable by an unprivileged excubitor
# invocation -- how many GPUs a node has is a fact about the node, not
# something a regular user's own environment should be able to
# misrepresent. 0 here means "unknown/none detected"; require_gpu_count
# below is what turns that into a hard error for the commands that need
# it, rather than silently pretending a plausible-sounding count.
if command -v nvidia-smi >/dev/null 2>&1; then
    NUM_GPUS_TOTAL="$(nvidia-smi -L 2>/dev/null | wc -l)"
else
    NUM_GPUS_TOTAL=0
fi

lock_file() { echo "${LOCK_DIR}/gpu${1}.lock"; }
meta_file() { echo "${LOCK_DIR}/gpu${1}.meta"; }

# Open $1 as fd variable `fd` (bash's {fd}-allocation, not a nameref --
# callers read it back via the plain $fd variable this sets in their own
# scope). Must be called directly (never via `$(...)` or in a pipeline)
# when the caller needs the fd to survive beyond this call, same
# constraint as acquire_n() below.
#
# Lock files are shared across whichever user happens to touch a given
# GPU index first, so their permissions can't depend on that user's
# umask -- force world-writable (LOCK_DIR is already 1777, so this
# doesn't widen who can get *at* the file, only who can write it once
# it's their turn to create it).
open_lock_fd() {
    local lf="$1"
    local old_umask; old_umask="$(umask)"
    umask 000
    exec {fd}>"$lf"
    local rc=$?
    umask "$old_umask"
    return "$rc"
}

gpu_ids() {
    seq 0 $((NUM_GPUS_TOTAL - 1))
}

is_locked() {
    local gpu="$1"
    local lf; lf="$(lock_file "$gpu")"
    command -v flock >/dev/null || return 1
    # Run the whole probe in a subshell: a bare `exec {fd}>... 2>/dev/null`
    # modifies the CURRENT shell's fd table persistently (not just this
    # line), which would silently redirect the rest of the caller's
    # stderr to /dev/null for the remainder of the process. Scoping it to
    # a subshell confines that entirely to the subshell, which exits
    # immediately after.
    (
        open_lock_fd "$lf" || exit 1
        if flock -n -x "$fd"; then
            exit 1   # got the lock -> it was NOT locked
        else
            exit 0   # could not get it -> it IS locked
        fi
    ) 2>/dev/null
}

# Best-effort: a regular user can only remove meta files they own, since
# LOCK_DIR is sticky (1777). Removing another user's stale meta requires
# `domestikos gc` running as root.
clear_meta() {
    local gpu="$1"
    rm -f "$(meta_file "$gpu")" 2>/dev/null || true
}

# PIDs of compute processes the driver sees on $1, regardless of whether
# they went through excubitor at all -- this is how we catch a bypass.
# Always exits 0 (empty output = none found/unknown): under `set -e`, a
# plain `var=$(...)` assignment inherits the command's exit status and
# aborts the whole script if it's non-zero, so callers must be able to
# trust this never fails even when nvidia-smi is missing or errors.
untracked_pids() {
    local gpu="$1"
    command -v nvidia-smi >/dev/null 2>&1 || return 0
    nvidia-smi -i "$gpu" --query-compute-apps=pid --format=csv,noheader 2>/dev/null | paste -sd, - || true
}

# Owning user for a single pid, "?" if it can't be resolved (e.g. the
# process already exited between the nvidia-smi query and this lookup).
# Always exits 0, for the same reason as untracked_pids above.
pid_owner() {
    local pid="$1" u
    u="$(ps -o user= -p "$pid" 2>/dev/null | tr -d '[:space:]')" || true
    echo "${u:-?}"
}

# $1: comma-separated pid list -> comma-separated owners, same order.
untracked_owners() {
    local pids="$1" pid_arr owners=() pid
    IFS=',' read -ra pid_arr <<< "$pids"
    for pid in "${pid_arr[@]}"; do
        owners+=("$(pid_owner "$pid")")
    done
    local IFS=','
    echo "${owners[*]}"
}

status() {
    printf "%-6s %-10s %-12s %-8s %-20s %s\n" "GPU" "STATE" "USER" "PID" "SINCE" "CMD"
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
                    printf "%-6s %-10s %-12s %-8s %-20s %s\n" "$gpu" "BUSY" "$luser" "$lpid" "$lsince" "$lcmd"
                else
                    printf "%-6s %-10s %-12s %-8s %-20s %s\n" "$gpu" "STALE" "$luser" "$lpid" "$lsince" "(process gone)"
                fi
            else
                printf "%-6s %-10s %-12s %-8s %-20s %s\n" "$gpu" "BUSY" "?" "?" "?" "?"
            fi
        else
            # free per our own lock bookkeeping -- but that only reflects
            # jobs that went through `excubitor run` in the first place,
            # so cross-check against what the driver actually sees.
            local bypass_pids; bypass_pids="$(untracked_pids "$gpu")" || true
            if [[ -n "$bypass_pids" ]]; then
                local bypass_users; bypass_users="$(untracked_owners "$bypass_pids")" || true
                printf "%-6s %-10s %-12s %-8s %-20s %s\n" "$gpu" "UNTRACKED" "$bypass_users" "$bypass_pids" "?" "(bypassed excubitor -- driver shows active process(es))"
            else
                printf "%-6s %-10s\n" "$gpu" "free"
            fi
        fi
    done
}

require_lock_dir() {
    if [[ ! -d "$LOCK_DIR" ]]; then
        echo "ERROR: ${LOCK_DIR} does not exist -- contact the administrators on Mattermost, \"FCC SW Machines\": https://mattermost.web.cern.ch/fccsw/channels/fccsw-machines" >&2
        exit 1
    fi
}

# Must be called directly, never via `$(...)` -- that would fork a
# subshell and the `exit` below would only ever terminate the subshell,
# silently letting the caller carry on as if nothing were wrong.
require_gpu_count() {
    if [[ "$NUM_GPUS_TOTAL" -eq 0 ]]; then
        echo "ERROR: no GPUs detected on this node -- is nvidia-smi installed and working?" >&2
        exit 1
    fi
}
