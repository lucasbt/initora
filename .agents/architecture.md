# Architecture

## Overview

initora has two entry points:

1. `bootstrap.sh` — installs the toolkit for the current user.
2. `initora` — runs modules, applies migrations, and self-updates.

Modules are plain Bash files sourced into the `initora` process. They share
the same shell, helpers, configuration, and logging functions.

## Bootstrap flow

`bootstrap.sh` runs as the regular user (not root):

1. Checks/install dependencies: `git`, `curl`, `gum`, `bash-completion`.
2. Detects whether it was started from a local clone. If yes, that clone is
   used; otherwise the repository is cloned to `~/.local/share/initora`.
3. Creates `~/.local/bin/initora` as a symlink to the installation.
4. Copies `initora-default.config` to `~/.config/initora/initora.config`
   (never overwrites an existing config).
5. Installs Bash completion to
   `~/.local/share/bash-completion/completions/initora`.
6. Creates a GNOME `.desktop` entry that launches `initora` inside Ptyxis.

> The `initora` CLI resolves its code from
> `${SETUP_HOME}/.local/share/initora` (the canonical install path). For
> development, keep the working clone at that path or run module files
> directly with `bash modules/NN-name.sh`.

## CLI flow (`initora`)

1. `set -Eeuo pipefail` and an `ERR` trap that prints module, line, command,
   and stack trace to both the terminal and the log.
2. `_detect_user` resolves the real user from `SETUP_USER`, `SUDO_USER`,
   `logname`, or the current user, and sets `SETUP_HOME`.
3. `HOME` is exported as `SETUP_HOME`; canonical paths are derived:
   - `SCRIPT_DIR=~/.local/share/initora`
   - `CONFIG_DIR=~/.config/initora`
   - `CACHE_DIR=~/.cache/initora`
   - `LOG_FILE=~/.cache/initora/initora.log`
4. `utils.sh` and `initora-default.config` are sourced, then the user config.
5. Commands are dispatched:
   - no args → interactive menu (`gum`, or Bash `select` fallback)
   - `install` / `-i` → `--all`/`-a` or `--module`/`-m`
   - `-ia` / `--all` → all modules
   - `list` → module discovery
   - `update` → self-update + migrations
   - `uninstall`, `config`, `log`, `--help`
6. Modules are discovered from `modules/NN-name.sh` and executed by the
   function `module_NN_name`.

### Module selection

- Module IDs are single values: `00`, `10`, `20`, `30`, `40`, or a name such
  as `dev-tools` or `20-dev-tools`.
- Comma-separated lists are not parsed. `-m 20,30` fails with
  `Module not found`.
- `-ia` is an alias for `--all` and runs every module in numeric order.

## Logging and errors

`utils.sh` provides `log_info`, `log_success`, `log_warn`, `log_error`,
`log_section`, `step`, `ok`, and `skip`. All messages are appended to
`$LOG_FILE`; terminal output uses colors and icons.

The `ERR` trap in `initora` prints a stack trace and exits with the failing
command's status. Modules should return non-zero on unrecoverable errors.

## Sudo handling

`initialize_sudo` validates sudo once and starts a background keepalive loop.
`cleanup` stops that loop on exit. `run_as_root` executes directly when
already root, otherwise via `sudo`. `initora update` calls `initialize_sudo`
before applying migrations because migrations may need root.

## Cleanup

On successful exit, `cleanup()` deletes everything in `$CACHE_DIR` except
`*.log`. It does not touch the home directory, does not change ownership,
and does not run `dnf autoremove`.

## Migrations

Migrations live in `migrations/NNNN-description.sh` and define
`migration_NNNN_description()`. Applied IDs are stored one per line in
`~/.config/initora/migrations_applied`, outside the Git working tree so that
`initora update` (`git reset --hard` + `git clean -fd`) cannot erase them.

`initora update`:

1. Detects local changes and asks before discarding them.
2. Pulls or resets to `origin/main`.
3. Restores executable bits.
4. Runs all pending migrations.
5. Prints the version and the changelog between revisions.

## Completion and desktop integration

- `completions/initora-completion.bash` completes top-level commands,
  `install` flags, and module names resolved from `initora list`.
- `bootstrap.sh` and migration `0001` create the `.desktop` entry.
- `bootstrap.sh` and migration `0002` install Bash completion.

## CI and release automation

- `.github/workflows/ci.yml` runs ShellCheck, `bash -n`, actionlint, and a
  Fedora container smoke test.
- `.github/workflows/validate-branch.yml` enforces branch prefixes.
- `.github/workflows/bump-pr-version.yml` bumps `version` on PRs.
- `.github/workflows/release.yml` creates the tag and GitHub Release after a
  merge. Documentation branches skip both the bump and the release.
