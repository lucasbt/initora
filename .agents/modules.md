# Modules

Modules live in `modules/NN-name.sh`, define `module_NN_name()`, and are
sourced by `initora`. They run in numeric order during a full installation.

| Module | Purpose |
| :--- | :--- |
| `00-system` | DNF, repositories, multimedia, GPU/Vulkan drivers, base packages, directories |
| `10-packages` | Vendor apps, RPM list, Flathub, Flatpak list |
| `20-dev-tools` | mise runtimes, mobile toolchain, containers, editors, cloud/AI tools |
| `30-desktop` | GNOME, Ptyxis, LocalSearch, Nerd Fonts, Microsoft fonts, wallpapers |
| `40-optimizations` | sysctl and journald limits |

## 00-system

- Configures `/etc/dnf/dnf.conf` with DNF5-compatible options:
  `gpgcheck=False`, `skip_if_unavailable=True`, `best=True`,
  `installonly_limit=2`, `max_parallel_downloads`, `fastestmirror=True`,
  `defaultyes=True`, `install_weak_deps=False`,
  `clean_requirements_on_remove=True`, `keepcache`.
- Removes the PyCharm COPR and RPM Fusion Steam repos. It intentionally keeps
  `rpmfusion-nonfree-nvidia-driver`.
- Adds RPM Fusion Free/Non-Free and the tainted release packages.
- Upgrades the system, removes orphaned packages, warns when a reboot is needed,
  then optionally updates firmware with `fwupdmgr`.
- Installs the common renderer stack (`mesa-vulkan-drivers`, `vulkan-loader`,
  `mesa-libGLU`, libglvnd libraries) before GPU detection.
- Detects GPUs with `lspci` and installs the matching VA-API stack:
  - Intel Gen12+ → `intel-media-driver` (iHD)
  - AMD RDNA 1+ → `mesa-va-drivers`, `mesa-vdpau-drivers`
  - NVIDIA Turing+ → `akmod-nvidia`, `xorg-x11-drv-nvidia-cuda`, `kernel-devel`,
    `acpid`, and optionally `nvidia-vaapi-driver`; warns about MOK enrollment
    and module/reboot status.
- Replaces `ffmpeg-free` with full `ffmpeg`, installs GStreamer/codec packages,
  and prints `vainfo` output when available.
- Installs base packages including `pciutils` and `switcheroo-control`.

## 10-packages

- Google Chrome stable from the Fedora/Google repository and Firefox from the
  Fedora RPM repository.
- Obsidian AppImage with `.desktop` integration and x86_64 asset selection.
- Bitwarden GUI (AppImage) and CLI (`bw`).
- Adds the Microsoft VS Code repository.
- Installs every package in `data/rpm-pkgs.list` (including Firefox and
  `fuse-libs`).
- Removes the duplicate Fedora Flatpak remote, configures Flathub, and installs
  every `remote app_id` entry in `data/flatpak-pkgs.list` (including Gearlever).
- Refreshes the font cache.

## 20-dev-tools

- **Build dependencies:** compilers and development headers, including
  `ninja-build` and `gtk3-devel` for Flutter Linux desktop builds.
- **Runtimes:** `mise` manages Java and Node.js (both `lts`), Python, Go, Rust,
  Maven, and Gradle. Node setup also runs `corepack enable` and installs global
  npm tools. The activation block in `.bashrc` is managed idempotently.
- **Containers:** rootless Podman, `podman-compose`, `podman-docker`, Buildah,
  Skopeo, a `docker=podman` shell alias, and a user `podman.socket`. The VS
  Code `DOCKER_HOST` uses the detected UID (`/run/user/<uid>/podman/podman.socket`).
  No `fuse-overlayfs` or custom `storage.conf` is written.
- **Editors:** VS Code settings (Java home from mise, Podman socket,
  terminal/font preferences) and Zed. IntelliJ IDEA and Pulsar are not installed.
- **Cloud/API:** AWS CLI v2, kubectl (amd64), Bruno (latest x86_64 RPM from GitHub releases), Insomnia.
- **GUI tools:** DBeaver, Draw.io, Typora.
- **Mobile:** KVM/libvirt (`qemu-kvm`, `virt-manager`, user groups, `libvirtd`),
  Android Studio (latest stable archive scraped from the official page), Flutter
  stable SDK, Android SDK `PATH` variables, and a conditional NVIDIA emulator alias.
- **AI tools:** Antigravity CLI and OpenCode CLI, plus OpenCode Desktop and
  Antigravity IDE/Desktop with versions resolved dynamically from official pages.
- **Shell:** Oh My Posh with the `pure` theme exported to a local config file.
  Starship is no longer installed.

## 30-desktop

- Applies `data/gnome-settings.list` (theme, fonts, Night Light, workspaces,
  power, touchpad, Nautilus, privacy, Ptyxis, GNOME Software update checks).
- Adds custom keybindings: `Super+T` for Ptyxis and `Super+Print` for Gradia.
- Configures the default Ptyxis profile (palette, font, scrollback, opacity).
- **LocalSearch:** enabled by default by resetting Tracker3 Miner.Files keys to
  upstream defaults. Set `LOCALSEARCH_ENABLE_FILES=false` to disable indexing.
- Installs Nerd Fonts that are not packaged as RPMs:
  - Hack
  - Meslo
  - Source Code Pro
  - Ubuntu Mono
  - IBM Plex Mono (Blex Mono; release asset `IBMPlexMono.zip`)
- JetBrains Mono, Fira Code, and Cascadia Code come from RPM packages and are
  not downloaded again.
- Installs Microsoft core fonts via the `msttcore-fonts-installer` RPM.
- Optionally downloads the wallpaper collection (`INSTALL_WALLPAPERS`).
- Does **not** disable ABRT, ModemManager, GNOME Remote Desktop,
  `NetworkManager-wait-online`, or DNF makecache units.

## 40-optimizations

- Writes `/etc/sysctl.d/99-initora.conf` with:
  - `vm.swappiness`
  - `net.core.somaxconn`
  - `net.ipv4.tcp_fastopen`
  - `net.ipv4.tcp_max_syn_backlog`
  - `net.core.netdev_max_backlog`
  - `fs.inotify.max_user_watches`
  - `fs.inotify.max_user_instances`
- Writes `/etc/systemd/journald.conf.d/99-initora.conf` with
  `SystemMaxUse=1G`, `SystemMaxFiles=10`, and `Compress=yes`.
- Does **not** set I/O scheduler udev rules, dirty-page ratios,
  `vfs_cache_pressure`, `fs.file-max`, or force `fstrim`. Those were removed
  as unnecessary on modern Fedora/NVMe systems.
