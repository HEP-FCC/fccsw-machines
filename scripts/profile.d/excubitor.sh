# excubitor.sh - login banner explaining GPU usage on this shared node.
# Installed by `make install` into /etc/profile.d/.

# Only show this for interactive login shells, not scripted/non-interactive
# sessions (e.g. scp, ansible, `ssh host cmd`).
[ -z "$PS1" ] && return

cat <<'EOF'

================================================================
 Shared GPUs -- use excubitor, don't launch CUDA jobs directly.
   excubitor run -n <N> [-t <secs>] -- <command>   (or -g <id>[,<id>...])
 man excubitor | Problems: Mattermost "FCC SW Machines"
================================================================
EOF

command -v excubitor >/dev/null 2>&1 && excubitor status 2>/dev/null

echo "================================================================"
echo
