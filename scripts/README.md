# scripts

Operational scripts for managing the FCC machines.

## excubitor / domestikos — GPU lock manager

A cooperative lock manager for a shared multi-GPU node, split into a user
command and an admin command:

- **`excubitor`** — run by anyone. `run`, `status`, `release`.
- **`domestikos`** — run by an admin (root). `gc`, `status`.

This is COOPERATIVE only: it stops nothing at the kernel/driver level. It
only works if everyone uses `excubitor run` instead of launching CUDA jobs
directly. `make install` also sets up `nvidia-smi -c EXCLUSIVE_PROCESS` as
a hard backstop (see below) so a forgotten lock causes a crash instead of
silent corruption.

### Installation (AlmaLinux 9 GPU nodes)

Targets: 4x NVIDIA A100-PCIE-40GB and Tesla T4 nodes. GPU count is
auto-detected via `nvidia-smi -L` at every invocation, so the same install
works unmodified on both — no per-host config needed.

On each machine, clone the repo (e.g. into root's home, which is *not*
readable by other users) and install from it:

```
git clone <this repo> ~/fccsw-machines
sudo make -C ~/fccsw-machines/scripts install
```

`make install` copies `excubitor`, `domestikos`, and `lib/` into
`/usr/local/libexec/excubitor/` (a publicly reachable location, unlike the
clone itself if it lives under `/root`), and symlinks `/usr/local/bin/excubitor`
and `/usr/local/bin/domestikos` to those copies.

`make install` also installs `tmpfiles.d/excubitor.conf` into
`/etc/tmpfiles.d/` and runs `systemd-tmpfiles --create` to apply it
immediately, creating the shared lock directory (`/var/lock/excubitor` by
default, mode `1777`). systemd re-applies this rule on every future boot
too — `/var/lock` is a tmpfs on AlmaLinux/RHEL (symlinked to `/run/lock`),
so without it the directory would vanish on reboot and `excubitor` would
refuse to run until someone reinstalled by hand. `excubitor` refuses to
run until this has been done at least once.

`make install` also installs and enables
`systemd/nvidia-exclusive-process.service`, which runs `nvidia-smi -c
EXCLUSIVE_PROCESS` once now and again on every future boot (GPU compute
mode, like the lock dir, resets on reboot and isn't backed by any file
that would otherwise survive it). Enabling can fail if a GPU already has
a running process on it — `make install` warns rather than aborting in
that case; re-run `systemctl restart nvidia-exclusive-process.service`
once idle.

To update after a `git pull`, re-run `sudo make -C ~/fccsw-machines/scripts
install` — the installed copies don't update themselves.

`make install` also installs `profile.d/excubitor.sh` into
`/etc/profile.d/`, a login banner explaining `excubitor` usage to anyone
who logs into the node interactively.

To remove: `sudo make -C ~/fccsw-machines/scripts uninstall`. This removes
the installed commands, the tmpfiles.d rule, the systemd unit, and the
login banner, but leaves the lock directory and the GPU's current compute
mode in place — the latter reverts to the driver default only on the next
reboot, since the unit that re-applies it is gone.

Both `PREFIX` (default `/usr/local`) and `BINDIR`/`LIBEXECDIR` can be
overridden, e.g. `make install PREFIX=/opt`.

### Usage

```
excubitor status
excubitor run -n <num_gpus> [-t <timeout_sec>] -- <command...>
excubitor release <gpu_id> [<gpu_id> ...]
```

```
excubitor run -n 1 -- python train.py
excubitor run -n 2 -t 600 -- python train_multi.py
```

Set `EXCUBITOR_GPU_TOTAL` to override the auto-detected GPU count, e.g. to
reserve one GPU for something else.

`status` also cross-checks against `nvidia-smi --query-compute-apps` and
flags a GPU as `UNTRACKED` (with the owning user and PID(s), via `ps`) if
it's busy with a process that never went through `excubitor run` -- i.e.
someone bypassed it entirely. This is visibility only; nothing here stops
or evicts an untracked process.

### Admin maintenance

```
sudo domestikos gc
```

Force-clears stale lock/meta files left behind by crashed jobs, regardless
of which user owned them (a regular user's `excubitor status` can only
clean up its own). This never touches a lock still held by a live process —
there is no force-eviction of running jobs.

### Support

Problems should be reported to the administrators via the "FCC SW Machines"
Mattermost channel: https://mattermost.web.cern.ch/fccsw/channels/fccsw-machines
