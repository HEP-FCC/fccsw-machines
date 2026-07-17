# scripts

Operational scripts for managing the FCC machines.

## excubitor / domestikos — GPU lock manager

A cooperative lock manager for a shared multi-GPU node, split into a user
command and an admin command:

- **`excubitor`** — run by anyone. `run`, `status`, `release`.
- **`domestikos`** — run by an admin (root). `init`, `gc`, `status`.

This is COOPERATIVE only: it stops nothing at the kernel/driver level. It
only works if everyone uses `excubitor run` instead of launching CUDA jobs
directly. Pair it with `nvidia-smi -c EXCLUSIVE_PROCESS` as a hard backstop
so a forgotten lock causes a crash instead of silent corruption.

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
clone itself if it lives under `/root`), symlinks `/usr/local/bin/excubitor`
and `/usr/local/bin/domestikos` to those copies, and runs `domestikos init`.

`domestikos init` creates the shared lock directory (`/var/lock/excubitor`
by default) and writes `/etc/tmpfiles.d/excubitor.conf` so systemd recreates
it automatically on every boot — `/var/lock` is a tmpfs on AlmaLinux/RHEL
(symlinked to `/run/lock`), so without that rule the directory would vanish
on reboot and `excubitor` would refuse to run until someone re-ran `init`
by hand. `excubitor` refuses to run until `init` has been done at least
once.

To update after a `git pull`, re-run `sudo make -C ~/fccsw-machines/scripts
install` — the installed copies don't update themselves.

To remove: `sudo make -C ~/fccsw-machines/scripts uninstall`. This removes
the installed commands and the tmpfiles.d rule, but leaves the lock
directory itself in place in case jobs are still using it.

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

### Admin maintenance

```
sudo ./domestikos gc
```

Force-clears stale lock/meta files left behind by crashed jobs, regardless
of which user owned them (a regular user's `excubitor status` can only
clean up its own). This never touches a lock still held by a live process —
there is no force-eviction of running jobs.
