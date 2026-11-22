#!/usr/bin/env bash
# =============================================================================
# modules/30-desktop.sh -- GNOME Desktop Customization and Accessibility
#
# Tasks:
#   - System Settings: Night Light, dark theme, text scaling, and window buttons.
#   - Productivity: Fixed workspaces and custom keybindings.
#   - Terminal: Deep Ptyxis terminal profile configuration (fonts, colors, shell).
#   - Search: LocalSearch file indexing (enabled by default).
#   - Assets: Installs Nerd Fonts, Microsoft fonts, and curated wallpaper collections.
#   - GNOME Extensions: Installs essential tools (Tweaks, Caffeine, AppIndicator).
# =============================================================================

MODULE_NAME="30-desktop"

# -----------------------------------------------------------------------------
# Helper: run command as user with proper GNOME DBus session
# -----------------------------------------------------------------------------
_run_as_user() {
    local user="$1"
    shift

    local uid
    uid=$(id -u "$user")

    sudo -u "$user" \
        XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        "$@"
}

# Font list
# Fonts already provided by RPM packages are not duplicated here:
#   JetBrains Mono -> jetbrains-mono-fonts-all
#   Fira Code      -> fira-code-fonts
#   Cascadia Code  -> cascadia-code-fonts
FONTS=(
  "Hack"
  "Meslo"
  "SourceCodePro"
  "UbuntuMono"
  "IBMPlexMono"    # Blex Mono / IBM Plex Mono (Nerd Fonts asset name)
)

module_30_desktop() {
  log_section "Module: GNOME Desktop and Accessibility"

  _apply_gnome_settings
  _configure_ptyxis_profile
  _configure_localsearch
  _install_wallpapers
  _install_fonts
  _install_microsoft_fonts

  log_success "Module $MODULE_NAME completed."
}

# -----------------------------------------------------------------------------
_apply_gnome_settings() {
  step "Applying GNOME settings"

  local settings_file="${SCRIPT_DIR}/data/gnome-settings.list"
  if [[ ! -f "$settings_file" ]]; then
    log_error "gnome-settings.list not found: $settings_file"
    return 1
  fi

  apply_gnome_settings_file "$settings_file"

  _configure_custom_keybinding

  ok "GNOME settings applied"
}

# -----------------------------------------------------------------------------
_configure_custom_keybinding(){
    step "Apply custom keybindings..."

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys \
      custom-keybindings \
      "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/','/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/']" || true

    # ck0 — Terminal (Ptyxis)
    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      name "Terminal" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      command "ptyxis" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck0/ \
      binding "<Super>t" || true

    # ck1 — Screenshot com annotation via Gradia
    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      name "Gradia Screenshot" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      command "flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE" || true

    _run_as_user "$SETUP_USER" gsettings set \
      org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ck1/ \
      binding "<Super>Print" || true

    ok "Custom keybindings applied"
}

# -----------------------------------------------------------------------------
_configure_ptyxis_profile() {
  step "Configuring Ptyxis terminal profile"

  local user="${SETUP_USER:-$USER}"

  local profile_uuid
  profile_uuid=$(_run_as_user "$user" dconf read /org/gnome/Ptyxis/default-profile-uuid 2>/dev/null | tr -d "'")

  if [[ -z "$profile_uuid" || "$profile_uuid" == "''" ]]; then
    log_warn "No default Ptyxis profile found. Skipping."
    return 0
  fi

  local profile_path="/org/gnome/Ptyxis/Profiles/${profile_uuid}/"
  local schema="org.gnome.Ptyxis.Profile:${profile_path}"

  _ptyxis_set() {
    local key="$1"
    local value="$2"

    gsettings set "$schema" "$key" "$value" 2>/dev/null || \
    _run_as_user "$user" dconf write "${profile_path}${key}" "$value" 2>/dev/null || true
  }

  _ptyxis_set "palette" "'${PTYXIS_PALETTE:-One Half Black}'"
  _ptyxis_set "scrollback-lines" "${PTYXIS_SCROLLBACK_LINES:-10000}"
  _ptyxis_set "opacity" "${PTYXIS_OPACITY:-1.0}"
  _ptyxis_set "bold-is-bright" "${PTYXIS_BOLD_IS_BRIGHT:-true}"
  _ptyxis_set "login-shell" "${PTYXIS_LOGIN_SHELL:-true}"

  if [[ "${PTYXIS_USE_SYSTEM_FONT:-false}" == "false" ]]; then
    _ptyxis_set "font-name" "'${PTYXIS_FONT_NAME:-JetBrains Mono 12}'"
  fi

  sudo grep -q '^Defaults[[:space:]]\+pwfeedback' /etc/sudoers || sudo EDITOR='tee -a' visudo <<< 'Defaults pwfeedback' >> /dev/null

  unset -f _ptyxis_set
  ok "Ptyxis terminal profile configured"
}

# -----------------------------------------------------------------------------
_configure_localsearch() {
    step "Configuring LocalSearch (file indexing)"
    local user="${SETUP_USER:-$USER}"

    if [[ "${LOCALSEARCH_ENABLE_FILES:-true}" == "true" ]]; then
        # Restore upstream defaults so desktop search indexes the home
        # directory again. On modern hardware the background cost is low.
        _run_as_user "$user" gsettings reset \
            org.freedesktop.Tracker3.Miner.Files index-single-directories 2>/dev/null || true
        _run_as_user "$user" gsettings reset \
            org.freedesktop.Tracker3.Miner.Files index-recursive-directories 2>/dev/null || true
        _run_as_user "$user" gsettings reset \
            org.freedesktop.Tracker3.Miner.Files crawling-interval 2>/dev/null || true
        ok "LocalSearch enabled with default indexing"
    else
        _run_as_user "$user" gsettings set \
            org.freedesktop.Tracker3.Miner.Files index-single-directories "[]" 2>/dev/null || true
        _run_as_user "$user" gsettings set \
            org.freedesktop.Tracker3.Miner.Files index-recursive-directories "[]" 2>/dev/null || true
        _run_as_user "$user" gsettings set \
            org.freedesktop.Tracker3.Miner.Files crawling-interval "-2" 2>/dev/null || true
        ok "LocalSearch file indexing disabled"
    fi
}

# -----------------------------------------------------------------------------
_install_wallpapers() {
    step "Installing wallpapers collection"

    [[ "${INSTALL_WALLPAPERS:-false}" == "true" ]] || {
        skip "Wallpaper install disabled in config"
        return
    }

    local collection_dir="${WALLPAPERS_DIR}/collection"
    local archive_url="https://github.com/lucasbt/walls/archive/refs/heads/main.tar.gz"

    if [[ -d "$collection_dir" && -n "$(ls -A "$collection_dir" 2>/dev/null)" ]]; then
        skip "Wallpapers collection already exists"
        return
    fi

    ask_yes_no "The wallpaper download may be very large. Proceed?" "n" || {
        skip "Wallpaper download skipped"
        return
    }

    mkdir -p "$collection_dir"

    log_info "Downloading wallpapers collection..."

    curl -L "$archive_url" --progress-bar | \
        tar -xz \
            --strip-components=2 \
            -C "$collection_dir" \
            walls-main/collection || return 1

    ok "Wallpapers installed to $collection_dir"
}

# -----------------------------------------------------------------------------
_install_fonts() {
    step "Installing Nerd Fonts collection"
    local fonts_nerd_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"
    local cache_dir="${CACHE_DIR:-/tmp}"
    mkdir -p "$cache_dir"

    local fonts_dir="${SETUP_HOME:-$HOME}/.local/share/fonts/nerd-fonts"
    mkdir -p "$fonts_dir"

    # Considera instalado se o diretório existir e não estiver vazio
    if [[ -d "$fonts_dir" && -n "$(ls -A "$fonts_dir" 2>/dev/null)" ]]; then
        skip "Nerd Fonts collection already exists"
        return
    fi

    log_info "Download Nerd Fonts..."
    local font zip_file url
    for font in "${FONTS[@]}"; do
        zip_file="${font}.zip"
        url="${fonts_nerd_url}/${zip_file}"
        log_info "Download $font..."
        curl -fLo "${cache_dir}/${zip_file}" "$url"
        log_info "Extract $font..."
        unzip -o "${cache_dir}/${zip_file}" -d "$fonts_dir" >/dev/null
        rm -f "${cache_dir}/${zip_file}"
    done

    log_info "Updating fonts cache..."
    fc-cache -f >/dev/null

    ok "Nerd Fonts installed to $fonts_dir"
}

# -----------------------------------------------------------------------------
_install_microsoft_fonts() {
    step "Installing Microsoft core fonts"
    if [[ "${INSTALL_MICROSOFT_FONTS:-true}" != "true" ]]; then
        skip "Microsoft fonts install disabled in config"
        return
    fi    
 
    local sentinel="/usr/share/fonts/msttcore/arial.ttf"
    if [[ -f "$sentinel" ]]; then
        skip "Microsoft fonts already installed"
        return
    fi
 
    local installer_url="https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm"
    local installer_rpm="${CACHE_DIR}/msttcore-fonts-installer.rpm"
 
    dnf_install cabextract
 
    log_info "Downloading msttcore-fonts-installer..."
    if curl -fsSL --retry 3 --retry-delay 5 --max-time 60 \
            -o "$installer_rpm" "$installer_url"; then
        sudo rpm -i --nosignature --nodigest "$installer_rpm" && \
            sudo fc-cache -f /usr/share/fonts/msttcore 2>/dev/null || true
        rm -f "$installer_rpm"
        ok "Microsoft fonts installed"
    else
        rm -f "$installer_rpm" 2>/dev/null || true
        log_warn "Could not download Microsoft fonts after 3 attempts"
        log_warn "To install manually later:"
        log_warn "  sudo dnf install cabextract xorg-x11-font-utils"
        log_warn "  sudo rpm -i --nosignature --nodigest '$installer_url'"
    fi
}

# -----------------------------------------------------------------------------
# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  source "${SCRIPT_DIR}/utils.sh"

  # Exporta automaticamente todas as variáveis carregadas
  set -a
  source "${SCRIPT_DIR}/initora-default.config"
  [[ -f "${SETUP_HOME}/.config/initora/initora.config" ]] && \
    source "${SETUP_HOME}/.config/initora/initora.config"
  set +a

  module_30_desktop
fi