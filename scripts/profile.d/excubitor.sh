# excubitor.sh - login banner explaining GPU usage on this shared node.
# Installed by `make install` into /etc/profile.d/.

# Only show this for interactive login shells, not scripted/non-interactive
# sessions (e.g. scp, ansible, `ssh host cmd`).
[ -z "$PS1" ] && return

cat <<'EOF'

================================================================
 Shared GPUs -- use excubitor, don't launch CUDA jobs directly.
================================================================

  excubitor status                                # see what's free
  excubitor run -n <N> [-t <secs>] -- <command>   # run using N GPUs

  Example:
    excubitor run -n 1 -- python train.py

  Bypassing it on a free GPU can make a later `excubitor run` land on
  the same one and fail to start. Use excubitor every time.

  (excubitor: the Byzantine palace guard -- it stands watch over who
  holds which GPU.)

  Problems? Contact the administrators on Mattermost, "FCC SW Machines":
    https://mattermost.web.cern.ch/fccsw/channels/fccsw-machines
================================================================

EOF
