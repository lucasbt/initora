#!/usr/bin/env bash
# =============================================================================
# utils.sh — Global utility functions for initora
# =============================================================================
# Usage: source utils.sh
# =============================================================================

# --- Colors ---
CLR_RESET='\033[0m'
CLR_RED='\033[0;31m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_BLUE='\033[0;34m'
CLR_CYAN='\033[0;36m'
CLR_MAGENTA='\033[0;35m'
CLR_ORANGE='\033[38;5;208m'
CLR_BOLD='\033[1m'
CLR_DIM="\e[2m"

_UTILS_LOADED=true

# =============================================================================
# Logging
# =============================================================================
_LABEL_WIDTH=5

LOG_FILE="${HOME}/.cache/initora/initora.log"
mkdir -p "$(dirname "$LOG_FILE")"

_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

_term_line() {
  local color="$1"; shift
  local icon="$1"; shift
  local label="$1"; shift
  local msg="$*"

  printf "%b%s %-*s %s%b\n" \
    "$color" "$icon" "$_LABEL_WIDTH" "$label" "$msg" "$CLR_RESET"
}

_log_file() {
  local level="$1"; shift
  local msg="$*"

  [[ -z "$LOG_FILE" ]] && return 0

  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0

  printf "[%s] %-5s %s\n" "$(_timestamp)" "$level" "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# Log (técnico)
# =============================================================================

log_info() {
  _log_file "INFO" "$*"
  _term_line "$CLR_DIM" "●" "INFO" "$*"
}

log_success() {
  _log_file "DONE" "$*"
  _term_line "$CLR_GREEN" "✔" "DONE" "$*"
}

log_warn() {
  _log_file "WARN" "$*"
  _term_line "$CLR_ORANGE" "▲" "WARN" "$*"
}

log_error() {
  _log_file "ERROR" "$*"
  _term_line "$CLR_RED" "✖" "ERROR" "$*"
}

log_section() {
  local msg="$*"

  # terminal
  echo ""
  echo -e "${CLR_BOLD}${CLR_BLUE}═════════════════════════════════════════════${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_BLUE}  ● ${msg}${CLR_RESET}"
  echo -e "${CLR_BOLD}${CLR_BLUE}═════════════════════════════════════════════${CLR_RESET}"

  # arquivo
  {
    echo ""
    printf "[%s] ==========================================\n" "$(_timestamp)"
    printf "[%s]   %s\n" "$(_timestamp)" "$msg"
    printf "[%s] ==========================================\n" "$(_timestamp)"
  } >> "$LOG_FILE"
}

# =============================================================================
# Progress
# =============================================================================

step() {
  echo ""
  _log_file "STEP" "$*"
  _term_line "$CLR_BOLD$CLR_MAGENTA" "▶" "STEP" "$*"
}

ok() {
  _log_file "OK" "$*"
  _term_line "$CLR_BOLD$CLR_GREEN" "✔" "OK" "$*"
}

skip() {
  _log_file "SKIP" "$*"
  _term_line "$CLR_BOLD$CLR_CYAN" "⏭" "SKIP" "$*"
}

# =============================================================================
# Privilege helpers
# =============================================================================

# Require root — re-executes the current script with sudo if not already root.
# Passes SETUP_USER and SETUP_HOME so the real user identity is preserved.
require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_info "Root access required. Re-running with sudo..."
    exec sudo \
      SETUP_USER="$SETUP_USER" \
      SETUP_HOME="$SETUP_HOME" \
      LOG_FILE="$LOG_FILE" \
      "$0" "$@"
  fi
}

is_root() { [[ $EUID -eq 0 ]]; }

# Runs a command with sudo only when not already root.
# Usage: run_as_root <command> [args...]
run_as_root() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

# =============================================================================
# Checks
# =============================================================================

# Check whether an RPM package from a .rpm file is installed
is_rpm_installed() {
  local rpm_file="$1"

  local package_name
  package_name=$(rpm -qp --queryformat '%{NAME}\n' "$rpm_file" 2>/dev/null)

  rpm -q "$package_name" &>/dev/null
}

# Check whether a Flatpak app is installed
is_flatpak_installed() {
  flatpak list --app --columns=application 2>/dev/null | grep -qx "$1"
}

# Check whether a binary is available in PATH
has_cmd() {
  command -v "$1" &>/dev/null
}

# Check whether a systemd unit is enabled
is_service_enabled() {
  systemctl is-enabled "$1" &>/dev/null
}

# Check whether a systemd unit is active (running)
is_service_active() {
  systemctl is-active "$1" &>/dev/null
}

# =============================================================================
# DNF helpers
# =============================================================================

# Install RPM packages, skipping those already present
dnf_install() {
  local to_install=()
  for pkg in "$@"; do
    if ! is_rpm_installed "$pkg"; then
      to_install+=("$pkg")
    else
      log_info "Package already installed: $pkg"
    fi
  done
  if [[ ${#to_install[@]} -gt 0 ]]; then
    log_info "Installing RPMs: ${to_install[*]}"
    run_as_root dnf install -y --skip-broken --allowerasing --skip-unavailable "${to_install[@]}"
  fi
}

# Remove RPM packages, skipping those not installed
dnf_remove() {
  local to_remove=()
  for pkg in "$@"; do
    if is_rpm_installed "$pkg"; then
      to_remove+=("$pkg")
    fi
  done
  if [[ ${#to_remove[@]} -gt 0 ]]; then
    log_info "Removing packages: ${to_remove[*]}"
    run_as_root dnf remove -y "${to_remove[@]}"
  fi
}

# Enable a COPR repository if not already enabled
dnf_copr_enable() {
  local repo="$1"
  if ! dnf copr list --enabled 2>/dev/null | grep -q "$repo"; then
    log_info "Enabling COPR: $repo"
    run_as_root dnf copr enable -y "$repo"
  else
    log_info "COPR already enabled: $repo"
  fi
}

# Add a DNF repository from a repofile URL if not already present
dnf_repo_add() {
  local repo_id="$1"
  local repo_url="$2"
  if ! dnf repolist --enabled 2>/dev/null | grep -q "^${repo_id}"; then
    log_info "Adding DNF repository: $repo_id"
    run_as_root dnf config-manager addrepo --from-repofile="$repo_url"
  else
    log_info "Repository already present: $repo_id"
  fi
}

# =============================================================================
# Flatpak helpers
# =============================================================================

# Install a Flatpak app if not already installed
flatpak_install() {
  local remote="${1}"
  local app="${2}"
  if ! is_flatpak_installed "$app"; then
    log_info "Installing Flatpak: $app"
    flatpak install -y --noninteractive "$remote" "$app"
  else
    log_info "Flatpak already installed: $app"
  fi
}

# =============================================================================
# GSettings helper
# Usage: gs_set "schema" "key" "value"
# =============================================================================
gs_set() {
  local schema="$1"
  local key="$2"
  local value="$3"
  local user="${SETUP_USER:-$USER}"

  local user_id
  user_id=$(id -u "$user")

  sudo -u "$user" \
    XDG_RUNTIME_DIR="/run/user/$user_id" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$user_id/bus" \
    gsettings set "$schema" "$key" "$value" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    log_success "gsettings: [$schema] $key = $value"
  else
    log_warn "gsettings failed: [$schema] $key = $value"
  fi
}

# Apply all entries from gnome-settings.list.
# File format: schema key value
# Values support ${VAR} references from initora-default.config (expanded via envsubst).
apply_gnome_settings_file() {
  local settings_file="$1"
  local user="${SETUP_USER:-$USER}"

  [[ ! -f "$settings_file" ]] && {
    log_error "Settings file not found: $settings_file"
    return 1
  }

  log_info "Applying GNOME settings from: $settings_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Expande variáveis mas preserva aspas
    expanded=$(eval "echo \"$line\"")

    # Divide apenas nos DOIS primeiros campos
    schema="${expanded%% *}"
    rest="${expanded#"$schema "}"
    key="${rest%% *}"
    value="${rest#"$key "}"

    [[ -z "$schema" || -z "$key" || -z "$value" ]] && continue

    gs_set "$schema" "$key" "$value"

  done < "$settings_file"
}

# =============================================================================
# sysctl helper
# =============================================================================

sysctl_set() {
  local key="$1"
  local value="$2"
  local conf_file="${3:-/etc/sysctl.d/99-initora.conf}"
  sed -i "/^${key}/d" "$conf_file" 2>/dev/null || true
  echo "${key} = ${value}" >> "$conf_file"
  sysctl -w "${key}=${value}" &>/dev/null || true
  log_success "sysctl: $key = $value"
}

# =============================================================================
# File helpers
# =============================================================================

# Ensure a line exists in a file (idempotent)
ensure_line() {
  local line="$1"
  local file="$2"
  grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# Replace a managed block in the target user's .bashrc.
# Usage: set_user_bashrc_block <marker> <content> [bashrc]
# An empty content removes the block. User-owned lines are preserved.
set_user_bashrc_block() {
    local marker="$1"
    local content="${2:-}"
    local bashrc="${3:-${SETUP_HOME:-$HOME}/.bashrc}"
    local user="${SETUP_USER:-$USER}"
    local tmp uid gid rc

    tmp=$(mktemp) || return 1

    if [[ -f "$bashrc" ]]; then
        awk -v start="# >>> initora: ${marker}" \
            -v end="# <<< initora: ${marker}" '
            $0 == start { skipping = 1; next }
            skipping && $0 == end { skipping = 0; next }
            !skipping { print }
        ' "$bashrc" > "$tmp" || true
    fi

    if [[ -n "$content" ]]; then
        {
            printf '# >>> initora: %s\n' "$marker"
            printf '%s\n' "$content"
            printf '# <<< initora: %s\n' "$marker"
        } >> "$tmp"
    fi

    uid=$(id -u "$user") || { rm -f "$tmp"; return 1; }
    gid=$(id -gn "$user") || { rm -f "$tmp"; return 1; }

    run_as_root install -o "$uid" -g "$gid" -m 0644 "$tmp" "$bashrc"
    rc=$?
    rm -f "$tmp"
    return "$rc"
}

# Create a timestamped backup of a file
backup_file() {
  local file="$1"

  [[ -f "$file" ]] || return 0

  sudo cp "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"
}

cached_download() {
    local url="$1"
    local output="$2"

    if [ ! -f "$output" ]; then
        log_info "Downloading $(basename "$output")"
        curl -L "$url" -o "$output"
    else
        log_info "Using cached $(basename "$output")"
    fi
}

# -----------------------------------------------------------------------------
# ask_yes_no "Question?" "default"
# default: "y" | "n" (optional, defaults to "n" if omitted)
# Returns 0 (true) for yes, 1 (false) for no
# If stdin is not a terminal (non-interactive), returns the default silently
# -----------------------------------------------------------------------------
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"
    local prompt answer

    # Definir prompt visual baseado no default
    if [[ "${default,,}" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    # Modo não-interativo (pipe, CI, script sem TTY) — aplica o default silenciosamente
    if [[ ! -t 0 ]]; then
        log_warn "$question $prompt → non-interactive, defaulting to: $default"
        [[ "${default,,}" == "y" ]] && return 0 || return 1
    fi

    # Timeout de 30s — se não responder, aplica o default
    while true; do
        echo -en "\n${CLR_YELLOW}?${CLR_RESET} $question $prompt " >&2
        if ! read -r -t 30 answer; then
            echo >&2
            log_warn "No response after 30s — defaulting to: $default"
            [[ "${default,,}" == "y" ]] && return 0 || return 1
        fi

        # Enter sem digitar nada = aceitar default
        if [[ -z "$answer" ]]; then
            answer="$default"
        fi

        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)
                echo -e "${CLR_YELLOW}  Please answer y or n.${CLR_RESET}" >&2
                ;;
        esac
    done
}

get_installed_version() {
    local pkg="$1"
    local version

    version=$(rpm -q --qf '%{VERSION}\n' "$pkg" 2>/dev/null) || return 1

    printf '%s\n' "$version" | head -n1
}

version_ge() {
    local current="$1"
    local target="$2"

    [[ -z "$current" || -z "$target" ]] && return 1

    [[ "$(printf '%s\n%s\n' "$current" "$target" | sort -V | tail -n1)" == "$current" ]]
}
