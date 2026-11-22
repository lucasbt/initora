#!/usr/bin/env bash
# =============================================================================
# Bash completion for initora
#
# Install:
#   sudo cp initora-completion.bash /etc/bash_completion.d/initora
#   # or, for a single user:
#   mkdir -p ~/.local/share/bash-completion/completions
#   cp initora-completion.bash ~/.local/share/bash-completion/completions/initora
#
# Then reload your shell (or `source` the file directly).
# =============================================================================

_initora_module_ids() {
  # Tries to ask initora itself for the module list and extracts just the
  # bare name (description) of each module, e.g.:
  #
  #   00      00-system               /home/lucas/.../00-system.sh
  #   ->  system
  local out
  out=$(initora list 2>/dev/null) || return
  awk '
    /^[[:space:]]*[0-9]/ {
      name = $2
      sub(/^[0-9]+-/, "", name)
      print name
    }
  ' <<< "$out"
}

_initora_completion() {
  local cur prev words cword
  _init_completion 2>/dev/null || {
    # Fallback for systems without bash-completion's _init_completion helper
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
  }

  local top_commands="install list update uninstall config log help --help -h -i -ia"
  local install_opts="--all -a --module -m"

  # Complete the value right after --module / -m
  case "$prev" in
    --module|-m)
      mapfile -t COMPREPLY < <(compgen -W "$(_initora_module_ids)" -- "$cur")
      return 0
      ;;
  esac

  # Figure out the subcommand (first non-option word) already typed
  local subcmd=""
  local i
  for (( i=1; i<${#words[@]}-1; i++ )); do
    case "${words[i]}" in
      install|-i)
        subcmd="install"
        break
        ;;
    esac
  done

  if [[ "$subcmd" == "install" ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$install_opts" -- "$cur")
    return 0
  fi

  if [[ $cword -eq 1 ]]; then
    mapfile -t COMPREPLY < <(compgen -W "$top_commands" -- "$cur")
    return 0
  fi

  # Default: no more suggestions
  COMPREPLY=()
  return 0
}

complete -F _initora_completion initora
