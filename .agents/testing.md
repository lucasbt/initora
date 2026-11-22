# Testing and validation

## Automated CI

`.github/workflows/ci.yml` runs on every pull request, on pushes to `main`,
and on manual dispatch.

### `shellcheck` job (Ubuntu)

- `bash -n` for every `*.sh`, `*.bash`, and the `initora` executable.
- `shellcheck -x -S warning` over the same files.

Run locally:

```bash
bash -n bootstrap.sh initora utils.sh modules/*.sh migrations/*.sh
shellcheck -x -S warning bootstrap.sh initora utils.sh modules/*.sh migrations/*.sh completions/*.bash
```

### `actionlint` job

Validates every workflow under `.github/workflows/`.

```bash
actionlint .github/workflows/*.yml
```

### `fedora-smoke` job

Runs in a `fedora:latest` container as a non-root user:

- copies the repository to `~/.local/share/initora`
- runs `initora --help` and checks that `-ia` is documented
- runs `initora list`
- verifies that `initora install -m 20,30` is rejected

This job intentionally does not execute modules, because they install
packages and modify the system.

## Local validation

### Static checks

```bash
bash -n bootstrap.sh initora utils.sh modules/*.sh migrations/*.sh
shellcheck -x -S warning bootstrap.sh initora utils.sh modules/*.sh migrations/*.sh completions/*.bash
actionlint .github/workflows/*.yml
```

### CLI behavior

```bash
# Help includes -ia and no comma-separated examples
initora --help

# Module discovery
initora list

# Comma-separated IDs must fail before any sudo/module execution
initora install -m 20,30; echo "exit=$?"   # expected non-zero

# Full install (destructive; use a VM)
initora -ia
```

### Shell completion

```bash
source completions/initora-completion.bash
initora <TAB>
initora install -m <TAB>
```

## Fedora VM checklist

Use a disposable Fedora Workstation VM or spare machine. Take a snapshot
before running.

1. **Fresh install**
   ```bash
   bash bootstrap.sh
   initora --help
   initora list
   ```
2. **Full run**
   ```bash
   initora -ia
   ```
   Verify:
   - no unexpected `chown` of the home directory
   - no `dnf autoremove` during cleanup
   - `~/.cache/initora` contains only `*.log` after success
   - journald limits: `systemctl show systemd-journald -p SystemMaxUse`
   - sysctl: `sysctl vm.swappiness fs.inotify.max_user_watches`
3. **Idempotency**
   ```bash
   initora -ia
   ```
   The second run should skip most work and must not fail.
4. **Migrations**
   ```bash
   initora update
   ```
   Pending migrations run once; the IDs are recorded in
   `~/.config/initora/migrations_applied`. Running `initora update` again
   should report no pending migrations.
5. **Legacy cleanup (migration 0003)**
   - create an initora-style `/etc/udev/rules.d/60-ioschedulers.conf`
   - create `~/.config/containers/storage.conf` with the old
     `fuse-overlayfs` content
   - run `initora update`
   - confirm both were removed and user-authored files were untouched
6. **Podman**
   ```bash
   systemctl --user status podman.socket
   podman info | grep -i overlay
   ```
   The storage driver should be `overlay` without `fuse-overlayfs`.
7. **Graphics**
   ```bash
   vainfo
   nvidia-smi          # hybrid NVIDIA machines
   glxinfo -B
   ```
8. **LocalSearch**
   ```bash
   gsettings get org.freedesktop.Tracker3.Miner.Files index-single-directories
   gsettings get org.freedesktop.Tracker3.Miner.Files crawling-interval
   ```
9. **Fonts**
   ```bash
   fc-list | grep -iE 'Hack|Meslo|Source Code Pro|Ubuntu Mono|IBM Plex Mono'
   fc-list | grep -i 'JetBrains Mono'
   ```
10. **Uninstall**
    ```bash
    initora uninstall
    ```
    Confirm binary, config, cache, and installation directory are removed.

## What CI cannot catch

- RPM/Flatpak availability changes in Fedora repositories.
- Vendor installer/API changes (Antigravity, OpenCode, Obsidian, Bitwarden,
  Insomnia, Bruno, DBeaver, Draw.io, Typora).
- NVIDIA/Secure Boot firmware prompts.
- GNOME/DBus behavior that depends on a real desktop session.
- Hardware-specific VA-API results.

Validate those in a VM or on the target laptop before tagging a release.
