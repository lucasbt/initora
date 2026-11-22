#!/usr/bin/env bash
# =============================================================================
# modules/20-dev-tools.sh -- Development Environments and Toolchains
#
# Tasks:
#   - Runtimes: mise for Java, Node.js, Python, Go, Rust, Maven, and Gradle.
#   - AI Tools: Antigravity CLI/Desktop, OpenCode CLI/Desktop.
#   - Containers: Podman configuration, Docker alias, and Podman Desktop.
#   - Cloud/Infra: AWS CLI v2, kubectl, and REST clients (Bruno, Insomnia).
#   - Database/Docs: DBeaver Community, Draw.io, and Typora.
#   - Mobile: KVM, Android Studio, Flutter, and Android SDK environment.
#   - Editor Configuration: VSCode settings and toolchain integration.
#   - Shell: Oh My Posh with the "pure" theme.
# =============================================================================

MODULE_NAME="20-dev-tools"

module_20_dev_tools() {
  log_section "Module: Development Tools"

  # ── 1. Build dependencies
  log_info "Installing build dependencies..."
  dnf_install \
    gcc gcc-c++ make clang cmake ninja-build \
    openssl-devel bzip2-devel libffi-devel zlib-devel \
    sqlite-devel readline-devel \
    xz-devel tk-devel \
    libuuid-devel \
    gtk3-devel

  # ── 2. Version control (other steps may clone repositories)
  _install_git

  # ── 3. Runtimes (mise replaces SDKMAN, NVM, rustup, and manual Go)
  _install_mise
  _install_mise_runtimes

  # ── 4. Container infrastructure
  _configure_podman
  _install_podman_desktop

  # ── 5. Editors
  _install_editors

  # ── 6. Infrastructure CLIs
  _install_kubectl
  _install_awscli

  # ── 7. REST clients
  _install_insomnia
  _install_bruno

  # ── 8. GUI utilities
  _install_dbeaver
  _install_drawio
  _install_typora

  # ── 9. Mobile development
  _configure_kvm
  _install_android_studio
  _configure_android_env
  _install_flutter

  # ── 10. Shell prompt
  _install_oh_my_posh

  # ── 11. AI tools
  _install_ai_cli_tools
  _install_opencode_desktop
  _install_antigravity_apps

  log_success "Module $MODULE_NAME completed."
}

# =============================================================================
# 2. Controle de versão
# =============================================================================

_install_git() {
    step "Installing Git"
    dnf_install git git-lfs git-delta meld
    git config --global credential.helper 'cache --timeout=14400000'
    ok "Git installed and configured"
}


# =============================================================================
# 3. Runtimes — mise
# =============================================================================

_install_mise() {
  if [[ "${INSTALL_MISE:-true}" != "true" ]]; then
    skip "mise disabled in config"
    return
  fi

  step "Installing mise (unified version manager)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local mise_bin="${user_home}/.local/bin/mise"

  if [[ -x "$mise_bin" ]]; then
    skip "mise already installed: $("$mise_bin" --version 2>/dev/null | head -n1)"
  else
    sudo -u "$user" mkdir -p "$(dirname "$mise_bin")"
    sudo -u "$user" env HOME="$user_home" MISE_INSTALL_PATH="$mise_bin" \
      bash -c 'curl -fsSL https://mise.run | sh' || {
        log_error "Failed to install mise"
        return 1
      }

    [[ -x "$mise_bin" ]] || {
      log_error "mise binary not found at $mise_bin after installation"
      return 1
    }
    ok "mise installed at $mise_bin"
  fi

  local activation="eval \"\$(${mise_bin} activate bash)\""
  set_user_bashrc_block "mise" "$activation"
  ok "mise activation configured in .bashrc"
}

_install_mise_runtimes() {
  if [[ "${INSTALL_MISE:-true}" != "true" ]]; then
    skip "mise runtimes disabled in config"
    return
  fi

  step "Installing runtimes with mise (may take a while on first run)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local mise_bin="${user_home}/.local/bin/mise"

  if [[ ! -x "$mise_bin" ]]; then
    log_error "mise not found at $mise_bin; run _install_mise first"
    return 1
  fi

  local java_version node_version python_version go_version rust_version
  java_version="${MISE_JAVA_VERSION:-lts}"
  node_version="${MISE_NODE_VERSION:-lts}"
  python_version="${MISE_PYTHON_VERSION:-latest}"
  go_version="${MISE_GO_VERSION:-latest}"
  rust_version="${MISE_RUST_VERSION:-latest}"

  log_info "Java:   ${java_version}"
  log_info "Node:   ${node_version}"
  log_info "Python: ${python_version}"
  log_info "Go:     ${go_version}"
  log_info "Rust:   ${rust_version}"

  sudo -u "$user" env HOME="$user_home" "$mise_bin" use --global \
    "java@${java_version}" \
    "node@${node_version}" \
    "python@${python_version}" \
    "go@${go_version}" \
    "rust@${rust_version}" || {
      log_error "Failed to install runtimes with mise"
      return 1
    }

  sudo -u "$user" env HOME="$user_home" "$mise_bin" use --global \
    maven@latest gradle@latest || \
    log_warn "Maven/Gradle could not be installed with mise — continuing."

  sudo -u "$user" env HOME="$user_home" "$mise_bin" exec -- \
    corepack enable || log_warn "corepack enable failed — continuing."

  log_info "Installing global npm packages..."
  sudo -u "$user" env HOME="$user_home" "$mise_bin" exec -- \
    npm install -g npm@latest typescript ts-node prettier eslint || \
    log_warn "Some npm packages failed to install — continuing."

  sudo -u "$user" env HOME="$user_home" "$mise_bin" exec -- sh -c '
    echo "Java:   $(java -version 2>&1 | head -n1)"
    echo "Node:   $(node --version 2>/dev/null || echo not-found)"
    echo "Python: $(python3 --version 2>/dev/null || echo not-found)"
    echo "Go:     $(go version 2>/dev/null || echo not-found)"
    echo "Rust:   $(rustc --version 2>/dev/null || echo not-found)"
  ' || true

  ok "mise runtimes installed"
}

# =============================================================================
# 4. AI CLI tools
# =============================================================================
 
# Agregador — ponto único de entrada para os dois instaladores
_install_ai_cli_tools() {
  _install_antigravity_cli
  _install_opencode
}
 
# ── Antigravity (via curl/bash script) ────────────────────────────────────────

_install_antigravity_cli() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"

  step "Installing/Updating Antigravity"

  # Executa a instalação no contexto do usuário correto
  sudo -u "$user" bash -c '
    CURRENT=$(antigravity --version 2>/dev/null || echo "none")
    echo "Current version: $CURRENT"
    echo "Fetching and running installer..."

    # Executa o instalador oficial do Antigravity
    curl -fsSL https://antigravity.google/cli/install.sh | bash
  ' || {
    log_error "Failed to install/update Antigravity"
    return 1
  }

  ok "Antigravity CLI ready"
}

# ── OpenCode (binário Go via script oficial) ──────────────────────────────────
_install_opencode() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local install_dir="${user_home}/.opencode/bin"
  local binary="${install_dir}/opencode"
  local bin_dir="${BIN_DIR:-${user_home}/.local/bin}"
  local symlink="${bin_dir}/opencode"

  step "Installing OpenCode"

  if sudo -u "$user" bash -c "[[ -x \"$binary\" ]]"; then
    CURRENT=$($binary --version 2>/dev/null || echo "none")

    log_info "OpenCode installed: $CURRENT"
    log_info "Checking updates..."

    sudo -u "$user" "$binary" upgrade --check 2>/dev/null || true
    sudo -u "$user" "$binary" upgrade 2>/dev/null || true

    return 0
  fi

  log_info "Downloading OpenCode installer..."

  sudo -u "$user" bash -c "curl -fsSL https://opencode.ai/install | bash" || {
    log_error "Failed to install OpenCode"
    return 1
  }

  mkdir -p "$bin_dir"
  ln -sf "$binary" "$symlink"

  ok "OpenCode installed"
}

# =============================================================================
# 5. Infraestrutura de containers
# =============================================================================

_configure_podman() {
  step "Configuring Podman"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"

  dnf_install podman podman-compose podman-docker buildah skopeo containers-common

  # Add docker=podman alias for developer convenience
  if [[ "${PODMAN_DOCKER_ALIAS:-true}" == "true" ]]; then
    local bashrc="${user_home}/.bashrc"
    if ! grep -qF 'alias docker=podman' "$bashrc" 2>/dev/null; then
      cat >> "$bashrc" << 'PODMANEOF'

# Podman as a Docker drop-in replacement
alias docker=podman
alias docker-compose='podman compose'
PODMANEOF
      ok "docker=podman alias added to .bashrc"
    else
      skip "docker=podman alias already present"
    fi
  fi

  # Enable Podman socket for tools that expect /var/run/docker.sock.
  # XDG_RUNTIME_DIR is required for `systemctl --user` when running via sudo.
  local user_uid xdg_runtime_dir
  user_uid=$(id -u "$user")
  xdg_runtime_dir="/run/user/${user_uid}"

  if ! sudo -u "$user" XDG_RUNTIME_DIR="$xdg_runtime_dir" \
      systemctl --user is-enabled podman.socket &>/dev/null; then
    loginctl enable-linger "$user" 2>/dev/null || true
    sudo -u "$user" XDG_RUNTIME_DIR="$xdg_runtime_dir" \
      systemctl --user enable --now podman.socket 2>/dev/null || true
    log_info "Podman socket enabled for user $user"
  fi

  sudo mkdir -p /etc/containers/registries.conf.d
  sudo tee /etc/containers/registries.conf.d/99-dev.conf > /dev/null << 'EOF'
[[registry]]
prefix   = "docker.io"
location = "docker.io"

[[registry]]
prefix   = "ghcr.io"
location = "ghcr.io"

[[registry]]
prefix   = "quay.io"
location = "quay.io"
EOF

  # Rootless Podman uses the native overlay driver on modern kernels.
  # fuse-overlayfs and a custom storage.conf are unnecessary and can
  # degrade performance, so no storage configuration is written here.

  ok "Podman installed and configured"
}

# -----------------------------------------------------------------------------
_install_podman_desktop() {
    if [[ "${INSTALL_PODMAN_DESKTOP:-true}" != "true" ]]; then
        skip "Podman Desktop install disabled in config"
        return
    fi

    step "Installing Podman Desktop"

    local install_dir="${PODMAN_DESKTOP_INSTALL_DIR:-/opt/podman-desktop}"
    local desktop_dir="/usr/local/share/applications"
    local icon_dir="/usr/local/share/icons"
    local symlink="/usr/local/bin/podman-desktop"

    if [[ -L "$symlink" && -x "$(readlink -f "$symlink")" ]]; then
        skip "Podman Desktop already installed"
        return
    fi

    log_info "Fetching latest Podman Desktop release..."

    local api_response
    if ! api_response=$(
        curl -fsSL --retry 3 --retry-delay 3 --max-time 15 \
            "https://api.github.com/repos/podman-desktop/podman-desktop/releases/latest"
    ); then
        log_error "Could not reach GitHub API"
        return 1
    fi

    if [[ -z "$api_response" ]]; then
        log_error "GitHub API returned empty response"
        return 1
    fi

    # -------------------------------------------------------------------------
    # Resolve versão e asset via jq (robusto contra pipefail)
    # -------------------------------------------------------------------------
    if ! command -v jq >/dev/null 2>&1; then
        log_error "'jq' is required but not installed"
        return 1
    fi

    local latest_tag
    latest_tag="$(jq -r '.tag_name // empty' <<< "$api_response")"

    local tarball_url
    tarball_url="$(
        jq -r '
            .assets[]
            | .browser_download_url
            | select(test("\\.tar\\.gz$"))
            | select(test("arm64") | not)
        ' <<< "$api_response" \
        | head -1 \
        || true
    )"

    if [[ -z "$latest_tag" || -z "$tarball_url" ]]; then
        log_error "Could not resolve Podman Desktop download URL"
        return 1
    fi

    local version="${latest_tag#v}"
    local tarball="${CACHE_DIR}/podman-desktop-${version}.tar.gz"

    log_info "Latest version: ${version}"
    log_info "Asset: $(basename "$tarball_url")"

    # -------------------------------------------------------------------------
    # Download
    # -------------------------------------------------------------------------
    log_info "Downloading Podman Desktop..."

    if ! curl -fsSL \
        --retry 3 \
        --retry-delay 5 \
        --max-time 300 \
        --progress-bar \
        "$tarball_url" \
        -o "$tarball"; then

        log_error "Failed to download Podman Desktop"
        rm -f "$tarball"
        return 1
    fi

    # -------------------------------------------------------------------------
    # Valida tarball
    # -------------------------------------------------------------------------
    if ! tar -tzf "$tarball" >/dev/null 2>&1; then
        log_error "Downloaded tarball is invalid"
        rm -f "$tarball"
        return 1
    fi

    sudo mkdir -p "$install_dir"

    log_info "Extracting to ${install_dir}..."

    if ! sudo tar -xzf "$tarball" \
        --strip-components=1 \
        -C "$install_dir"; then

        log_error "Failed to extract Podman Desktop"
        rm -f "$tarball"
        return 1
    fi

    rm -f "$tarball"

    # -------------------------------------------------------------------------
    # Localiza binário principal
    # -------------------------------------------------------------------------
    local binary
    binary="$(
        find "$install_dir" \
            -maxdepth 2 \
            -type f \
            -name "podman-desktop" \
            | head -1 \
            || true
    )"

    if [[ -z "$binary" ]]; then
        log_error "Could not find 'podman-desktop' binary in ${install_dir}"

        log_info "Files extracted:"
        find "$install_dir" -maxdepth 2 -type f | sed 's/^/  - /'

        return 1
    fi

    sudo chmod +x "$binary"
    sudo ln -sf "$binary" "$symlink"

    log_info "Symlink created: $symlink → $binary"

    # -------------------------------------------------------------------------
    # Ícone
    # -------------------------------------------------------------------------
    sudo mkdir -p "$icon_dir"

    local icon_path="${icon_dir}/podman-desktop.png"

    local bundled_icon
    bundled_icon="$(
        find "$install_dir" -maxdepth 3 \
            \( -iname "*icon*" -o -iname "*logo*" -o -iname "*podman*" \) \
            \( -name "*.png" -o -name "*.svg" \) \
            | head -1 \
            || true
    )"

    if [[ -n "$bundled_icon" ]]; then
        sudo cp "$bundled_icon" "$icon_path"

        log_info "Icon copied from bundle: $(basename "$bundled_icon")"
    else
        log_info "Bundled icon not found, downloading fallback icon..."

        if ! sudo curl -fsSL \
            --max-time 10 \
            "https://raw.githubusercontent.com/podman-desktop/podman-desktop/main/buildResources/icon.png" \
            -o "$icon_path"; then

            log_warn "Failed to download icon, using generic icon name"
            icon_path="podman-desktop"
        fi
    fi

    # -------------------------------------------------------------------------
    # Desktop entry
    # -------------------------------------------------------------------------
    sudo mkdir -p "$desktop_dir"

    sudo tee "${desktop_dir}/podman-desktop.desktop" > /dev/null << EOF
[Desktop Entry]
Name=Podman Desktop
Comment=Manage containers and Kubernetes with Podman
Exec=${binary} %U
Icon=${icon_path}
Terminal=false
Type=Application
Categories=Development;System;
StartupWMClass=Podman Desktop
EOF

    update-desktop-database "$desktop_dir" 2>/dev/null || true

    ok "Podman Desktop ${version} installed → ${binary}"
}


# =============================================================================
# 6. Editores
# =============================================================================

_install_editors() {
  step "Installing editors"

  # Zed
  local zed_bin="$SETUP_HOME/.local/bin/zed"

  if [[ -x "$zed_bin" ]] || command -v zed &>/dev/null; then
      skip "Zed already installed"
  else
      step "Installing Zed editor"
      curl -fsSL https://zed.dev/install.sh | sh || {
          log_error "Failed to install Zed"
          return 1
      }
      ok "Zed installed"
  fi

  _configure_vscode
  
}

_configure_vscode() {
  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local user_uid
  user_uid=$(id -u "$user")
  local settings_dir="${user_home}/.config/Code/User"
  local mise_bin="${user_home}/.local/bin/mise"
  local java_home=""

  step "Configuring VS Code (extensions + settings)"

  # ── Dependency: VS Code must be callable as 'code'
  if ! command -v code &>/dev/null; then
    log_warn "VS Code ('code') not found in PATH — skipping configuration"
    return
  fi

  # ── Detect the active Java home managed by mise
  if [[ -x "$mise_bin" ]]; then
    local java_bin
    java_bin=$(sudo -u "$user" env HOME="$user_home" "$mise_bin" which java 2>/dev/null || true)
    if [[ -n "$java_bin" ]]; then
      java_home=$(dirname "$(dirname "$java_bin")")
      log_info "Java home: ${java_home}"
    fi
  fi

  # ── settings.json (variables are expanded here, hence the unquoted delimiter)
  sudo -u "$user" mkdir -p "$settings_dir"
  sudo -u "$user" tee "${settings_dir}/settings.json" > /dev/null << VSCODE_SETTINGS
{
  "workbench.startupEditor": "none",
  "workbench.editor.enablePreview": false,
  "workbench.list.smoothScrolling": false,
 
  "editor.fontFamily": "'JetBrains Mono', 'Fira Code', monospace",
  "editor.fontSize": 14,
  "editor.fontLigatures": true,
  "editor.minimap.enabled": false,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": "active",
  "diffEditor.ignoreTrimWhitespace": true,
  "search.exclude": {
    "**/node_modules": true,
    "**/target": true,
    "**/build": true,
    "**/.gradle": true,
    "**/.git": true
  },
  "files.watcherExclude": {
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/node_modules/**": true,
    "**/target/**": true,
    "**/build/**": true
  },
 
  "editor.formatOnSave": true,
  "editor.formatOnPaste": false,
  "editor.tabSize": 4,
  "editor.insertSpaces": true,
  "editor.trimAutoWhitespace": true,
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "editor.wordWrap": "off",
  "editor.linkedEditing": true,
 
  "terminal.integrated.defaultProfile.linux": "bash",
  "terminal.integrated.fontFamily": "'JetBrains Mono'",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.lineHeight": 1.2,
  "terminal.integrated.scrollback": 10000,
  "terminal.integrated.enableBell": false,
  
  "java.jdt.ls.java.home": "${java_home}",
  "java.configuration.updateBuildConfiguration": "automatic",
  "java.compile.nullAnalysis.mode": "automatic",
  "java.saveActions.organizeImports": true,
  "java.cleanup.actionsOnSave": [
    "qualifyMembers",
    "qualifyStaticMembers",
    "addOverride",
    "addDeprecated",
    "stringConcatToTextBlock",
    "invertEquals",
    "addFinalModifier",
    "instanceofPatternMatch",
    "lambdaExpression",
    "switchExpression"
  ],
  "java.test.defaultConfig": "junit5",
  "spring-boot.ls.problem.application-properties.UNKNOWN_PROPERTY_KEY": "WARNING",
 
  "docker.environment": {
    "DOCKER_HOST": "unix:///run/user/${user_uid}/podman/podman.sock"
  },
  "docker.showStartPage": false,
  
  "files.autoSave": "onFocusChange",
  "files.autoSaveDelay": 1000,
 
  "telemetry.telemetryLevel": "off",
 
  "accessibility.signals.sounds.volume": 0,
  "editor.accessibilitySupport": "off"
}
VSCODE_SETTINGS
 
  ok "VS Code configured — Java home: ${java_home:-mise activation}"
}

# =============================================================================
# 7. Ferramentas CLI de infraestrutura
# =============================================================================

_install_kubectl() {
  step "Installing kubectl"
  if ! command -v kubectl &>/dev/null; then      
      local ver bin
      ver=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
      bin="$CACHE_DIR/kubectl"
      cached_download \
          "https://storage.googleapis.com/kubernetes-release/release/${ver}/bin/linux/amd64/kubectl" \
          "$bin"
      sudo install "$bin" /usr/local/bin/kubectl
      ok "kubectl installed"
  else
      skip "kubectl already installed"
  fi
}

_install_awscli() {
    local zip_file="${CACHE_DIR}/awscliv2.zip"
    local extract_dir="${CACHE_DIR}/awscli-extracted"
    local install_dir="/usr/local/aws-cli"
    local bin_dir="/usr/local/bin"

    step "Checking AWS CLI"

    # Versão instalada
    local current_version=""
    if command -v aws &>/dev/null; then
        current_version=$(aws --version 2>&1 | awk -F/ '{print $2}' | awk '{print $1}')
    fi

    # 🔥 Versão remota real (GitHub tags)
    local remote_version
    remote_version=$(curl -s https://api.github.com/repos/aws/aws-cli/tags \
        | jq -r '.[0].name' 2>/dev/null \
        | sed 's/^v//')

    if [[ -z "$remote_version" || "$remote_version" == "null" ]]; then
        log_error "Failed to fetch remote AWS CLI version"
        return 1
    fi

    log_info "Current AWS CLI: ${current_version:-none}"
    log_info "Latest AWS CLI:  $remote_version"

    # Se já está atualizado, sai
    if [[ -n "$current_version" && "$current_version" == "$remote_version" ]]; then
        skip "AWS CLI already at latest version ($current_version)"
        return 0
    fi

    log_info "Downloading AWS CLI v2"

    cached_download \
        "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
        "$zip_file"

    rm -rf "$extract_dir"
    unzip -q "$zip_file" -d "$extract_dir"

    log_info "Installing/Updating AWS CLI to $remote_version"

    sudo "$extract_dir/aws/install" \
        --install-dir "$install_dir" \
        --bin-dir "$bin_dir" \
        ${current_version:+--update}

    rm -rf "$extract_dir"
    rm -rf "$zip_file"

    ok "AWS CLI now at $remote_version"
}

# =============================================================================
# 8. Clientes de API REST
# =============================================================================

_install_insomnia() {
    step "Installing Insomnia"
    log_info "Querying latest Insomnia release from GitHub..."

    local tag github_version installed_version
    local release_json rpm_asset rpm_file

    tag=$(curl -fsSL https://api.github.com/repos/Kong/insomnia/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')

    if [[ -z "$tag" ]]; then
        log_error "Unable to identify the latest Insomnia version on GitHub"
        return 1
    fi

    # core@2024.5.0 -> 2024.5.0
    github_version="${tag#core@}"

    log_info "Latest Insomnia release: ${github_version}"

    if installed_version=$(get_installed_version insomnia); then
        log_info "Installed Insomnia version: ${installed_version}"

        if version_ge "$installed_version" "$github_version"; then
            skip "Insomnia already up to date (${installed_version})"
            return
        fi
    fi

    log_info "Installing/Updating Insomnia..."

    release_json=$(curl -fsSL \
        "https://api.github.com/repos/Kong/insomnia/releases/tags/${tag}")

    rpm_asset=$(echo "$release_json" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*Insomnia\.Core[^"]*\.rpm)')

    if [[ -z "$rpm_asset" ]]; then
        log_error "Could not find Insomnia RPM asset"
        return 1
    fi

    rpm_file="${CACHE_DIR}/$(basename "$rpm_asset")"

    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading Insomnia RPM..."
        curl -fL "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached RPM: $rpm_file"
    fi

    dnf_install "$rpm_file"

    ok "Insomnia installed/updated to ${github_version}"
}

_install_bruno() {
  step "Installing Bruno"
  local repo="usebruno/bruno"
  local tag github_version installed_version
  local release_json rpm_asset rpm_file

  tag=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
      | grep -oP '"tag_name":\s*"\K([^"]+)')

  if [[ -z "$tag" ]]; then
      log_error "Unable to identify the latest Bruno release on GitHub"
      return 1
  fi

  # v4.3.0 -> 4.3.0
  github_version="${tag#v}"

  log_info "Latest Bruno release: ${github_version}"

  if installed_version=$(get_installed_version bruno); then
      log_info "Installed Bruno version: ${installed_version}"

      if version_ge "$installed_version" "$github_version"; then
          skip "Bruno already up to date (${installed_version})"
          return
      fi
  fi

  log_info "Installing/Updating Bruno..."

  release_json=$(curl -fsSL \
      "https://api.github.com/repos/${repo}/releases/tags/${tag}")

  # Find x86_64 RPM asset (project targets x86_64 only)
  rpm_asset=$(echo "$release_json" \
      | grep -oP 'browser_download_url":\s*"\K([^"]*_x86_64_linux\.rpm)')

  if [[ -z "$rpm_asset" ]]; then
      log_error "Could not find Bruno x86_64 RPM asset"
      return 1
  fi

  rpm_file="${CACHE_DIR}/$(basename "$rpm_asset")"

  if [[ ! -f "$rpm_file" ]]; then
      log_info "Downloading Bruno RPM..."
      curl -fL "$rpm_asset" -o "$rpm_file"
  else
      log_info "Using cached RPM: $rpm_file"
  fi

  dnf_install "$rpm_file"

  ok "Bruno installed/updated to ${github_version}"
}


# =============================================================================
# 8. Utilitários GUI
# =============================================================================

_install_dbeaver() {
    step "Installing DBeaver Community"
    log_info "Querying latest DBeaver release from GitHub..."

    local tag github_version installed_version
    local release_json rpm_asset rpm_file

    tag=$(curl -fsSL https://api.github.com/repos/dbeaver/dbeaver/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')

    if [[ -z "$tag" ]]; then
        log_error "Unable to identify latest DBeaver version"
        return 1
    fi

    # v25.1.3 -> 25.1.3
    github_version="${tag#v}"

    log_info "Latest DBeaver release: ${github_version}"

    if installed_version=$(get_installed_version dbeaver-ce); then
        log_info "Installed DBeaver version: ${installed_version}"

        if version_ge "$installed_version" "$github_version"; then
            skip "DBeaver already up to date (${installed_version})"
            return
        fi
    fi

    release_json=$(curl -fsSL \
        "https://api.github.com/repos/dbeaver/dbeaver/releases/tags/${tag}")

    rpm_asset=$(echo "$release_json" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*x86_64\.rpm)')

    if [[ -z "$rpm_asset" ]]; then
        log_error "Could not find DBeaver RPM asset"
        return 1
    fi

    rpm_file="${CACHE_DIR}/$(basename "$rpm_asset")"

    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading DBeaver RPM..."
        curl -fL "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached RPM: $rpm_file"
    fi

    dnf_install "$rpm_file"

    ok "DBeaver installed/updated to ${github_version}"
}

_install_drawio() {
    step "Installing draw.io desktop"
    log_info "Querying latest draw.io release from GitHub..."

    local tag github_version installed_version
    local release_json rpm_asset rpm_file

    tag=$(curl -fsSL https://api.github.com/repos/jgraph/drawio-desktop/releases/latest \
        | grep -oP '"tag_name":\s*"\K([^"]+)')

    if [[ -z "$tag" ]]; then
        log_error "Unable to identify latest draw.io version"
        return 1
    fi

    # v24.7.17 -> 24.7.17
    github_version="${tag#v}"

    log_info "Latest draw.io release: ${github_version}"

    if installed_version=$(get_installed_version draw.io); then
        log_info "Installed draw.io version: ${installed_version}"

        if version_ge "$installed_version" "$github_version"; then
            skip "draw.io already up to date (${installed_version})"
            return
        fi
    fi

    release_json=$(curl -fsSL \
        "https://api.github.com/repos/jgraph/drawio-desktop/releases/tags/${tag}")

    rpm_asset=$(echo "$release_json" \
        | grep -oP 'browser_download_url":\s*"\K([^"]*x86_64[^"]*\.rpm)')

    if [[ -z "$rpm_asset" ]]; then
        log_error "Could not find draw.io RPM asset"
        return 1
    fi

    rpm_file="${CACHE_DIR}/$(basename "$rpm_asset")"

    if [[ ! -f "$rpm_file" ]]; then
        log_info "Downloading draw.io RPM..."
        curl -fL "$rpm_asset" -o "$rpm_file"
    else
        log_info "Using cached RPM: $rpm_file"
    fi

    dnf_install "$rpm_file"

    ok "draw.io installed/updated to ${github_version}"
}

_install_typora() {
    local install_dir="$SETUP_HOME/.local/share/typora"
    local bin_link="$SETUP_HOME/.local/bin/typora"
    local desktop_file="$SETUP_HOME/.local/share/applications/typora.desktop"
    local archive="${CACHE_DIR}/typora.tar.gz"

    if [[ -x "$bin_link" ]] || [[ -x "$install_dir/Typora" ]] || command -v typora &>/dev/null; then
        skip "Typora already installed"
        return
    fi

    step "Installing Typora (portable tarball)"
    mkdir -p "$install_dir" "$SETUP_HOME/.local/bin"

    cached_download \
        "https://downloads.typora.io/linux/Typora-linux-x64.tar.gz" \
        "$archive"

    if ! tar -xzf "$archive" -C "$install_dir" --strip-components=2; then
        log_error "Failed to extract Typora archive"
        return 1
    fi

    ln -sf "$install_dir/Typora" "$bin_link"
    log_info "Created symlink: $bin_link → $install_dir/Typora"

    mkdir -p "$(dirname "$desktop_file")"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Typora
Exec=$bin_link %f
Icon=$install_dir/resources/assets/icon/icon_256x256@2x.png
Terminal=false
Categories=Utility;TextEditor;Markdown;
StartupNotify=true
EOF
    chmod +x "$desktop_file"

    ok "Typora installed"
}


# =============================================================================
# 9. Mobile development
# =============================================================================

_configure_kvm() {
  if [[ "${INSTALL_KVM:-true}" != "true" ]]; then
    skip "KVM setup disabled in config"
    return
  fi

  step "Configuring KVM/libvirt"

  dnf_install qemu-kvm libvirt libvirt-daemon-kvm libvirt-client virt-manager

  local user="${SETUP_USER:-$USER}"

  if id -nG "$user" | grep -qw libvirt && id -nG "$user" | grep -qw kvm; then
    skip "User $user already belongs to libvirt and kvm"
  else
    run_as_root usermod -aG libvirt,kvm "$user" || {
      log_error "Failed to add $user to libvirt/kvm groups"
      return 1
    }
    log_warn "Log out and back in for the new libvirt/kvm groups to take effect."
  fi

  if ! run_as_root systemctl is-active --quiet libvirtd; then
    run_as_root systemctl enable --now libvirtd 2>/dev/null || \
      log_warn "Could not enable libvirtd; it may be socket-activated on this release."
  fi

  ok "KVM/libvirt configured"
}

_install_android_studio() {
  if [[ "${INSTALL_ANDROID_STUDIO:-true}" != "true" ]]; then
    skip "Android Studio install disabled in config"
    return
  fi

  step "Installing Android Studio (latest stable)"

  local page archive_url version
  if ! page=$(curl -fsSL --max-time 30 https://developer.android.com/studio); then
    log_error "Could not fetch the Android Studio download page"
    return 1
  fi

  archive_url=$(grep -oE 'https://[^" ]+/android-studio-[^" ]+-linux\.tar\.gz' <<< "$page" | sed -n '1p')
  if [[ -z "$archive_url" ]]; then
    log_error "Could not resolve the Android Studio Linux x64 download URL"
    return 1
  fi
  version=$(sed -E 's#.*/ide-zips/([^/]+)/.*#\1#' <<< "$archive_url")

  local install_dir="/opt/android-studio"
  local marker="${install_dir}/.initora-source"
  local installed_source=""

  if [[ -x "${install_dir}/bin/studio" ]]; then
    [[ -f "$marker" ]] && installed_source=$(cat "$marker")
    if [[ "$installed_source" == "$archive_url" ]]; then
      skip "Android Studio already up to date (${version})"
      return
    elif [[ -n "$installed_source" ]]; then
      log_info "Updating Android Studio to ${version}"
    else
      log_warn "Android Studio exists but was not installed by initora; skipping"
      return
    fi
  fi

  local archive="${CACHE_DIR}/android-studio-${version}.tar.gz"
  cached_download "$archive_url" "$archive" || {
    log_error "Failed to download Android Studio"
    return 1
  }

  if ! tar -tzf "$archive" >/dev/null 2>&1; then
    log_error "Downloaded Android Studio archive is invalid"
    rm -f "$archive"
    return 1
  fi

  local extract_dir="${CACHE_DIR}/android-studio-extract"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir" || {
    log_error "Failed to extract Android Studio"
    return 1
  }

  local source_dir="${extract_dir}/android-studio"
  if [[ ! -x "${source_dir}/bin/studio" ]]; then
    source_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 2 -type d \
      -name 'android-studio*' -print -quit)
  fi

  if [[ ! -x "${source_dir}/bin/studio" ]]; then
    log_error "Could not find the Android Studio launcher in the archive"
    return 1
  fi

  run_as_root rm -rf "$install_dir"
  run_as_root mkdir -p "$(dirname "$install_dir")"
  run_as_root cp -a "$source_dir" "$install_dir"
  printf '%s\n' "$archive_url" | run_as_root tee "$marker" > /dev/null
  run_as_root ln -sfn "$install_dir/bin/studio" /usr/local/bin/studio

  local desktop_file="/usr/local/share/applications/android-studio.desktop"
  run_as_root mkdir -p "$(dirname "$desktop_file")"
  run_as_root tee "$desktop_file" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Studio
Comment=Official IDE for Android development
Exec=${install_dir}/bin/studio %u
Icon=${install_dir}/bin/studio.png
Terminal=false
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=android-studio
EOF
  run_as_root update-desktop-database "$(dirname "$desktop_file")" 2>/dev/null || true

  rm -rf "$extract_dir"
  ok "Android Studio ${version} installed"
}

_configure_android_env() {
  if [[ "${INSTALL_ANDROID_STUDIO:-true}" != "true" && \
        "${INSTALL_FLUTTER:-true}" != "true" ]]; then
    skip "Android environment disabled in config"
    return
  fi

  step "Configuring Android SDK environment"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local sdk="${ANDROID_HOME:-${user_home}/Android/Sdk}"
  local nvidia_line=""

  sudo -u "$user" mkdir -p \
    "$sdk/platform-tools" \
    "$sdk/emulator" \
    "$sdk/cmdline-tools/latest/bin"

  if lspci 2>/dev/null | grep -qi nvidia; then
    nvidia_line="alias emulador-nvidia='env ANDROID_EMU_GLES_MAX_VERSION=4.6 \"\$ANDROID_HOME/emulator/emulator\" -gpu host'"
  fi

  local android_block
  android_block=$(cat << EOF
export ANDROID_HOME="${sdk}"
export ANDROID_SDK_ROOT="\${ANDROID_HOME}"
export PATH="\${ANDROID_HOME}/emulator:\${ANDROID_HOME}/platform-tools:\${ANDROID_HOME}/cmdline-tools/latest/bin:\${PATH}"
${nvidia_line}
EOF
  )

  set_user_bashrc_block "android-sdk" "$android_block"
  ok "Android SDK environment configured at ${sdk}"
}

_install_flutter() {
  if [[ "${INSTALL_FLUTTER:-true}" != "true" ]]; then
    skip "Flutter SDK install disabled in config"
    return
  fi

  step "Installing Flutter SDK (stable)"

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local install_dir="${user_home}/.local/flutter"

  if [[ -d "${install_dir}/.git" ]]; then
    skip "Flutter SDK already present at ${install_dir}"
  else
    sudo -u "$user" mkdir -p "$(dirname "$install_dir")"
    sudo -u "$user" git clone --depth 1 --branch stable \
      https://github.com/flutter/flutter.git "$install_dir" || {
        log_error "Failed to clone the Flutter SDK"
        return 1
      }
    ok "Flutter SDK cloned"
  fi

  local flutter_block="export PATH=\"${install_dir}/bin:\${PATH}\""
  set_user_bashrc_block "flutter" "$flutter_block"

  log_info "Prefetching the Flutter/Dart SDK..."
  sudo -u "$user" env HOME="$user_home" "${install_dir}/bin/flutter" --version \
    >/dev/null 2>&1 || \
    log_warn "Flutter prefetch failed; run 'flutter --version' manually to diagnose."

  log_warn "Accept Android licenses manually with: flutter doctor --android-licenses"
  ok "Flutter SDK ready"
}

# =============================================================================
# 10. Shell prompt — Oh My Posh
# =============================================================================

_install_oh_my_posh() {
  if [[ "${INSTALL_OH_MY_POSH:-true}" != "true" ]]; then
    skip "Oh My Posh disabled in config"
    return
  fi

  step "Installing Oh My Posh (pure theme)"

  dnf_install oh-my-posh

  local ohmyposh_bin
  ohmyposh_bin=$(command -v oh-my-posh 2>/dev/null || true)
  if [[ -z "$ohmyposh_bin" ]]; then
    log_error "oh-my-posh binary not found after installation"
    return 1
  fi

  local user="${SETUP_USER:-$USER}"
  local user_home="${SETUP_HOME:-$HOME}"
  local theme="${OH_MY_POSH_THEME:-pure}"
  local config_dir="${user_home}/.config/oh-my-posh"
  local config_file="${config_dir}/${theme}.omp.json"

  sudo -u "$user" mkdir -p "$config_dir"

  if [[ -f "$config_file" ]]; then
    skip "Oh My Posh theme configuration already exists"
  else
    sudo -u "$user" "$ohmyposh_bin" config export \
      --config "$theme" --output "$config_file" || {
        log_warn "Could not export theme '${theme}'; using it by name instead"
        config_file="$theme"
      }
    ok "Oh My Posh theme '${theme}' configured"
  fi

  local activation="eval \"\$(${ohmyposh_bin} init bash --config '${config_file}')\""
  set_user_bashrc_block "oh-my-posh" "$activation"
  ok "Oh My Posh activation configured in .bashrc"
}

# =============================================================================
# 11. AI desktop applications
# =============================================================================

_install_opencode_desktop() {
  if [[ "${INSTALL_OPENCODE_DESKTOP:-true}" != "true" ]]; then
    skip "OpenCode Desktop install disabled in config"
    return
  fi

  step "Installing OpenCode Desktop"

  local latest_url="https://opencode.ai/update/api/latest/desktop/opencode/opencode-desktop-linux-x86_64.rpm"
  local resolved_url version installed_version rpm_file

  # A ranged GET resolves the redirect without downloading the whole RPM.
  if ! resolved_url=$(curl -fsSL -r 0-0 -o /dev/null -w '%{url_effective}' "$latest_url"); then
    log_error "Could not resolve the latest OpenCode Desktop release"
    return 1
  fi

  version=$(sed -E 's#.*/bin/([^/]+)/.*#\1#' <<< "$resolved_url")
  if [[ -z "$version" ]]; then
    log_error "Could not parse the OpenCode Desktop version from $resolved_url"
    return 1
  fi

  if installed_version=$(get_installed_version opencode-desktop 2>/dev/null); then
    log_info "Installed OpenCode Desktop: ${installed_version}"
    if version_ge "$installed_version" "$version"; then
      skip "OpenCode Desktop already up to date (${installed_version})"
      return
    fi
  fi

  log_info "Latest OpenCode Desktop: ${version}"
  rpm_file="${CACHE_DIR}/opencode-desktop-${version}-x86_64.rpm"
  cached_download "$resolved_url" "$rpm_file" || {
    log_error "Failed to download OpenCode Desktop"
    return 1
  }

  if ! rpm -qp --queryformat '%{NAME}\n' "$rpm_file" &>/dev/null; then
    log_error "Downloaded OpenCode Desktop RPM is invalid"
    rm -f "$rpm_file"
    return 1
  fi

  run_as_root dnf install -y --allowerasing "$rpm_file" || {
    log_error "Failed to install OpenCode Desktop"
    return 1
  }

  ok "OpenCode Desktop ${version} installed"
}

_install_antigravity_tarball() {
  local label="$1"
  local url="$2"
  local install_dir="$3"
  local symlink_name="$4"

  local marker="${install_dir}/.initora-source"
  local installed_source=""

  if [[ -d "$install_dir" ]]; then
    [[ -f "$marker" ]] && installed_source=$(cat "$marker")
    if [[ "$installed_source" == "$url" ]]; then
      skip "$label already up to date"
      return
    elif [[ -n "$installed_source" ]]; then
      log_info "Updating $label"
    else
      log_warn "$label exists but was not installed by initora; skipping"
      return
    fi
  fi

  local archive
  archive="${CACHE_DIR}/${label}-$(basename "$url")"
  cached_download "$url" "$archive" || {
    log_error "Failed to download $label"
    return 1
  }

  if ! tar -tzf "$archive" >/dev/null 2>&1; then
    log_error "Downloaded $label archive is invalid"
    rm -f "$archive"
    return 1
  fi

  local extract_dir="${CACHE_DIR}/${label}-extract"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir" || {
    log_error "Failed to extract $label"
    return 1
  }

  local source_dir binary rel_binary
  source_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 2 -type d \
    -iname 'antigravity*' -print -quit)
  [[ -n "$source_dir" ]] || source_dir="$extract_dir"

  binary=$(find "$source_dir" -maxdepth 3 -type f -perm -u+x \
    \( -iname 'antigravity' -o -iname 'antigravity*ide*' -o -iname 'Antigravity' \) \
    -print -quit)

  if [[ -z "$binary" ]]; then
    log_error "Could not find the $label launcher in the archive"
    return 1
  fi

  rel_binary="${binary#"$source_dir"/}"

  run_as_root rm -rf "$install_dir"
  run_as_root mkdir -p "$install_dir"
  run_as_root cp -a "$source_dir/." "$install_dir/"
  printf '%s\n' "$url" | run_as_root tee "$marker" > /dev/null
  run_as_root ln -sfn "${install_dir}/${rel_binary}" "/usr/local/bin/${symlink_name}"

  local icon
  icon=$(find "$install_dir" -maxdepth 4 -type f \
    \( -iname '*icon*.png' -o -iname '*logo*.png' -o -iname '*.svg' \) \
    -print -quit)
  [[ -n "$icon" ]] || icon="${install_dir}/${rel_binary}"

  local desktop_file="/usr/local/share/applications/${symlink_name}.desktop"
  run_as_root mkdir -p "$(dirname "$desktop_file")"
  run_as_root tee "$desktop_file" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${label}
Comment=${label} from Google
Exec=${install_dir}/${rel_binary} %U
Icon=${icon}
Terminal=false
Categories=Development;IDE;
StartupNotify=true
EOF
  run_as_root update-desktop-database "$(dirname "$desktop_file")" 2>/dev/null || true

  rm -rf "$extract_dir"
  ok "$label installed"
}

_install_antigravity_apps() {
  if [[ "${INSTALL_ANTIGRAVITY_APPS:-true}" != "true" ]]; then
    skip "Antigravity desktop apps disabled in config"
    return
  fi

  step "Installing Antigravity desktop apps (latest versions)"

  local page ide_url desktop_url
  if ! page=$(curl -fsSL --max-time 30 https://antigravity.google/download); then
    log_error "Could not fetch the Antigravity download page"
    return 1
  fi

  ide_url=$(grep -oE 'https://[^" ]+/linux-x64/Antigravity%20IDE\.tar\.gz' <<< "$page" | sed -n '1p')
  desktop_url=$(grep -oE 'https://[^" ]+/linux-x64/Antigravity\.tar\.gz' <<< "$page" | sed -n '1p')

  if [[ -z "$ide_url" || -z "$desktop_url" ]]; then
    log_error "Could not resolve the Antigravity Linux x64 download URLs"
    return 1
  fi

  _install_antigravity_tarball "Antigravity IDE" "$ide_url" \
    "/opt/antigravity-ide" "antigravity-ide"
  _install_antigravity_tarball "Antigravity Desktop" "$desktop_url" \
    "/opt/antigravity-desktop" "antigravity-desktop"
}

# =============================================================================
# Standalone entry point
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/initora-default.config"
  [[ -f "${SETUP_HOME}/.config/initora/initora.config" ]] && \
    source "${SETUP_HOME}/.config/initora/initora.config"
  module_20_dev_tools
fi