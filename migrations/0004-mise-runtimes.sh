#!/usr/bin/env bash
# migrations/0004-mise-runtimes.sh
#
# Replaces the shell activation blocks of the legacy version managers with
# mise and Oh My Posh. Directories such as ~/.sdkman, ~/.nvm and ~/.cargo are
# intentionally left untouched: this migration only edits initora-generated
# lines in the user's .bashrc.

migration_0004_mise_runtimes() {
  step "Running migration 0004 - mise runtimes..."

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local bashrc="${user_home}/.bashrc"

  if [[ ! -f "$bashrc" ]]; then
    log_info "No .bashrc found at $bashrc; nothing to migrate."
    return 0
  fi

  backup_file "$bashrc"

  local tmp
  tmp=$(mktemp) || return 1

  # Each legacy block had a fixed number of generated lines. Remove exactly
  # those lines so a user line immediately after a block is never discarded.
  awk '
    /^# SDKMAN -- SDK version manager$/ { skip = 2; next }
    /^# NVM -- Node Version Manager$/ { skip = 3; next }
    /^# Golang$/ { skip = 2; next }
    /^# Rust \/ Cargo$/ { skip = 1; next }
    /^# Starship -- modern dev-focused shell prompt$/ { skip = 1; next }
    skip > 0 { skip--; next }
    { print }
  ' "$bashrc" > "$tmp" || {
    log_error "Failed to rewrite $bashrc"
    rm -f "$tmp"
    return 1
  }

  local uid gid
  uid=$(id -u "$user") || { rm -f "$tmp"; return 1; }
  gid=$(id -gn "$user") || { rm -f "$tmp"; return 1; }

  run_as_root install -o "$uid" -g "$gid" -m 0644 "$tmp" "$bashrc" || {
    log_error "Failed to install migrated $bashrc"
    rm -f "$tmp"
    return 1
  }
  rm -f "$tmp"
  log_success "Legacy runtime activation blocks removed from .bashrc"

  local mise_bin="${user_home}/.local/bin/mise"
  if [[ -x "$mise_bin" ]]; then
    set_user_bashrc_block "mise" "eval \"\$(${mise_bin} activate bash)\""
    log_success "mise activation added to .bashrc"
  else
    log_info "mise is not installed yet; its activation will be added by module 20."
  fi

  if has_cmd oh-my-posh; then
    set_user_bashrc_block "oh-my-posh" \
      'eval "$(oh-my-posh init bash --config pure)"'
    log_success "Oh My Posh activation added to .bashrc"
  fi

  ok "'Migration 0004 - mise runtimes' finished!"
}
