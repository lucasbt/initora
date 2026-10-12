#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh -- Quick installer for initora
#
# Initora — Fedora Workstation Bootstrap for Developers
# Bootstrap your Developer Fedora Workstation
#
# Usage (as a regular user, not root):
#   curl -fsSL https://raw.githubusercontent.com/lucasbt/initora/main/bootstrap.sh | bash
#   -- or --
#   bash bootstrap.sh
# =============================================================================
set -euo pipefail

REPO_URL="${INITORA_REPO:-https://github.com/lucasbt/initora}"
INSTALL_DIR="${HOME}/.local/share/initora"
BIN_DIR="${HOME}/.local/bin"
BIN_PATH="${BIN_DIR}/initora"
CONFIG_DIR="${HOME}/.config/initora"
CONFIG_FILE="${CONFIG_DIR}/initora.config"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/initora.desktop"
COMPLETION_DIR="${HOME}/.local/share/bash-completion/completions"
COMPLETION_FILE="${COMPLETION_DIR}/initora"

# --- Colors ---
CLR_RESET='\033[0m'
CLR_RED='\033[0;31m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_BLUE='\033[0;34m'
CLR_CYAN='\033[0;36m'
CLR_BOLD='\033[1m'

info()  { echo -e "${CLR_BLUE}[initora] • $*${CLR_RESET}"; }
ok()    { echo -e "${CLR_GREEN}[initora] ✔ $*${CLR_RESET}"; }
warn()  { echo -e "${CLR_YELLOW}[initora] ⚠ $*${CLR_RESET}"; }
err()   { echo -e "${CLR_RED}[initora] ✖ $*${CLR_RESET}" >&2; }

_print_banner() {
  clear
  echo ""
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██╗███╗   ██╗██╗████████╗ ██████╗ ██████╗  █████╗ ${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██║████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗██╔══██╗${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝███████║${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗██╔══██║${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ██║██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║██║  ██║${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_CYAN}  ╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝${CLR_RESET}"
  echo ""
  echo -e "  ${CLR_BOLD}INITORA - Fedora Workstation Bootstrap for Developers${CLR_RESET}"
  echo ""
}

# =============================================================================
# 1. Install required dependencies with user approval
# =============================================================================
_install_deps() {
  local deps=(git curl gum bash-completion)
  local missing=()

  for dep in "${deps[@]}"; do
    command -v "$dep" &>/dev/null || missing+=("$dep")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "All dependencies already satisfied: ${deps[*]}"
    return
  fi

  echo ""
  echo -e "${CLR_BOLD}The following dependencies need to be installed:${CLR_RESET}"
  for pkg in "${missing[@]}"; do
    echo -e "  ${CLR_YELLOW}•${CLR_RESET} $pkg"
  done
  echo ""
  echo -e "  Command that will be executed:"
  echo -e "  ${CLR_BOLD}sudo dnf install -y ${missing[*]}${CLR_RESET}"
  echo ""

  read -rp "$(echo -e "${CLR_BOLD}Install now? [Y/n]:${CLR_RESET} ")" answer </dev/tty || true
  answer="${answer:-Y}"

  if [[ "${answer^^}" != "Y" ]]; then
    err "Dependency installation declined. Aborting."
    exit 1
  fi

  sudo dnf install -y "${missing[@]}" || {
    err "Failed to install dependencies. Check your connection and try again."
    exit 1
  }
  ok "Dependencies installed: ${missing[*]}"
}

# =============================================================================
# 2. Detect execution source and manage clone/update
# =============================================================================
_setup_repo() {
  local script_source
  script_source="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

  if [[ -n "$script_source" && -f "${script_source}/initora" ]]; then
    info "Local clone detected at: $script_source"
    INSTALL_DIR="$script_source"
    return
  fi

  if [[ ! -d "$INSTALL_DIR/.git" ]]; then
    info "Cloning repository to $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
    git -C "$INSTALL_DIR" config core.fileMode false
    ok "Repository cloned"
    return
  fi

  # Ignore file-mode-only diffs (e.g. the chmod +x this script itself applies
  # to initora/utils.sh/modules on every run) so they are never mistaken for
  # local changes on a re-run.
  git -C "$INSTALL_DIR" config core.fileMode false

  local has_local_changes=false
  if ! git -C "$INSTALL_DIR" diff --quiet 2>/dev/null || \
     ! git -C "$INSTALL_DIR" diff --cached --quiet 2>/dev/null; then
    has_local_changes=true
  fi

  if [[ "$has_local_changes" == "true" ]]; then
    echo ""
    warn "Local uncommitted changes detected in:"
    warn " -> $INSTALL_DIR"
    echo ""
    git -C "$INSTALL_DIR" status --short
    echo ""
    echo -e "${CLR_BOLD}What would you like to do?${CLR_RESET}"
    echo -e "  ${CLR_YELLOW}[O]${CLR_RESET} Overwrite -- discard local changes and update from remote"
    echo -e "  ${CLR_YELLOW}[A]${CLR_RESET} Abort    -- keep local changes and cancel bootstrap"
    echo ""
    read -rp "$(echo -e "${CLR_BOLD}Choice [O/A]:${CLR_RESET} ")" answer </dev/tty || true
    answer="${answer:-A}"

    if [[ "${answer^^}" != "O" ]]; then
      warn "Bootstrap aborted. Local changes preserved."
      exit 0
    fi

    info "Discarding local changes and updating from remote..."
    git -C "$INSTALL_DIR" fetch origin
    git -C "$INSTALL_DIR" reset --hard origin/main
    git -C "$INSTALL_DIR" clean -fd
    ok "Repository updated (local changes discarded)"
  else
    info "Updating existing repository in $INSTALL_DIR"
    git -C "$INSTALL_DIR" pull --ff-only
    ok "Repository updated"
  fi
}

# =============================================================================
# 4. Install binary to ~/.local/bin/initora and configure alias
# =============================================================================
_setup_bin_and_alias() {
  chmod +x "${INSTALL_DIR}/initora"
  chmod +x "${INSTALL_DIR}/utils.sh"
  find "${INSTALL_DIR}/modules" -name "*.sh" -exec chmod +x {} \;

  mkdir -p "$BIN_DIR"

  [[ -e "$BIN_PATH" ]] && rm -f "$BIN_PATH"
  ln -s "${INSTALL_DIR}/initora" "$BIN_PATH"
  ok "Binary available at: $BIN_PATH"
}

_setup_default_config() {
  mkdir -p "$CONFIG_DIR"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    cp "${INSTALL_DIR}/initora-default.config" "$CONFIG_FILE"
    ok "Default config created at: $CONFIG_FILE"
  else
    warn "Config already exists at: $CONFIG_FILE -- not overwritten"
  fi
}

# =============================================================================
# 4b. Install bash completion (user-level, no sudo required)
# =============================================================================
_setup_completion() {
  local completion_src="${INSTALL_DIR}/completions/initora-completion.bash"

  if [[ ! -f "$completion_src" ]]; then
    warn "Completion script not found at: $completion_src -- skipping"
    return
  fi

  mkdir -p "$COMPLETION_DIR"
  cp -f "$completion_src" "$COMPLETION_FILE"
  ok "Bash completion installed at: $COMPLETION_FILE"

  if ! rpm -q bash-completion &>/dev/null; then
    warn "Package 'bash-completion' not detected -- completions may not"
    warn "load automatically. Install it with: sudo dnf install bash-completion"
  fi
}

# =============================================================================
# 5. Create .desktop entry so initora shows up in the GNOME menu, launched
#    inside Ptyxis (Fedora Workstation's default terminal)
# =============================================================================
_setup_desktop_entry() {
  if ! command -v ptyxis &>/dev/null; then
    warn "ptyxis not found -- .desktop entry will still be created, but won't launch until ptyxis is installed"
  fi

  local icon_path="${INSTALL_DIR}/assets/initora.png"
  if [[ ! -f "$icon_path" ]]; then
    warn "Icon not found at $icon_path -- falling back to generic icon"
    icon_path="utilities-terminal"
  fi

  mkdir -p "$DESKTOP_DIR"

  cat > "$DESKTOP_FILE" << DESKTOPEOF
[Desktop Entry]
Type=Application
Name=Initora
GenericName=Fedora Workstation Bootstrap
Comment=Bootstrap your Developer Fedora Workstation
Exec=ptyxis --title="Initora - Fedora Workstation Bootstrap for Developers" -x bash -c 'initora; status=$?; echo; if [ "$status" -eq 0 ]; then echo "Initora completed successfully."; else echo "Initora exited with an error (code $status)."; fi; echo; read -n 1 -s -r -p "Press any key to close..."'
Icon=${icon_path}
Terminal=false
Categories=Utility;System;Development;
Keywords=fedora;bootstrap;developer;setup;dev;
StartupNotify=true
DESKTOPEOF

  chmod +x "$DESKTOP_FILE"

  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" &>/dev/null || true
  fi

  ok "Menu entry created: $DESKTOP_FILE"
}

# =============================================================================
# Main
# =============================================================================
main() {
  _print_banner
  _install_deps
  _setup_repo
  _setup_bin_and_alias
  _setup_default_config
  _setup_completion
  _setup_desktop_entry

  echo ""
  ok "Bootstrap completed!"
  echo ""
  echo -e "  Run setup with:"
  echo -e "  ${CLR_GREEN}initora${CLR_RESET}"
  echo ""
  echo -e "  Bash completion installed -- open a new terminal (or run"
  echo -e "  ${CLR_GREEN}source ${COMPLETION_FILE}${CLR_RESET}) to enable it in this session."
  echo ""
}

main "$@"