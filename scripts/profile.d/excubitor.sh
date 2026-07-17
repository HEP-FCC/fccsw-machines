# excubitor.sh - login banner explaining GPU usage on this shared node.
# Installed by `make install` into /etc/profile.d/.

# Only show this for interactive login shells, not scripted/non-interactive
# sessions (e.g. scp, ansible, `ssh host cmd`).
[ -z "$PS1" ] && return

cat <<'EOF'

================================================================
 This node has shared GPUs -- use excubitor, don't launch CUDA jobs directly.
================================================================

  excubitor status                               # see what's free
  excubitor run -n <N> [-t <secs>] -- <command>   # run using N GPUs

  Examples:
    excubitor run -n 1 -- python train.py
    excubitor run -n 2 -t 600 -- python train_multi.py

  Bypassing excubitor on a GPU it already tracks as busy just fails --
  the driver refuses a second CUDA context. But if you bypass it while
  it's free, excubitor won't know, and a later `excubitor run` may get
  assigned that same GPU and fail to start. Use excubitor every time.

  (excubitor: the Byzantine palace guard -- it stands watch over who
  holds which GPU.)

  Problems? Contact the administrators on Mattermost, "FCC SW Machines":
    https://mattermost.web.cern.ch/fccsw/channels/fccsw-machines
================================================================

EOF
