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

### One-time setup (admin)

```
sudo ./domestikos init
```

Creates and permissions the shared lock directory (`/var/lock/excubitor` by
default). `excubitor` refuses to run until this has been done.

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

Set `EXCUBITOR_GPU_TOTAL` to override the default GPU count (4) if a node
has a different number of GPUs.

### Admin maintenance

```
sudo ./domestikos gc
```

Force-clears stale lock/meta files left behind by crashed jobs, regardless
of which user owned them (a regular user's `excubitor status` can only
clean up its own). This never touches a lock still held by a live process —
there is no force-eviction of running jobs.
