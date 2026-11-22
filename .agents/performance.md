# Performance and hardware tuning

## Target hardware

**Tested on:**
- Intel Gen12+ (Tiger Lake / 11th gen+)
- AMD RDNA 1+ (RX 5000+)
- NVIDIA Turing+ (RTX 20+)

**Minimum requirements:**
- Architecture: x86_64
- RAM: 16 GiB
- Storage: NVMe SSD

The previous tuning targeted a Haswell-era laptop with 8 GiB RAM and a SATA
SSD. Several settings were useful there but are unnecessary or counterproductive
on modern hardware.

## What remains

### DNF

- `max_parallel_downloads=10`
- `fastestmirror=True` (valid in DNF5; default is `False`)
- `keepcache=false`
- `installonly_limit=2`
- `defaultyes=True`
- `install_weak_deps=False`
- `clean_requirements_on_remove=True`
- `skip_if_unavailable=True`
- `best=True`
- `gpgcheck=False` (intentional, required by third-party repos)

### sysctl

- `vm.swappiness=10` — prefer RAM over swap; ZRAM still compresses before disk.
- `net.core.somaxconn=4096`
- `net.ipv4.tcp_fastopen=3`
- `net.ipv4.tcp_max_syn_backlog=4096`
- `net.core.netdev_max_backlog=4096`
- `fs.inotify.max_user_watches=524288`
- `fs.inotify.max_user_instances=512`

inotify limits matter for editors and build tools watching large projects.
Network backlog settings help container and Kubernetes workloads.

### journald

- `SystemMaxUse=1G`
- `SystemMaxFiles=10`
- `Compress=yes`

A 1 GiB cap is generous enough for debugging on a 512 GB disk while preventing
unbounded growth.

### Desktop

- GNOME animations are **enabled** (`GNOME_ANIMATIONS=true`). Modern Intel iGPUs
  (Gen12+) handle them smoothly.
- LocalSearch file indexing is **enabled** by default. It is cheap on this
  hardware and keeps GNOME search useful.
- GNOME Software automatic update checks/downloads are disabled with
  `gsettings`; system services are not masked.

### Fonts

Nerd Fonts are downloaded only when no RPM package provides them:

| Font | Source |
| :--- | :--- |
| JetBrains Mono | `jetbrains-mono-fonts-all` |
| Fira Code | `fira-code-fonts` |
| Cascadia Code | `cascadia-code-fonts` |
| Hack | Nerd Fonts release |
| Meslo | Nerd Fonts release |
| Source Code Pro | Nerd Fonts release |
| Ubuntu Mono | Nerd Fonts release |
| IBM Plex Mono (Blex Mono) | Nerd Fonts release (`IBMPlexMono.zip`) |

This avoids duplicate font families and reduces download size.

### Runtimes and prompt

A single `mise` installation replaces SDKMAN, NVM, rustup, and the manual Go
archive. Java and Node.js request `lts`, so the newest LTS is resolved at
install time instead of being pinned in the repository. Oh My Posh replaces
Starship, and its `pure` theme is exported to `~/.config/oh-my-posh/` so shell
startup does not fetch a remote theme. The generated `.bashrc` blocks are
surrounded by initora markers and replaced idempotently.

## What was removed and why

| Removed | Reason |
| :--- | :--- |
| udev I/O scheduler rules (`60-ioschedulers.conf`) | Modern Fedora kernels choose appropriate schedulers for NVMe/SATA; forcing `none`/`mq-deadline`/`bfq` adds risk without measurable gain. |
| `vm.dirty_ratio`, `vm.dirty_background_ratio` | Defaults are balanced for modern NVMe and mixed workloads; aggressive values can increase latency and data-loss risk on power loss. |
| `vm.vfs_cache_pressure=50` | Not a meaningful bottleneck on 32 GiB RAM; defaults are fine. |
| `fs.file-max=2097152` | systemd and Fedora already set high limits; the override was redundant. |
| Forced `fstrim -av` and custom TRIM setup | Fedora enables `fstrim.timer` by default; forcing a trim on every run is unnecessary. |
| `fuse-overlayfs` + custom `storage.conf` | Rootless Podman uses the native overlay driver on modern kernels; `fuse-overlayfs` adds overhead. |
| Disabling ABRT, ModemManager, GNOME Remote Desktop, `NetworkManager-wait-online`, DNF makecache | These services are useful or already well-behaved; disabling them caused confusing failures and did not produce measurable gains. |
| Disabling GNOME animations | Modern iGPU handles animations; disabled animations hurt UX more than they help. |
| Disabling LocalSearch | Breaks GNOME file search; indexing cost is negligible on this hardware. |
| SDKMAN, NVM, rustup, manual `/usr/local/go` | One `mise` install manages all requested runtimes and keeps them user-owned. |
| Starship | Oh My Posh is the supported prompt and exports a local theme config. |

## Graphics / VA-API

- Intel Gen12+ (Tiger Lake, Alder Lake, Meteor Lake) uses the iHD driver:
  `intel-media-driver`, not `libva-intel-driver` (which targets Haswell and older).
- AMD uses `mesa-va-drivers` and `mesa-vdpau-drivers`.
- All GPUs get the common Mesa Vulkan/OpenGL renderer stack and libglvnd
  libraries.
- NVIDIA uses RPM Fusion:
  - `akmod-nvidia`
  - `xorg-x11-drv-nvidia-cuda`
  - `kernel-devel` and `acpid` for akmods rebuilds
  - `nvidia-vaapi-driver` (optional)
- The `rpmfusion-nonfree-nvidia-driver` repository must stay enabled.
- Secure Boot requires enrolling the akmods MOK key:
  `sudo mokutil --import /etc/pki/akmods/certs/public_key.der`, then reboot.

## Legacy cleanup

Migration `0003-modern-hardware-cleanup.sh` removes, only when generated by
initora:

- `/etc/udev/rules.d/60-ioschedulers.conf`
- `~/.config/containers/storage.conf` with the `fuse-overlayfs` override
- obsolete sysctl keys from `/etc/sysctl.d/99-initora.conf`

It never removes user-authored files.
