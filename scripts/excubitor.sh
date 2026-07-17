#!/usr/bin/env bash
#
# excubitor.sh - simple cooperative lock manager for a shared multi-GPU node
#
# Locks are per-GPU-index, backed by flock on files under LOCK_DIR.
# This is COOPERATIVE only: it stops nothing at the kernel/driver level.
# It only works if everyone uses this wrapper instead of launching CUDA
# jobs directly. Pair with `nvidia-smi -c EXCLUSIVE_PROCESS` as a hard
# backstop so a forgotten lock causes a crash instead of silent corruption.
#
# Usage:
#   excubitor.sh status
#   excubitor.sh run -n <num_gpus> [-t <timeout_sec>] -- <command...>
#   excubitor.sh acquire -n <num_gpus> [-t <timeout_sec>]   # prints GPU ids, holds locks in subshell
#   excubitor.sh release <gpu_id> [<gpu_id> ...]
#
# Examples:
#   excubitor.sh run -n 1 -- python train.py
#   excubitor.sh run -n 2 -t 600 -- python train_multi.py
#   excubitor.sh status
#
set -euo pipefail

LOCK_DIR="/var/lock/excubitor"
NUM_GPUS_TOTAL="${EXCUBITOR_GPU_TOTAL:-4}"
DEFAULT_TIMEOUT=0   # 0 = wait forever

mkdir -p "$LOCK_DIR"
chmod 1777 "$LOCK_DIR"   # sticky, world-writable so any user can create/hold locks

# ---- helpers ---------------------------------------------------------

lock_file() { echo "${LOCK_DIR}/gpu${1}.lock"; }
meta_file() { echo "${LOCK_DIR}/gpu${1}.meta"; }

gpu_ids() {
    seq 0 $((NUM_GPUS_TOTAL - 1))
}

is_locked() {
    local gpu="$1"
    local lf; lf="$(lock_file "$gpu")"
    # try a non-blocking shared-then-exclusive probe via flock in a subshell
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

status() {
    printf "%-6s %-8s %-12s %-8s %-20s %s\n" "GPU" "STATE" "USER" "PID" "SINCE" "CMD"
    for gpu in $(gpu_ids); do
        local mf; mf="$(meta_file "$gpu")"
        if is_locked "$gpu"; then
            if [[ -f "$mf" ]]; then
                # shellcheck disable=SC1090
                local luser lpid lsince lcmd
                luser=$(cut -d'|' -f1 "$mf")
                lpid=$(cut -d'|' -f2 "$mf")
                lsince=$(cut -d'|' -f3 "$mf")
                lcmd=$(cut -d'|' -f4- "$mf")
                if kill -0 "$lpid" 2>/dev/null; then
                    printf "%-6s %-8s %-12s %-8s %-20s %s\n" "$gpu" "BUSY" "$luser" "$lpid" "$lsince" "$lcmd"
                else
                    printf "%-6s %-8s %-12s %-8s %-20s %s\n" "$gpu" "STALE" "$luser" "$lpid" "$lsince" "(process gone, will clear)"
                fi
            else
                printf "%-6s %-8s %-12s %-8s %-20s %s\n" "$gpu" "BUSY" "?" "?" "?" "?"
            fi
        else
            printf "%-6s %-8s\n" "$gpu" "free"
        fi
    done
}

# Try to acquire exactly $1 GPUs. MUST be called directly (never via
# command substitution / a pipeline) -- it must run in the caller's own
# shell process, not a subshell, because the held fds (and thus the
# flock locks) are released the instant the process holding them exits.
# On success, leaves the held gpu ids/fds in the global HELD_GPUS/HELD_FDS
# arrays for the caller to hold for the lifetime of the process.
declare -a HELD_FDS=()
declare -a HELD_GPUS=()

acquire_n() {
    local n="$1"
    local timeout="$2"
    local deadline=0
    if [[ "$timeout" -gt 0 ]]; then
        deadline=$(( $(date +%s) + timeout ))
    fi

    while true; do
        HELD_FDS=()
        HELD_GPUS=()
        for gpu in $(gpu_ids); do
            local lf; lf="$(lock_file "$gpu")"
            exec {fd}>"$lf"
            if flock -n -x "$fd"; then
                HELD_FDS+=("$fd")
                HELD_GPUS+=("$gpu")
                if [[ "${#HELD_GPUS[@]}" -eq "$n" ]]; then
                    return 0
                fi
            else
                exec {fd}>&-
            fi
        done

        # not enough free GPUs right now: release what we grabbed, wait, retry
        for fd in "${HELD_FDS[@]}"; do
            flock -u "$fd"
            exec {fd}>&-
        done
        HELD_FDS=()
        HELD_GPUS=()

        if [[ "$timeout" -gt 0 && "$(date +%s)" -ge "$deadline" ]]; then
            echo "ERROR: timed out waiting for ${n} free GPU(s)" >&2
            return 1
        fi
        sleep 5
    done
}

write_meta() {
    local gpu="$1"; shift
    echo "${USER}|$$|$(date '+%Y-%m-%d %H:%M:%S')|$*" > "$(meta_file "$gpu")"
}

clear_meta() {
    local gpu="$1"
    rm -f "$(meta_file "$gpu")"
}

release_gpu_ids() {
    for gpu in "$@"; do
        local lf; lf="$(lock_file "$gpu")"
        exec {fd}>"$lf"
        if flock -n -x "$fd"; then
            # nobody held it -- nothing to release, but clean stale meta anyway
            clear_meta "$gpu"
            flock -u "$fd"
        else
            echo "WARN: GPU $gpu currently locked by another process; cannot force-release" >&2
        fi
        exec {fd}>&-
    done
}

cmd_run() {
    local n=1 timeout="$DEFAULT_TIMEOUT"
    while getopts "n:t:" opt; do
        case "$opt" in
            n) n="$OPTARG" ;;
            t) timeout="$OPTARG" ;;
            *) ;;
        esac
    done
    shift $((OPTIND - 1))
    if [[ "${1:-}" == "--" ]]; then shift; fi
    if [[ "$#" -eq 0 ]]; then
        echo "usage: excubitor.sh run -n <num_gpus> [-t <timeout_sec>] -- <command...>" >&2
        exit 1
    fi

    if ! [[ "$n" =~ ^[0-9]+$ ]] || [[ "$n" -lt 1 ]]; then
        echo "ERROR: -n must be a positive integer (got '${n}')" >&2
        exit 1
    fi
    if [[ "$n" -gt "$NUM_GPUS_TOTAL" ]]; then
        echo "ERROR: requested ${n} GPU(s) but only ${NUM_GPUS_TOTAL} are configured (set EXCUBITOR_GPU_TOTAL to override)" >&2
        exit 1
    fi

    acquire_n "$n" "$timeout" || exit 1
    local gpu_arr=("${HELD_GPUS[@]}")

    for gpu in "${gpu_arr[@]}"; do
        write_meta "$gpu" "$*"
    done

    # not `local`: still read by cleanup() when it runs as the EXIT trap,
    # by which point cmd_run has already returned and its locals are gone.
    cvd=$(IFS=,; echo "${gpu_arr[*]}")
    echo "[excubitor] acquired GPU(s): ${cvd}  (user=${USER} pid=$$)"

    cleanup() {
        for fd in "${HELD_FDS[@]}"; do
            flock -u "$fd" 2>/dev/null || true
            # NB: fd was opened in acquire_n()'s scope, not this nested
            # function's -- bash's `exec {fd}>&-` name-tracking only works
            # within the scope that opened it, so close by number via eval.
            eval "exec ${fd}>&-" 2>/dev/null || true
        done
        for gpu in "${HELD_GPUS[@]}"; do
            clear_meta "$gpu"
        done
        echo "[excubitor] released GPU(s): ${cvd}"
    }
    trap cleanup EXIT INT TERM

    CUDA_VISIBLE_DEVICES="$cvd" "$@"
}

cmd_status() { status; }

cmd_release() {
    if [[ "$#" -eq 0 ]]; then
        echo "usage: excubitor.sh release <gpu_id> [<gpu_id> ...]" >&2
        exit 1
    fi
    release_gpu_ids "$@"
}

cmd_gc() {
    # clear meta files for locks whose owning PID is dead but lock file
    # itself is not actually flocked (e.g. leftover from a crash before
    # flock even engaged) -- flock itself auto-releases when the holding
    # process dies, so this mostly just tidies up stale .meta files.
    for gpu in $(gpu_ids); do
        local mf; mf="$(meta_file "$gpu")"
        if [[ -f "$mf" ]] && ! is_locked "$gpu"; then
            rm -f "$mf"
        fi
    done
}

case "${1:-}" in
    run) shift; cmd_run "$@" ;;
    status) shift; cmd_gc; cmd_status ;;
    release) shift; cmd_release "$@" ;;
    *)
        echo "usage: excubitor.sh {run|status|release} ..." >&2
        exit 1
        ;;
esac
