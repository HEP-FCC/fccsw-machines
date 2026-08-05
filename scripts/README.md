# scripts

Operational scripts for managing the FCC machines.

## excubitor / domestikos — GPU lock manager

A cooperative lock manager for a shared multi-GPU node, split into a user
command and an admin command:

- **`excubitor`** — run by anyone. `run`, `status`, `clean`.
- **`domestikos`** — run by an admin (root). `gc`, `status`, `check`, `offenders`.

This is COOPERATIVE only: it stops nothing at the kernel/driver level. It
only works if everyone uses `excubitor run` instead of launching CUDA jobs
directly. `make install` also sets up `nvidia-smi -c EXCLUSIVE_PROCESS` as
a hard backstop (see below) so a forgotten lock causes a crash instead of
silent corruption, and runs `domestikos check` periodically to catch and
log anyone who bypasses `excubitor` anyway.

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

`make install` also installs `systemd/domestikos.service` +
`systemd/domestikos.timer` and starts the timer, which runs `domestikos
check` once now, again ~1 minute after every boot, and every 5 minutes
after that. Each run does two things:

- best-effort (re-)assert `nvidia-smi -c EXCLUSIVE_PROCESS` (GPU compute
  mode, like the lock dir, resets on reboot and isn't backed by any file
  that would otherwise survive it) — silently, since this normally fails
  once any GPU has an active process, which is the steady state after the
  first successful run;
- check every GPU `excubitor` considers free for actual driver-visible
  usage, and log a `WARN` line (visible via `journalctl -u
  domestikos.service`) for any bypass found.

The very first run happens synchronously during `make install`; if it
fails (e.g. a GPU is already in use), `make install` warns rather than
aborting — it'll succeed automatically once idle, either on the next
timer tick or via `systemctl start domestikos.service`.

To update after a `git pull`, re-run `sudo make -C ~/fccsw-machines/scripts
install` — the installed copies don't update themselves.

`make install` also installs `profile.d/excubitor.sh` into
`/etc/profile.d/`, a login banner explaining `excubitor` usage to anyone
who logs into the node interactively.

To remove: `sudo make -C ~/fccsw-machines/scripts uninstall`. This removes
the installed commands, the tmpfiles.d rule, the systemd service and
timer, and the login banner, but leaves the lock directory and the GPU's
current compute mode in place — the latter reverts to the driver default
only on the next reboot, since the timer that re-applies it is gone.

Both `PREFIX` (default `/usr/local`) and `BINDIR`/`LIBEXECDIR` can be
overridden, e.g. `make install PREFIX=/opt`.

### Installation via RPM (alternative to `make install`)

`scripts/packaging/excubitor.spec` packages the same install as an RPM,
so `dnf`/`rpm` track every file instead of `make install` writing
straight onto the system. It installs to the standard `/usr` paths
(`/usr/bin`, `/usr/libexec/excubitor`, ...) rather than `/usr/local` —
don't mix the two install methods on one host; if a node was previously
set up with `make install`, run `sudo make -C ~/fccsw-machines/scripts
uninstall` first.

Build (needs `rpm-build`; run from a checkout, not as root):

```
make -C ~/fccsw-machines/scripts rpm
```

This drops `excubitor-<version>-1.<dist>.noarch.rpm` under
`scripts/rpmbuild/RPMS/noarch/`. Install/upgrade/remove with normal
package-manager commands:

```
sudo dnf install ./excubitor-0.1.0-1.el9.noarch.rpm
sudo dnf upgrade ./excubitor-0.1.0-1.el9.noarch.rpm   # after a version bump + rebuild
sudo dnf remove excubitor
```

The package's `%post`/`%preun`/`%postun` scriptlets do exactly what
`make install`/`uninstall` do by hand: apply the tmpfiles rule, enable
and (best-effort) start `domestikos.timer`/`.service` on install, and
stop/disable them on final removal (an upgrade leaves them running).
Same caveat as `make install`: the first `domestikos check` run may
warn and defer to the next timer tick if a GPU is already busy.

The RPM's version comes from `EXCUBITOR_VERSION` in
`lib/excubitor-common.sh` (also what `excubitor -v`/`domestikos -v`
print) — bump that when cutting a new release, then re-run `make rpm`.

### Usage

```
excubitor status
excubitor run -n <num_gpus> [-t <timeout_sec>] -- <command...>
```

`excubitor -v`/`--version` and `domestikos -v`/`--version` print the
installed version (both share one version number, defined in
`lib/excubitor-common.sh`, since they're always installed/updated
together).

```
excubitor run -n 1 -- python train.py
excubitor run -n 2 -t 600 -- python train_multi.py
```

The GPU count is always auto-detected via `nvidia-smi -L` and isn't
overridable by a regular user -- how many GPUs a node has is a fact about
the node, not something an individual `excubitor` invocation should be
able to misrepresent.

`status` also cross-checks against `nvidia-smi --query-compute-apps` and
flags a GPU as `UNTRACKED` (with the owning user and PID(s), via `ps`) if
it's busy with a process that never went through `excubitor run` -- i.e.
someone bypassed it entirely. This is visibility only; nothing here stops
or evicts an untracked process.

```
excubitor clean
```

Clears your own stale (dead-process) lock/meta files, e.g. left behind
by a crashed job, and reports how many it found. `status` already does
this same cleanup silently as a side effect; `clean` is for when you
want to trigger it explicitly and see confirmation. Only affects entries
you own -- another user's leftovers need `domestikos gc`.

### Admin maintenance

```
sudo domestikos gc
```

Force-clears stale lock/meta files left behind by crashed jobs, regardless
of which user owned them (a regular user's `excubitor status` can only
clean up its own). This never touches a lock still held by a live process —
there is no force-eviction of running jobs.

`domestikos check` is what `domestikos.timer` runs periodically (see
Installation above); it can also be run by hand any time to force an
immediate re-check.

```
domestikos offenders               # bypass warnings from the last 24h
domestikos offenders "1 hour ago"  # or any journalctl --since value
```

Shows `check`'s `UNTRACKED`/bypass warnings pulled from the systemd
journal, so you don't have to hand-roll the `journalctl -u
domestikos.service` query yourself. Doesn't require root (though
`domestikos` as a whole is meant to be run as one).

```
domestikos usage                # per-user job count + total GPU-time, last 7 days
domestikos usage "30 days ago"  # or any journalctl --since value
```

Every `excubitor run` logs a `USAGE` record (tag `excubitor`, e.g. via
`journalctl -t excubitor`) when a job releases its GPU(s), recording the
user, GPU(s), duration, and command. `domestikos usage` aggregates those
into a per-user table of job count and total GPU-time, plus a grand
total. Reading other users' journal entries typically requires root or
`systemd-journal` group membership, so in practice this is an admin-only
view even though the command itself doesn't enforce it.

### Support

Problems should be reported to the administrators via the "FCC SW Machines"
Mattermost channel: https://mattermost.web.cern.ch/fccsw/channels/fccsw-machines
