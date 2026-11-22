# Configuration

## Precedence

Configuration is loaded in this order:

1. `initora-default.config` (defaults, versioned in the repo).
2. `~/.config/initora/initora.config` (user overrides, created on first run).
3. Environment variables already exported by the caller.

`initora` creates the user config from defaults if it does not exist and never
overwrites it. `bootstrap.sh` also creates it during installation.

## Paths

| Variable | Default | Meaning |
| :--- | :--- | :--- |
| `SETUP_USER` | detected | Real (non-root) user |
| `SETUP_HOME` | detected | Home directory of `SETUP_USER` |
| `SETUP_DIR` | `~/.local/share/initora` | Canonical installation |
| `CONFIG_DIR` | `~/.config/initora` | User config and migration state |
| `CACHE_DIR` | `~/.cache/initora` | Downloads and logs |
| `LOG_FILE` | `~/.cache/initora/initora.log` | Execution log |
| `WALLPAPERS_DIR` | `~/Pictures/walls` | Wallpaper collection |

## Installation toggles

| Variable | Default | Effect |
| :--- | :--- | :--- |
| `INSTALL_WALLPAPERS` | `true` | Download the wallpaper collection (asks first) |
| `INSTALL_MULTIMEDIA` | `true` | Install codecs, FFmpeg, GStreamer, VA-API |
| `INSTALL_PROPRIETARY_FIRMWARE` | `true` | Run `fwupdmgr` updates |
| `INSTALL_PODMAN_DESKTOP` | `true` | Install Podman Desktop |
| `INSTALL_MISE` | `true` | Install mise and all language runtimes |
| `INSTALL_OH_MY_POSH` | `true` | Install Oh My Posh with the `pure` theme |
| `INSTALL_KVM` | `true` | Install and configure KVM/libvirt |
| `INSTALL_ANDROID_STUDIO` | `true` | Install Android Studio and configure Android env |
| `INSTALL_FLUTTER` | `true` | Install the Flutter stable SDK |
| `INSTALL_OPENCODE_DESKTOP` | `true` | Install the latest OpenCode Desktop RPM |
| `INSTALL_ANTIGRAVITY_APPS` | `true` | Install Antigravity IDE and Desktop |
| `PODMAN_DOCKER_ALIAS` | `true` | Add `docker=podman` aliases to `.bashrc` |
| `ENABLE_RPMFUSION_FREE` | `true` | Add RPM Fusion Free |
| `ENABLE_RPMFUSION_NONFREE` | `true` | Add RPM Fusion Non-Free |
| `ENABLE_FLATHUB` | `true` | Add Flathub and install Flatpaks |

## DNF

| Variable | Default | Notes |
| :--- | :--- | :--- |
| `DNF_MAX_PARALLEL` | `10` | `max_parallel_downloads` |
| `DNF_KEEPCACHE` | `false` | `keepcache` |

`gpgcheck=False` is hard-coded in `modules/00-system.sh` and is intentional.

## Runtimes and prompt

| Variable | Default | Notes |
| :--- | :--- | :--- |
| `MISE_JAVA_VERSION` | `lts` | Resolves dynamically to the newest Java LTS |
| `MISE_NODE_VERSION` | `lts` | Resolves dynamically to the newest Node.js LTS |
| `MISE_PYTHON_VERSION` | `latest` | Python version request for mise |
| `MISE_GO_VERSION` | `latest` | Go version request for mise |
| `MISE_RUST_VERSION` | `latest` | Rust version request for mise |
| `OH_MY_POSH_THEME` | `pure` | Theme name exported to `~/.config/oh-my-posh/` |

The `lts` aliases are resolved by mise at install time; no patch version is
pinned in the repository. Maven and Gradle are always requested as `latest`.

## Mobile development

| Variable | Default | Notes |
| :--- | :--- | :--- |
| `ANDROID_HOME` | `~/Android/Sdk` | Android SDK root written to `.bashrc` |

Android SDK subdirectories are created, but SDK packages and licenses are not
accepted automatically. KVM group changes require logout/login.

## Graphics / NVIDIA

| Variable | Default | Effect |
| :--- | :--- | :--- |
| `INSTALL_NVIDIA_DRIVER` | `true` | Install the NVIDIA driver when an NVIDIA GPU is detected |
| `INSTALL_NVIDIA_VAAPI` | `true` | Install `nvidia-vaapi-driver` |

On hybrid laptops, Intel VA-API remains the primary path; NVIDIA is used for
CUDA and, when configured, VA-API. Secure Boot requires MOK enrollment.

## GNOME

Appearance: `GNOME_COLOR_SCHEME`, `GNOME_GTK_THEME`, `GNOME_ICON_THEME`,
`GNOME_TEXT_SCALE`, `GNOME_FONT_UI`, `GNOME_FONT_DOCUMENT`,
`GNOME_FONT_MONO`, `GNOME_CURSOR_BLINK`, `GNOME_ANIMATIONS`.

Night Light: `GNOME_NIGHT_LIGHT_ENABLED`, `GNOME_NIGHT_LIGHT_TEMPERATURE`,
`GNOME_NIGHT_LIGHT_AUTO`, `GNOME_NIGHT_LIGHT_FROM`, `GNOME_NIGHT_LIGHT_TO`.

Workspaces/windows: `GNOME_DYNAMIC_WORKSPACES`, `GNOME_NUM_WORKSPACES`,
`GNOME_WORKSPACES_PRIMARY_ONLY`, `GNOME_BUTTON_LAYOUT`.

Power: `GNOME_SLEEP_AC_TIMEOUT`, `GNOME_SLEEP_BATTERY_TIMEOUT`,
`GNOME_IDLE_DIM`, `GNOME_AMBIENT_BRIGHTNESS`.

Input: `GNOME_TOUCHPAD_TAP_CLICK`, `GNOME_TOUCHPAD_TWO_FINGER_SCROLL`,
`GNOME_TOUCHPAD_NATURAL_SCROLL`.

Nautilus: `GNOME_NAUTILUS_VIEW`, `GNOME_NAUTILUS_SHOW_HIDDEN`.

Privacy: `GNOME_PRIVACY_RECENT_FILES`, `GNOME_PRIVACY_RECENT_FILES_AGE`,
`GNOME_PRIVACY_REMOVE_TEMP`, `GNOME_PRIVACY_OLD_FILES_AGE`.

## Ptyxis

App-level: `PTYXIS_INTERFACE_STYLE`, `PTYXIS_TAB_BAR_POLICY`,
`PTYXIS_RESTORE_SESSION`, `PTYXIS_AUDIBLE_BELL`, `PTYXIS_NEW_TAB_POSITION`.

Profile-level: `PTYXIS_PALETTE`, `PTYXIS_USE_SYSTEM_FONT`,
`PTYXIS_FONT_NAME`, `PTYXIS_SCROLLBACK_LINES`, `PTYXIS_OPACITY`,
`PTYXIS_BOLD_IS_BRIGHT`, `PTYXIS_LOGIN_SHELL`.

## Performance

| Variable | Default | Notes |
| :--- | :--- | :--- |
| `VM_SWAPPINESS` | `10` | Lower = prefer RAM over swap |
| `JOURNALD_MAX_SIZE` | `1G` | Journal size cap |
| `JOURNALD_MAX_FILES` | `10` | Journal file cap |
| `LOCALSEARCH_ENABLE_FILES` | `true` | Enable GNOME file indexing |

## Data lists

### `data/rpm-pkgs.list`

One RPM package per line. Blank lines and lines starting with `#` are ignored.
Inline comments after a space are stripped. Keep fonts that are already
provided by RPM packages out of the Nerd Fonts array in
`modules/30-desktop.sh`.

### `data/flatpak-pkgs.list`

Format: `remote app_id`, for example:

```text
flathub it.mijorus.gearlever
```

### `data/gnome-settings.list`

Format: `schema key value`. Values may reference config variables with
`${VAR}`; they are expanded with `eval` by
`apply_gnome_settings_file()`.

Example:

```text
org.gnome.desktop.interface color-scheme "${GNOME_COLOR_SCHEME}"
```

## Adding a package

- Native package → append to `data/rpm-pkgs.list`.
- Flatpak → append to `data/flatpak-pkgs.list`.
- Vendor installer (AppImage, vendor repo) → add a dedicated function in the
  relevant module and make it idempotent.
- GNOME setting → append to `data/gnome-settings.list`.

## Migration state

Applied migration IDs are stored in
`~/.config/initora/migrations_applied`. Delete a line only when intentionally
re-running that migration.
