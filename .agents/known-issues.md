# Known issues and resolved findings

This file records the modernization review findings and their current status.

## Resolved findings

### 1. CLI documentation did not match the implementation

**Status:** resolved.

- `initora -ia` is now a real alias for `--all` (full installation).
- Comma-separated module IDs (`-m 20,30`) were never implemented and are no
  longer documented. The CLI rejects them as `Module not found`.
- Help text, README, and Bash completion include `-ia` and only document
  single module IDs.

### 2. Bootstrap local-clone detection

**Status:** intentional, documented.

`bootstrap.sh` keeps the local-clone detection: when run from a clone that
contains `initora`, it uses that clone instead of re-cloning. The canonical
installation path remains `~/.local/share/initora`.

Caveat: the `initora` CLI always resolves modules from
`${SETUP_HOME}/.local/share/initora`. If you run `bootstrap.sh` from a clone
outside that path, the `~/.local/bin/initora` symlink points at the clone but
the CLI will still look for modules in the canonical path. For development,
keep the clone at `~/.local/share/initora` or run module files directly with
`bash modules/NN-name.sh`.

### 3. `gum` availability

**Status:** resolved.

`gum` is available in the Fedora repositories, so `bootstrap.sh` continues to
install it as a normal dependency. The Bash `select` fallback remains for
systems without `gum`.

### 4. `gpgcheck=False`

**Status:** intentional.

The project uses third-party repositories that are not consistently signed.
`gpgcheck=False` is kept deliberately. Revisit only with an explicit security
decision and a migration plan.

### 5. IntelliJ IDEA installation

**Status:** resolved.

The IntelliJ download/install block was removed from `modules/20-dev-tools.sh`.
Existing IntelliJ installations are left in place; initora no longer manages
or updates them.

### 6. VS Code Podman socket and architecture

**Status:** resolved.

- `DOCKER_HOST` now uses the detected UID:
  `unix:///run/user/<uid>/podman/podman.sock`.
- The project targets `x86_64` only. `kubectl` and AWS CLI downloads remain
  amd64 assets, and `initora` warns when `uname -m` is not `x86_64`.

### 7. Cleanup was too aggressive

**Status:** resolved.

- `cleanup()` no longer runs `chown -R` over the home directory.
- `cleanup()` no longer runs `dnf autoremove`.
- It removes only non-log files under `$CACHE_DIR` and stops the sudo
  keepalive.
- `initora update` now calls `initialize_sudo` before applying migrations.

### 8. LocalSearch was disabled

**Status:** resolved.

`modules/30-desktop.sh` now enables LocalSearch by resetting the Tracker3
`Miner.Files` keys to upstream defaults. Set `LOCALSEARCH_ENABLE_FILES=false`
to disable indexing.

### 9. Rootless Podman configuration

**Status:** resolved.

- Uses the detected user (`$user`) rather than `$USER`.
- Sets `XDG_RUNTIME_DIR` when calling `systemctl --user`.
- Uses `loginctl enable-linger "$user"`.
- Removed `fuse-overlayfs` and the custom
  `~/.config/containers/storage.conf`; native overlay is used.
- Migration `0003` removes the old initora-generated storage override.

### 10. README drift

**Status:** resolved.

- Removed GitHub Copilot CLI and IntelliJ IDEA from the feature and module
  descriptions.
- Fixed wallpaper asset extensions from `.jpg` to `.png`.
- Updated Nerd Fonts to the five fonts actually downloaded. IBM Plex Mono uses
  the Nerd Fonts release asset `IBMPlexMono.zip` (the family is also known as
  Blex Mono).

### 11. DNF5 compatibility

**Status:** resolved.

Removed from `[main]`:

- `deltarpm` (removed from DNF5)
- `metadata_expire=never` (valid but undesirable)
- `color=always` (not a global `[main]` option in DNF5)

Kept `fastestmirror=True` after confirming it is a valid DNF5 option.

### 12. CI and branch validation

**Status:** resolved.

- Added `.github/workflows/ci.yml` with:
  - `bash -n` syntax checks
  - ShellCheck (`-S warning`)
  - actionlint
  - Fedora container smoke test (`--help`, `list`, comma rejection)
- `validate-branch.yml` now accepts `minor/` and `documentation/`.
- Workflow scripts pass PR branch names through environment variables instead
  of interpolating untrusted expressions directly into shell commands.

## Current caveats

- **No full integration test.** CI does not run modules, because they install
  packages and modify the system. Validate modules in a Fedora VM or spare
  machine before release.
- **Secure Boot + NVIDIA.** The NVIDIA kernel module requires MOK enrollment.
  initora prints the command but cannot complete the firmware prompt.
- **x86_64 only.** ARM64 Fedora is not supported by the vendor downloads
  (kubectl, AWS CLI, some AppImages).
- **User config is not migrated.** If a user config still contains obsolete
  variables (for example `ENABLE_SSD_TRIM` or `LOCALSEARCH_DISABLE_*`), they
  are simply ignored. Remove them manually with `initora config`.
- **Local clone path.** See finding 2 above.
- **`gpgcheck=False`.** See finding 4 above.
- **Module functions share one shell.** Avoid generic function names that could
  collide across modules; prefix private helpers with `_` and a module-specific
  name when in doubt.
