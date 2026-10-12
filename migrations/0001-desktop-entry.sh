#!/usr/bin/env bash
# migrations/0001-desktop-entry.sh
#
# Adds the .desktop entry (GNOME menu launcher via Ptyxis) for users who
# installed initora before this feature existed. New installs already get
# this from bootstrap.sh's _setup_desktop_entry(); this migration brings
# existing installs up to the same state.

migration_0001_desktop_entry() {
  step "Running migration 0001 - Initora Desktop Entry creation..."

  local desktop_dir="${SETUP_HOME}/.local/share/applications"
  local desktop_file="${desktop_dir}/initora.desktop"

  if ! has_cmd ptyxis; then
    log_warn "ptyxis not found -- .desktop entry will still be created, but won't launch until ptyxis is installed"
  fi

  local icon_path="${SCRIPT_DIR}/assets/initora.png"
  if [[ ! -f "$icon_path" ]]; then
    log_warn "Icon not found at $icon_path -- falling back to generic icon"
    icon_path="utilities-terminal"
  fi

  mkdir -p "$desktop_dir"

  cat > "$desktop_file" << DESKTOPEOF
[Desktop Entry]
Type=Application
Name=Initora
GenericName=Fedora Workstation Bootstrap
Comment=Bootstrap your Developer Fedora Workstation
Exec=ptyxis --title="Initora - Fedora Workstation Bootstrap for Developers" -- bash -c '(initora); read -p "Press Enter to close..."'
Icon=${icon_path}
Terminal=false
Categories=Utility;System;Development;
Keywords=fedora;bootstrap;developer;setup;dev;
StartupNotify=true
DESKTOPEOF

  chmod +x "$desktop_file"

  if has_cmd update-desktop-database; then
    update-desktop-database "$desktop_dir" &>/dev/null || true
  fi

  log_success "Menu entry created: $desktop_file"

  ok "'Migration 0001 - Initora Desktop Entry creation' finished!"
}
