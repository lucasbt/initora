<div align="center">
   <img align="center" alt="Initora Logo" src="assets/initora_logo_neon.png" width="40%"/>	
	<p align="center">
     <br />
		<b>Automated setup • Performance tuned • Ready-to-code</b>
     <br />
   </p>
   <p align="center">
   <a href="https://fedoraproject.org/"><img src="https://img.shields.io/badge/Fedora-44+-blue?logo=fedora&logoColor=white" alt="Fedora"></a>
   <a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white" alt="Shell: Bash"></a>
   <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
</p>
   <h1></h1>
</div>

#### Fedora Workstation Bootstrap for Developers

**Initora** is a high-end, modular, and idempotent bootstrap toolkit designed to transform a fresh Fedora Workstation installation into a professional development powerhouse. It automates everything while respecting your system and existing configurations.

## ✨ Key Features

- **🎯 Modular Architecture:** 5 independent modules for granular control. Run specific modules or re-run safely anytime—fully idempotent. [See details below](#-modular-architecture)

- **🚀 Performance-First:** DNF parallelization (10 concurrent downloads), kernel `sysctl` tuning for development workloads, and a bounded systemd journal.

- **💻 Polyglot Toolchain:** Automated management for Java (SDKMAN: 21 LTS & 25), Node.js (NVM with LTS), Rust (rustup), and Golang (latest stable).

- **🤖 AI-Ready:** Built-in support for Antigravity CLI and OpenCode.

- **🎨 Visual Excellence:** Dark mode GNOME, 5 Nerd Fonts with ligatures, Microsoft fonts, custom Ptyxis terminal, and curated wallpaper collection.

- **📦 App Ecosystem:** VSCode, Zed, Podman, AWS CLI, kubectl, DBeaver, Postman, Insomnia, Obsidian, Bitwarden, Draw.io, Typora, Chrome, and more.

- **🖥️ Hybrid Graphics:** Detects Intel, AMD, and NVIDIA GPUs; installs the correct VA-API drivers and the NVIDIA driver from RPM Fusion on hybrid laptops.

- **🛠 Idempotency:** Safely re-run any module. Detects existing states, skips redundant operations, and updates outdated software.

- **🖥️ Desktop Integration:** Appears in GNOME applications menu. Launch from Activities → "Initora".

- **⌨️ Shell Autocomplete:** Bash tab-completion for all commands, flags, and module names — no need to memorize module numbers.

## 🚀 Quick Start

**IMPORTANT:** Install `git` if not already present *(ships with Fedora Workstation)*

```bash
sudo dnf install -y git
```

### 1. One-liner Installation
The easiest way to provision your system is by running the bootstrap script directly from the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/lucasbt/initora/main/bootstrap.sh | bash
```

### 2. Manual Setup
If you want to inspect the code before running:

```bash
git clone https://github.com/lucasbt/initora ~/.local/share/initora
cd ~/.local/share/initora
bash bootstrap.sh
```

> `bootstrap.sh` automatically installs bash tab-completion for `initora` (see [Shell Autocomplete](#-shell-autocomplete)). Open a new terminal after the first install to enable it.


## 🛠 Usage & CLI

Initora provides a comprehensive CLI with both interactive and scripted modes.

| Command | Description |
| :--- | :--- |
| `initora` | Interactive module selector (GUM UI). Choose modules via menu. |
| `initora install` | Execute all 5 modules in sequence (full setup). |
| `initora -ia` | Short form for a full installation (all modules). |
| `initora install -m 20` | Run a specific module (e.g., dev tools). Use `00`, `10`, `20`, `30`, `40`. |
| `initora list` | Show all available modules and their descriptions. |
| `initora update` | Self-update repository and apply pending migrations. |
| `initora config` | Edit user configuration file (`~/.config/initora/initora.config`). |
| `initora log` | View execution logs interactively via `less` (search with `/`). |
| `initora uninstall` | Remove initora completely (binary, config, cache, aliases). |

### Usage Examples

**Full installation:**
```bash
initora -ia
```

**Install only Dev Tools:**
```bash
initora install -m 20
```

**Install a module by name:**
```bash
initora install -m desktop
```

**View logs:**
```bash
initora log
```

### Uninstallation
```bash
initora uninstall
```
Removes binary, config, cache, and aliases. *(Does not revert installed packages or system changes.)*

## ⌨️ Shell Autocomplete

Initora ships with a bash completion script that suggests:

- **Top-level commands:** `install`, `list`, `update`, `uninstall`, `config`, `log`, `--help`, `-ia`
- **`install` flags:** `--all`/`-a`, `--module`/`-m`
- **Module names** for `-m`/`--module`, resolved dynamically from `initora list` (e.g. `system`, `dev-tools`, `desktop`, `optimizations`) — no need to remember module numbers

```bash
initora install -m <TAB>
# system  packages  dev-tools  desktop  optimizations
```

**Installation:**
- **New installs:** handled automatically by `bootstrap.sh` — the script is copied to `~/.local/share/bash-completion/completions/initora`.
- **Existing installs:** applied automatically the next time you run `initora update`, via migration [`0002-bash-completion.sh`](migrations/0002-bash-completion.sh).

In both cases, open a new terminal (or `source ~/.local/share/bash-completion/completions/initora`) to activate it in your current session.

> Requires the `bash-completion` package for the completions directory to be sourced automatically. Most Fedora Workstation installs have it by default; if not, install it with `sudo dnf install bash-completion`.

## 📂 Structure of current repo

```text
.
├── AGENTS.md               # Guide for AI agents working on this repo
├── .agents/                # Detailed architecture and maintenance docs
├── bootstrap.sh            # Main entry point for installation
├── initora                 # CLI entry point for module management
├── initora-default.config  # Default configuration variables
├── utils.sh               # Shared helper functions
├── version                # Project version
├── completions/           # Shell autocomplete scripts
│   └── initora-completion.bash
├── data/                  # Data lists for automated installation
│   ├── flatpak-pkgs.list  # List of Flatpak applications
│   ├── gnome-settings.list # GSettings configuration list
│   └── rpm-pkgs.list      # List of DNF/RPM packages
├── migrations/            # One-shot migration scripts
│   ├── 0001-desktop-entry.sh
│   ├── 0002-bash-completion.sh
│   └── 0003-modern-hardware-cleanup.sh
├── modules/               # Modular setup scripts
│   ├── 00-system.sh
│   └── ...
└── assets/                # Images and resources
    ├── initora.png
    └── wallpaper*.png
```

## 📂 Modular Architecture

Initora is built on a series of specialized scripts located in the `modules/` directory. Each module is **independent and idempotent**, meaning you can run them individually or re-run them safely without side effects.

### [00] System Base ([`00-system.sh`](modules/00-system.sh))
*Core system setup, repository management, and multimedia support.*

**What it does:**
- **DNF Configuration:** Enables parallel package downloads (up to 10 concurrent), activates `fastestmirror` for faster resolution, and sets `defaultyes=True` for unattended installs. Configuration uses DNF5-compatible options only.
- **Repository Management:** Installs RPM Fusion (Free/Non-Free) for multimedia and restricted codecs; removes unwanted repos (PyCharm COPR and Steam). The NVIDIA RPM Fusion repository is kept enabled for hybrid graphics.
- **Multimedia Stack:** Installs comprehensive codec support:
  - **Video codecs:** H.264, H.265, OpenH264 (for Firefox)
  - **Audio codecs:** FLAC, FAAC, AAC, MP3 (LAME)
  - **Hardware acceleration:** Detects the installed GPU and installs the matching VA-API driver:
    - Intel (Broadwell/Gen12+) → `intel-media-driver` (iHD)
    - AMD → `mesa-va-drivers` + `mesa-vdpau-drivers`
    - NVIDIA → `akmod-nvidia`, `xorg-x11-drv-nvidia-cuda`, and `nvidia-vaapi-driver`
  - **Tools:** VLC, FFmpeg (full version from RPM Fusion), GStreamer plugins (base, good, bad, ugly)
- **System Update:** Performs full `dnf upgrade`, removes orphaned packages, and optionally updates firmware (via `fwupdmgr`).
- **Base Packages:** Installs essentials: Git, curl, wget, GnuPG, Flatpak, fontconfig, FZF, GNOME Keyring, PCI utilities, `switcheroo-control`, and OpenSSL.
- **Directory Setup:** Creates project-specific directories (`~/.local/share/initora`, `~/.config/initora`, `~/.cache/initora`).

> **Secure Boot + NVIDIA:** when Secure Boot is enabled, enroll the akmods MOK key (`sudo mokutil --import /etc/pki/akmods/certs/public_key.der`) and reboot before the NVIDIA driver can load.

---

### [10] Packages ([`10-packages.sh`](modules/10-packages.sh))
*Application installation (native and sandboxed) with repository integration.*

**What it does:**
- **Google Chrome:** Installs Chrome stable from the official Google repository for automatic updates.
- **Obsidian:** Downloads the latest AppImage from GitHub, creates a system launcher (`.desktop` entry), and adds to GNOME applications menu.
- **Bitwarden:** Installs both:
  - **GUI** (AppImage) — Full-featured password manager with system integration
  - **CLI** (`bw`) — Command-line tool for scripting and automation
- **VSCode:** Adds the official Microsoft repository and installs VSCode for system-wide updates.
- **Bulk RPM Installation:** Reads `data/rpm-pkgs.list` and installs all packages in batch (20+ categories including development, productivity, graphics, office).
- **Flathub Setup:** Configures Flatpak and the Flathub remote for sandboxed applications.
- **Bulk Flatpak Installation:** Reads `data/flatpak-pkgs.list` and installs Flatpak apps (messaging, media, utilities, GNOME extensions).
- **Font Cache Update:** Refreshes the system font cache after installation.

---

### [20] Dev Tools ([`20-dev-tools.sh`](modules/20-dev-tools.sh))
*The heart of the developer workstation—runtimes, toolchains, containers, and editors.*

**What it does:**

**Runtimes & Language Managers:**
- **SDKMAN:** Installs Java LTS (21) and Java Latest (25), Maven, Gradle, and configures auto-accept for prompts.
- **NVM (Node.js):** Installs Node.js LTS with npm and global packages (typescript, ts-node, prettier, eslint).
- **Rust:** Installs via `rustup` with stable toolchain, Cargo, and automatic PATH setup.
- **Golang:** Downloads the latest stable Go release, installs to `/usr/local/go`, and configures `GOPATH`.

**AI & Developer Tools:**
- **Antigravity CLI:** Google's AI tool (successor to Gemini CLI) with automatic installer.
- **OpenCode:** Binary Go-based AI tool for code generation and analysis.

**Container & Cloud Infrastructure:**
- **Podman:** Rootless configuration with a user socket for IDE integration, Docker aliases, and native overlay storage (no `fuse-overlayfs`).
- **Podman Desktop:** GUI client for container management with AppImage auto-update.
- **AWS CLI v2:** Latest AWS command-line tools for infrastructure management.
- **kubectl:** Kubernetes command-line tool for cluster management.
- **REST Clients:** Postman (AppImage with deep configuration) and Insomnia for API testing.

**Databases & Documentation:**
- **DBeaver Community:** Universal database manager with auto-setup.
- **Draw.io:** Diagramming tool (AppImage).
- **Typora:** Markdown editor with real-time preview (AppImage).

**Terminals & Shells:**
- **Starship:** Ultra-fast cross-shell prompt with a minimalist, low-latency configuration optimized for developers.

**Editors:**
- **Visual Studio Code:** Deep configuration including:
  - Custom `settings.json` for performance tuning (minimap disabled, fontLigatures enabled)
  - Java runtime configuration (supports both Java 21 and 25 via SDKMAN)
  - Terminal integration with Ptyxis and a dynamically resolved Podman socket (`DOCKER_HOST`)
- **Zed:** Modern code editor (install via official script).

---

### [30] Desktop ([`30-desktop.sh`](modules/30-desktop.sh))
*GNOME customization, accessibility, and visual polish.*

**What it does:**

**GNOME Settings:**
- **Theme & Appearance:** Enables dark mode, sets custom GTK/icon themes from configuration.
- **Night Light:** Enables blue-light reduction on a schedule (6:00 PM – 8:00 AM by default).
- **Workspace Management:** Configures fixed 3 workspaces (not dynamic), with keyboard shortcuts for fast navigation (`Super+1/2/3`).
- **Text Scaling:** Applies user-defined text scale for accessibility.
- **Window Buttons:** Custom button layout (`appmenu:minimize,maximize,close`).
- **Sleep Timeouts:** Configures AC power (7200s / 2 hours) and battery (1800s / 30 minutes) sleep timeouts for balanced performance and battery life.

**Terminal Customization:**
- **Ptyxis Profile:** Deep configuration including:
  - Color palette (Tomorrow Night Bright — professional, eye-friendly; customizable)
  - Font (JetBrains Mono 12 by default, customizable)
  - Scrollback history (10,000 lines)
  - Bold-is-bright and login-shell settings
- **Custom Keybindings:**
  - `Super+T` — Open Ptyxis terminal
  - `Super+Print` — Screenshot with annotation (via Gradia Flatpak)
- **Sudo Feedback:** Enables visual feedback when typing `sudo` password (asterisks).

**System Optimization:**
- **LocalSearch:** File indexing is enabled by default (upstream settings), so GNOME search finds files and documents. Set `LOCALSEARCH_ENABLE_FILES=false` to disable it.
- **GNOME Software:** Automatic update checks and downloads are disabled via `gsettings`, without masking system services.

**Visual Assets:**
- **Nerd Fonts:** Downloads and installs 5 monospace Nerd Fonts not already provided by RPM packages:
  - Hack, Meslo, Source Code Pro, Ubuntu Mono, and IBM Plex Mono (Blex Mono)
  - JetBrains Mono, Fira Code, and Cascadia Code come from Fedora RPM packages (`jetbrains-mono-fonts-all`, `fira-code-fonts`, `cascadia-code-fonts`)
  - All fonts include programming ligatures and Unicode glyphs for IDE/terminal use
- **Microsoft Core Fonts:** Arial, Times New Roman, Courier New, etc. (via RPM installer).
- **Wallpaper Collections:** Downloads curated wallpaper collection from GitHub (~100+ high-quality images) if enabled.

---

### [40] Optimizations ([`40-optimizations.sh`](modules/40-optimizations.sh))
*Low-level system and hardware tuning for performance and battery life.*

**What it does:**

**Kernel Parameters (sysctl):**
- **Swap Management:** Sets `swappiness=10` to prefer RAM over ZRAM compression, reducing latency.
- **inotify Limits:** Increases `max_user_watches` to 524,288 — essential for editors and build tools monitoring large projects.
- **Network (Container Workloads):** Increases TCP backlog and enables TCP fast open for containers and Kubernetes.

**Maintenance:**
- **Journal Management:** Limits `systemd-journald` to 1 GB and 10 files to prevent unbounded log growth (`/var/log/journal/`).

> I/O scheduler udev rules, forced `fstrim`, dirty-page ratios, `vfs_cache_pressure`, and `fs.file-max` tuning from older versions were removed. Modern Fedora kernels and `fstrim.timer` already handle these correctly, and the old overrides added risk without measurable benefit.

---

## 🔄 How Modules Are Executed

When you run `initora install`, `initora -ia`, or select modules interactively:

1. Each module is sourced dynamically from `modules/NN-name.sh`
2. The module function (e.g., `module_20_dev_tools`) is executed
3. Logging is performed in real-time to `~/.cache/initora/initora.log`
4. If a module fails, execution stops and the error is logged with a stack trace
5. Modules are **fully idempotent** — re-running them detects existing state and skips redundant operations

## ⚙️ Customization

### Alter User Config
Settings are managed in `~/.config/initora/initora.config`. This file allows you to override any default variable found in [`initora-default.config`](initora-default.config). Use the CLI to edit:
```bash
initora config
```

### Add RPM Package
To add new DNF packages, append them to [`data/rpm-pkgs.list`](data/rpm-pkgs.list). Each line should contain a single package name.

### Add Flatpak Package
To add new Flatpak applications, append them to [`data/flatpak-pkgs.list`](data/flatpak-pkgs.list).

**Format:** `remote app_id` (e.g., `flathub org.mozilla.firefox`)

### GNOME Settings
Custom GNOME settings can be added to [`data/gnome-settings.list`](data/gnome-settings.list).

**Format:** `schema key value` (e.g., `org.gnome.desktop.interface clock-show-date true`)

### Add New Module
Initora's engine is designed for easy extension. To add a new module, create a script in the `modules/` directory following the naming convention `NN-name.sh`.

**Minimal example:**
```bash
#!/usr/bin/env bash
module_50_extras() {
  log_section "Module: Extras"
  # your code here
  log_success "Module 50-extras completed."
}
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/initora-default.config"
  [[ -f "${SETUP_HOME}/.config/initora/initora.config" ]] && \
    source "${SETUP_HOME}/.config/initora/initora.config"
  module_50_extras
fi
```

## 🔄 Migration System

Initora supports database migrations for applying updates between versions. Migrations are stored in the `migrations/` directory and are applied automatically during `initora update`. This allows for seamless feature updates without requiring a full reinstall.

**Current migrations:**
- `0001-desktop-entry.sh` — Adds GNOME application menu integration for existing installations.
- `0002-bash-completion.sh` — Installs bash tab-completion for existing installations (see [Shell Autocomplete](#-shell-autocomplete)).
- `0003-modern-hardware-cleanup.sh` — Removes legacy I/O scheduler udev rules, the `fuse-overlayfs` Podman storage override, and obsolete sysctl keys from older hardware tuning.

## 🔍 Logs & Troubleshooting

Initora maintains a detailed execution log to help you track changes and debug issues.

### Interactive Log Viewer
The easiest way to view and search through logs is using the built-in command:
```bash
initora log
```
This opens the log file in `less`, starting at the most recent entries. Use `j`/`k` to scroll, `/` to search, and `q` to quit.

### View Real-time Logs
Monitor the installation process as it happens:
```bash
tail -f ~/.cache/initora/initora.log
```

### Log Location
The log file is stored at:
`~/.cache/initora/initora.log`

### Debugging Errors
If a module fails, the error handler will print a stack trace both to the terminal and the log file. You can quickly search for errors using:
```bash
grep "ERROR" ~/.cache/initora/initora.log
```

## 🤝 Contributing

Contributions are what make the open-source community an amazing place to learn, inspire, and create. Please refer to our [`CONTRIBUTING.md`](CONTRIBUTING.md) for detailed guidelines on:

- Branch naming conventions (e.g., `feature/`, `fix/`, `release/`)
- Automated versioning and release workflow
- Pull request process

**Quick start:**
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 🔐 Security & Best Practices
- **Root Safety:** Scripts use `sudo` surgically only when necessary.
- **Backup:** Important system files (like `dnf.conf`) are backed up before modification.
- **Non-Intrusive:** Initora respects existing configurations where possible and focuses on adding value rather than forcing changes.

## 📜 License
Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

---

*Maintained by [lucasbt](https://github.com/lucasbt) • Built for the Fedora Community*