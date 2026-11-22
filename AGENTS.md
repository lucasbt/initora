# AGENTS.md

Guidance for AI agents and contributors working on **initora**, a modular Fedora
Workstation bootstrap toolkit.

## Project scope

- Target: Fedora Workstation 40+ (developed against Fedora 44), `x86_64` only.
- Tested on: Intel Gen12+ (Tiger Lake / 11th gen+), AMD RDNA 1+ (RX 5000+), NVIDIA Turing+ (RTX 20+).
- Minimum: 16 GiB RAM, NVMe SSD, x86_64.
- Note: Intel iGPU VA-API (iHD) requires Gen12+; older Intel GPUs work without hardware video acceleration.
- The project is a Bash toolkit, not an application framework. Keep changes
  small, explicit, and consistent with the existing module style.

## Repository map

```text
bootstrap.sh              # Installer: deps, clone, symlink, config, completion, .desktop
initora                   # CLI: module discovery/execution, migrations, self-update
initora-default.config    # Default configuration (copied to ~/.config/initora/)
utils.sh                  # Logging, DNF/Flatpak/GSettings helpers, download helpers
version                   # Version file (bumped automatically by CI)
modules/00-system.sh      # DNF, repos, multimedia, GPU/VA-API, base packages
modules/10-packages.sh    # RPM/Flatpak bulk installs and vendor apps
modules/20-dev-tools.sh   # Runtimes, containers, editors, cloud and AI CLIs
modules/30-desktop.sh     # GNOME settings, Ptyxis, LocalSearch, fonts, wallpapers
modules/40-optimizations.sh # sysctl and journald limits
data/                     # Package and GSettings lists
migrations/               # One-shot upgrades applied by `initora update`
completions/              # Bash completion
.github/workflows/        # CI, branch validation, version bump, release
.agents/                  # Detailed contributor/agent documentation
```

## Common commands

```bash
# Install / refresh the local installation
bash bootstrap.sh

# Full setup (all modules) — short form
initora -ia

# Full setup (explicit form)
initora install --all

# One module by number or name
initora install -m 20
initora install -m dev-tools

# Inspect and maintain
initora list
initora update
initora config
initora log

# Validation
bash -n bootstrap.sh initora utils.sh modules/*.sh migrations/*.sh
shellcheck -x -S warning bootstrap.sh initora utils.sh modules/*.sh migrations/*.sh completions/*.bash
actionlint .github/workflows/*.yml
```

`initora -ia` is the supported short form for a full installation. Module IDs
are single values only; comma-separated lists such as `-m 20,30` are **not**
supported.

## Engineering rules

1. **Bash strict mode.** Entry points use `set -Eeuo pipefail`. Preserve it.
2. **Idempotency.** Every module must be safe to re-run. Detect existing state
   and `skip` instead of reinstalling or overwriting user files.
3. **Use the helpers.** Prefer `run_as_root`, `dnf_install`, `dnf_remove`,
   `cached_download`, `ask_yes_no`, `has_cmd`, `is_rpm_installed`, and the
   `log_*`/`step`/`ok`/`skip` functions over ad-hoc shell.
4. **User context.** Never assume UID 1000 or a fixed home directory. Use
   `SETUP_USER`, `SETUP_HOME`, and `id -u "$user"` when a UID is required.
5. **Do not disable system services.** Older versions disabled ABRT,
   ModemManager, GNOME Remote Desktop, `NetworkManager-wait-online`, and DNF
   makecache units. That block was removed intentionally; do not reintroduce it.
   GNOME Software update checks are disabled through `gsettings` only.
6. **Do not chown the home directory.** `cleanup()` only removes cache files
   and stops the sudo keepalive. Never run `chown -R` over `$HOME` and never
   run `dnf autoremove` as part of cleanup.
7. **DNF5 compatibility.** Use options supported by DNF5. Do not add
   `deltarpm`, `color=always`, or `metadata_expire=never` to `[main]`.
   `fastestmirror` is valid in DNF5.
8. **`gpgcheck=False` is intentional.** It is required for some third-party
   repositories used by this project. Do not change it without an explicit
   decision and a migration.
9. **Keep the NVIDIA RPM Fusion repo.** `rpmfusion-nonfree-nvidia-driver` is
   required for hybrid NVIDIA laptops and must not be added to the unwanted
   repository list.
10. **Fonts.** JetBrains Mono, Fira Code, and Cascadia Code come from RPM
    packages. Only fonts without an RPM equivalent are downloaded by the
    Nerd Fonts installer: Hack, Meslo, Source Code Pro, Ubuntu Mono, and
    IBM Plex Mono (Blex Mono; release asset `IBMPlexMono.zip`).
11. **Migrations.** State lives in `~/.config/initora/migrations_applied`.
    Migration functions are named `migration_NNNN_description()`. Only add a
    migration when an existing installation needs a one-time fix.
12. **Versioning.** Never edit `version` manually in a feature PR. The
    `Bump Version on PR` workflow bumps it based on the branch prefix.
    Documentation branches (`docs/`, `documentation/`) do not bump or release.
13. **Language runtimes.** Use `mise` for Java, Node.js, Python, Go, and Rust.
    Do not reintroduce SDKMAN, NVM, rustup, or manual `/usr/local/go`
    installations. Oh My Posh is the default shell prompt; do not reintroduce
    Starship.

## Safety checklist before committing

- [ ] `bash -n` passes for every changed shell file.
- [ ] `shellcheck -x -S warning` passes.
- [ ] `actionlint` passes for workflow changes.
- [ ] New config variables have defaults in `initora-default.config` and are
      documented in `.agents/configuration.md`.
- [ ] New packages exist in Fedora/RPM Fusion or are installed by a vendor
      installer; avoid duplicate sources (RPM + Nerd Fonts, for example).
- [ ] No secrets, tokens, or machine-specific paths were added.
- [ ] Existing user configuration is not overwritten.

## Related documentation

- `.agents/architecture.md` — execution flow, user detection, migrations.
- `.agents/modules.md` — what each module installs and configures.
- `.agents/configuration.md` — configuration variables and data lists.
- `.agents/performance.md` — tuning decisions and rationale.
- `.agents/known-issues.md` — resolved findings and current caveats.
- `.agents/testing.md` — CI jobs and local validation.
