#!/usr/bin/env bash
# =============================================================================
# modules/00-system.sh -- System Base Configuration (REQUIRED)
#
# Tasks:
#   - DNF Tuning: Parallel downloads, fastest mirror, and cache management.
#   - Repositories: Adds RPM Fusion (Free/Non-Free) and removes unwanted repos.
#   - Multimedia: H.264, H.265, FFmpeg, and GStreamer codecs with VA-API setup.
#   - Updates: Full system upgrade and firmware (fwupdmgr) updates.
#   - Base Packages: Installs essential system utilities and dependencies.
#   - Directories: Initializes project-specific local directories.
# =============================================================================

MODULE_NAME="00-system"

module_00_system() {
  log_section "Module: System Base"

  _configure_dnf
  _add_rpmfusion
  _remove_unwanted_repos
  _system_update
  _install_multimedia  
  _install_base_packages
  _setup_directories

  log_success "Module $MODULE_NAME completed."
}

# -----------------------------
# Firmware
# -----------------------------
#
_configure_firmware() {
  step "Updating firmware"
  if [ "${INSTALL_PROPRIETARY_FIRMWARE}" != true ]; then
      skip "Skipping firmware updates."
      return
  fi

  dnf_install linux-firmware
  # Firmware (se fwupdmgr disponível)
  if has_cmd fwupdmgr; then
    log_info "Checking firmware updates..."
    fwupdmgr refresh --force  2>/dev/null || true
    fwupdmgr update -y        2>/dev/null || true
  fi

  ok "Firmware updated."
}

# -----------------------------------------------------------------------------
# Graphics / VA-API
# -----------------------------------------------------------------------------
_install_graphics() {
  step "Configuring graphics and VA-API"

  # Common renderer stack for Vulkan/OpenGL applications and development.
  dnf_install \
    mesa-vulkan-drivers vulkan-loader mesa-libGLU \
    libglvnd-opengl libglvnd-egl libglvnd-glx

  has_cmd lspci || dnf_install pciutils

  local gpus
  gpus=$(lspci -nn 2>/dev/null | grep -Ei 'VGA|3D|Display' || true)

  if [[ -z "$gpus" ]]; then
    log_warn "Could not detect GPU; skipping VA-API setup"
    return 0
  fi

  if grep -qi 'Intel' <<< "$gpus"; then
    log_info "Intel GPU detected — installing iHD VA-API driver"
    dnf_install intel-media-driver libva libva-utils
  fi

  if grep -qiE 'AMD|ATI' <<< "$gpus"; then
    log_info "AMD GPU detected — installing Mesa VA-API drivers"
    dnf_install mesa-va-drivers mesa-vdpau-drivers
  fi

  if grep -qi 'NVIDIA' <<< "$gpus"; then
    _install_nvidia
  fi

  ok "Graphics and VA-API configured"
}

_install_nvidia() {
  if [[ "${INSTALL_NVIDIA_DRIVER:-true}" != "true" ]]; then
    skip "NVIDIA driver disabled in config"
    return 0
  fi

  step "Installing NVIDIA driver (RPM Fusion)"

  # The NVIDIA driver lives in a dedicated RPM Fusion repository that used
  # to be removed as "unwanted". Keep it enabled for hybrid graphics.
  run_as_root dnf config-manager setopt \
    rpmfusion-nonfree-nvidia-driver.enabled=1 2>/dev/null || true

  dnf_install akmod-nvidia xorg-x11-drv-nvidia-cuda kernel-devel acpid

  if [[ "${INSTALL_NVIDIA_VAAPI:-true}" == "true" ]]; then
    dnf_install nvidia-vaapi-driver || \
      log_warn "nvidia-vaapi-driver not available — VA-API on NVIDIA will be unavailable"
  fi

  if has_cmd mokutil && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    log_warn "Secure Boot is enabled. Enroll the akmods MOK key and reboot:"
    log_warn "  sudo mokutil --import /etc/pki/akmods/certs/public_key.der"
  fi

  local nvidia_version
  nvidia_version=$(modinfo -F version nvidia 2>/dev/null || true)
  if [[ -z "$nvidia_version" ]]; then
    log_warn "NVIDIA kernel module is not available yet; akmods may still be building."
    log_warn "Reboot, then verify with: nvidia-smi && vainfo && glxinfo -B"
  else
    log_info "NVIDIA kernel module version: ${nvidia_version}"
    if ! grep -q '^nvidia[[:space:]]' /proc/modules 2>/dev/null; then
      log_warn "NVIDIA module is installed but not loaded. Reboot to activate it."
    fi
  fi

  ok "NVIDIA driver configured"
}

# -----------------------------------------------------------------------------
_install_multimedia() {
    if [[ "${INSTALL_MULTIMEDIA:-true}" != "true" ]]; then
        skip "Multimedia install disabled in config"
        return
    fi
    step "Installing multimedia support (H.264, H.265, ffmpeg, codecs)"

    _install_graphics

    # -------------------------------------------------------------------------
    # ffmpeg completo (RPM Fusion) — substitui o ffmpeg-free do Fedora
    # --allowerasing necessário pois ffmpeg conflita intencionalmente com ffmpeg-free
    # -------------------------------------------------------------------------
    run_as_root dnf swap -y ffmpeg-free ffmpeg --allowerasing 2>/dev/null || \
      run_as_root dnf install -y ffmpeg --allowerasing 2>/dev/null || true

    # -------------------------------------------------------------------------
    # GStreamer + codecs
    # Excluindo PackageKit-gstreamer-plugin pois PackageKit foi desabilitado
    # -------------------------------------------------------------------------
    local multimedia_pkgs=(
        gstreamer1-plugins-base
        gstreamer1-plugins-good
        gstreamer1-plugins-good-extras
        gstreamer1-plugins-bad-free
        gstreamer1-plugins-bad-freeworld
        gstreamer1-plugins-ugly
        gstreamer1-plugin-openh264
        gstreamer1-plugin-libav
        openh264
        mozilla-openh264
        libdvdread
        libdvdnav
        lame
        faac
        flac
        faad2
        libavcodec-freeworld
        x264
        x265
        vlc
        ffmpeg-libs
    )
    dnf_install "${multimedia_pkgs[@]}"

    # -------------------------------------------------------------------------
    # Verificar VA-API após instalação (não fatal se falhar)
    # -------------------------------------------------------------------------
    if command -v vainfo &>/dev/null; then
        log_info "VA-API status:"
        vainfo 2>&1 | grep -E "Driver|VAProfile|error" | head -20 || true
    else
        log_warn "vainfo not found — instale 'libva-utils' para verificar VA-API manualmente"
    fi

    # Grupo multimedia completo (GStreamer, etc.)
    run_as_root dnf group install -y multimedia 2>/dev/null || true
    run_as_root dnf group install -y sound-and-video 2>/dev/null || true

    run_as_root dnf config-manager setopt fedora-cisco-openh264.enabled=1 2>/dev/null || true
    log_warn "Firefox: Enable the OpenH264 plugin in Preferences → Add-ons → Plugins."

    ok "Multimedia packages installed"
}

# -----------------------------------------------------------------------------
_configure_dnf() {
  step "Configuring DNF for better performance"

  local dnf_conf="/etc/dnf/dnf.conf"
  backup_file "$dnf_conf"

  local max_p="${DNF_MAX_PARALLEL:-10}"
  local keepcache="${DNF_KEEPCACHE:-false}"

  # Idempotent: remove existing entries then re-add.
  # Only options supported by DNF5 are used (no deltarpm, no color=,
  # and metadata is allowed to expire normally).
  for param in \
    "gpgcheck=False" \
    "skip_if_unavailable=True" \
    "best=True" \
    "installonly_limit=2" \
    "max_parallel_downloads=${max_p}" \
    "fastestmirror=True" \
    "defaultyes=True" \
    "install_weak_deps=False" \
    "clean_requirements_on_remove=True" \
    "keepcache=${keepcache}"; do
    local key="${param%%=*}"
    run_as_root sed -i "/^${key}=/d" "$dnf_conf"
    echo "$param" | run_as_root tee -a "$dnf_conf" > /dev/null
  done

  ok "DNF configured"
}

# -----------------------------------------------------------------------------
_add_rpmfusion() {
  step "Adding RPM Fusion repositories"

  local fedora_ver
  fedora_ver=$(rpm -E %fedora)

  if [[ "${ENABLE_RPMFUSION_FREE:-true}" == "true" ]]; then
    if ! dnf repolist --enabled 2>/dev/null | grep -q "rpmfusion-free"; then
      log_info "Installing RPM Fusion Free..."
      run_as_root dnf install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
    else
      skip "RPM Fusion Free already present"
    fi
  fi

  if [[ "${ENABLE_RPMFUSION_NONFREE:-true}" == "true" ]]; then
    if ! dnf repolist --enabled 2>/dev/null | grep -q "rpmfusion-nonfree"; then
      log_info "Installing RPM Fusion Non-Free..."
      run_as_root dnf install -y \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"
    else
      skip "RPM Fusion Non-Free already present"
    fi
  fi

  run_as_root dnf install -y \
    rpmfusion-free-release-tainted \
    rpmfusion-nonfree-release-tainted \
    rpmfusion-free-appstream-data \
    rpmfusion-nonfree-appstream-data || true

  ok "RPM Fusion configured"
}

# -----------------------------------------------------------------------------
_remove_unwanted_repos() {
  step "Removing unwanted repositories"

  local repos=(
    "_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo"
    "rpmfusion-nonfree-steam.repo"
  )

  for repo in "${repos[@]}"; do
    local repo_path="/etc/yum.repos.d/${repo}"

    if [[ -f "$repo_path" ]]; then
      log_info "Removing $repo..."
      run_as_root rm -f "$repo_path"
      ok "$repo removed"
    else
      skip "$repo not present"
    fi
  done

  # Atualiza cache do DNF para refletir mudanças
  log_info "Refreshing DNF metadata..."

  if run_as_root dnf clean all 2>/dev/null; then
    log_info "DNF cache cleaned"
  else
    log_warn "DNF clean failed (continuing)"
  fi

  ok "Unwanted repositories cleaned up"
}

# -----------------------------------------------------------------------------
_system_update() {
  step "Updating system packages"

  # Upgrade all packages (--refresh já atualiza o cache)
  log_info "Running full system upgrade..."
  if run_as_root dnf upgrade -y --refresh; then
    ok "System packages upgraded"
  else
    log_warn "System upgrade completed with warnings"
  fi

  # Upgrade do grupo core (falha silenciosa é aceitável aqui)
  log_info "Upgrading core group..."
  run_as_root dnf group upgrade -y core 2>/dev/null || true

  # Remover pacotes órfãos
  log_info "Removing orphaned packages..."
  run_as_root dnf autoremove -y || true

  if has_cmd needs-restarting; then
    if ! needs-restarting -r &>/dev/null; then
      log_warn "A reboot is recommended (kernel or core libraries were updated)."
    fi
  fi

  _configure_firmware
}

# -----------------------------------------------------------------------------
_setup_directories() {
  step "Creating setup directories"
  local user_home="${SETUP_HOME:-$HOME}"
  local dirs=(
    "$user_home/.local/share/initora"
    "$user_home/.config/initora"
    "$user_home/.cache/initora"
    "$user_home/.local/bin"
    "$user_home/.local/opt"
  )
  for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || sudo -u "${SETUP_USER:-$USER}" mkdir -p "$d"
  done
  ok "Directories ready"
}


#
# -----------------------------
# Base Packages
# -----------------------------
#
_install_base_packages() {
  step "Installing essential dependencies"

  dnf_install \
      flatpak curl wget git unzip tar gzip ca-certificates gnupg \
      dnf-plugins-core lsb-release dconf-editor util-linux \
      fontconfig fzf gnome-keyring libgnome-keyring pciutils \
      switcheroo-control fedora-workstation-repositories openssl

  ok "Base packages installed."
}

# Standalone entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "${SCRIPT_DIR}/utils.sh"
  source "${SCRIPT_DIR}/initora-default.config"
  [[ -f "${SETUP_HOME}/.config/initora/initora.config" ]] && \
    source "${SETUP_HOME}/.config/initora/initora.config"
  module_00_system
fi
