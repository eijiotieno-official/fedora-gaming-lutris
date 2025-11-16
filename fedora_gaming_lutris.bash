#!/usr/bin/env bash
# Fedora 43+ Lutris-focused gaming setup script
# Refactored: Reboot logic only triggers if NVIDIA drivers or nouveau blacklist applied for the first time

set -euo pipefail
IFS=$'\n\t'

LOGFILE="/var/log/fedora-gaming-setup.log"
NONINTERACTIVE=false
NO_REBOOT=false
DRY_RUN=false
INSTALL_WINE=false
ENABLE_PROTON_GE=false
PERFORMANCE_MODE=false
FEDORA_VER=""
DRY_CMD_PREFIX=""

usage() {
  cat <<EOF
Usage: sudo $0 [options]
Options:
  --noninteractive    Run without prompting (assume yes for installs and reboots)
  --no-reboot         Do not reboot automatically even if required
  --dry-run           Print actions but do not execute (safe preview)
  --install-wine      Install Wine and Winetricks
  --enable-proton-ge  After Lutris install try to open Lutris to let it install Proton-GE
  --performance-mode  Set CPU governor to performance mode for gaming
  --log-file PATH     Write logs to PATH (default: $LOGFILE)
  -h, --help          Show this help message
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --noninteractive) NONINTERACTIVE=true; shift ;;
    --no-reboot) NO_REBOOT=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --install-wine) INSTALL_WINE=true; shift ;;
    --enable-proton-ge) ENABLE_PROTON_GE=true; shift ;;
    --performance-mode) PERFORMANCE_MODE=true; shift ;;
    --log-file) LOGFILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ "$DRY_RUN" == true ]]; then
  DRY_CMD_PREFIX="echo [dry-run]"
fi

log() {
  local msg="$1"
  echo "$(date -u +"%Y-%m-%d %H:%M:%SZ") : $msg" | tee -a "$LOGFILE"
}

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    bash -c "$*"
  fi
}

_install_pkgs() {
  for pkg in "$@"; do
    if rpm -q "$pkg" >/dev/null 2>&1; then
      log "Package $pkg already installed, skipping"
    else
      log "Installing $pkg"
      if [[ "$DRY_RUN" == true ]]; then
        echo "[dry-run] dnf -y install $pkg"
      else
        if ! dnf -y install "$pkg"; then
          log "Warning: failed to install $pkg"
        fi
      fi
    fi
  done
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "This script must be run as root. Re-run with sudo or as root." >&2
    exit 1
  fi
}

require_root

if [[ "$DRY_RUN" == false ]]; then
  mkdir -p "$(dirname "$LOGFILE")"
  touch "$LOGFILE"
  chmod 0644 "$LOGFILE"
fi

log "Starting Fedora gaming setup script"
FEDORA_VER=$(rpm -E %fedora || true)
KERNEL_VER=$(uname -r || true)
CPU_INFO=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo || true)
TOTAL_RAM=$(free -h | awk '/Mem:/ {print $2}')
log "Fedora: $FEDORA_VER, Kernel: $KERNEL_VER, CPU:$CPU_INFO, RAM:$TOTAL_RAM"

# Update system early
log "Refreshing package metadata and upgrading existing packages"
run_cmd "dnf -y upgrade --refresh"

# Enable RPM Fusion
run_cmd "dnf -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm || true"
run_cmd "dnf -y install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm || true"

# GPU detection
HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL=false
if lspci -nnk | grep -i 'nvidia' >/dev/null 2>&1; then HAS_NVIDIA=true; fi
if lspci -nnk | grep -E -i 'amd|advanced micro devices' >/dev/null 2>&1; then
  if lspci -nnk | grep -i 'vga' | grep -i 'amd' >/dev/null 2>&1 || lspci -nnk | grep -i '3d controller' | grep -i 'amd' >/dev/null 2>&1; then HAS_AMD=true; fi
fi
if lspci -nnk | grep -i 'intel' >/dev/null 2>&1; then
  if lspci -nnk | grep -i 'vga' | grep -i 'intel' >/dev/null 2>&1; then HAS_INTEL=true; fi
fi
log "GPU detection: NVIDIA=$HAS_NVIDIA AMD=$HAS_AMD INTEL=$HAS_INTEL"

# Secure Boot check
SECURE_BOOT_ENABLED=false
if command -v mokutil >/dev/null 2>&1; then
  if mokutil --sb-state 2>/dev/null | grep -iq enabled; then SECURE_BOOT_ENABLED=true; fi
fi
log "Secure Boot enabled: $SECURE_BOOT_ENABLED"

# Blacklist nouveau and track if first-time change
BLACKLIST_NOUVEAU=false
FIRST_TIME_NVIDIA_INSTALL=false
if [[ "$HAS_NVIDIA" == true ]]; then
  if ! rpm -q akmod-nvidia >/dev/null 2>&1; then
    FIRST_TIME_NVIDIA_INSTALL=true
  fi
  if ! grep -E "^blacklist nouveau" /etc/modprobe.d/* >/dev/null 2>&1; then
    BLACKLIST_NOUVEAU=true
    run_cmd "echo 'blacklist nouveau' > /etc/modprobe.d/blacklist-nouveau.conf"
    run_cmd "echo 'options nouveau modeset=0' >> /etc/modprobe.d/blacklist-nouveau.conf"
  fi
fi

# Install drivers and Vulkan libs
_install_pkgs vulkan-loader vulkan-tools
if [[ "$HAS_NVIDIA" == true ]]; then
  _install_pkgs akmod-nvidia xorg-x11-drv-nvidia-cuda akmods xorg-x11-drv-nvidia-libs.i686 vulkan.i686 xorg-x11-drv-nvidia-cuda-libs.i686 nvidia-settings
fi
if [[ "$HAS_AMD" == true ]]; then
  _install_pkgs mesa-dri-drivers mesa-vulkan-drivers mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 vulkan.i686 linux-firmware
fi
if [[ "$HAS_INTEL" == true ]]; then
  _install_pkgs mesa-dri-drivers mesa-vulkan-drivers mesa-dri-drivers.i686 mesa-vulkan-drivers.i686 vulkan.i686 linux-firmware
fi

# Rebuild initramfs if nouveau blacklisted
if [[ "$BLACKLIST_NOUVEAU" == true ]]; then
  run_cmd "dracut --force"
fi

# Decide on reboot: only if NVIDIA drivers installed first time or nouveau blacklisted first time
if { [[ "$FIRST_TIME_NVIDIA_INSTALL" == true ]] || [[ "$BLACKLIST_NOUVEAU" == true ]]; } && [[ "$NO_REBOOT" == false ]]; then
  if [[ "$NONINTERACTIVE" == true ]]; then
    log "Noninteractive mode: rebooting automatically due to first-time NVIDIA driver install or nouveau blacklist"
    run_cmd "systemctl reboot"
    exit 0
  else
    read -p "A reboot is required for NVIDIA driver / nouveau changes. Reboot now? [y/N]: " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
      run_cmd "systemctl reboot"
      exit 0
    else
      log "User deferred reboot. Must reboot later for drivers to load properly"
    fi
  fi
fi

# Install gaming helpers
_install_pkgs gamemode mangohud vulkan-tools vulkan-loader lutris

# Install glxinfo for OpenGL verification (used in verify_setup)
_install_pkgs mesa-demos

# Install essential 32-bit libraries for gaming compatibility
log "Installing 32-bit gaming dependencies..."
_install_pkgs glibc.i686            # 32-bit C library (required for most Windows games)
_install_pkgs libgcc.i686           # 32-bit GCC runtime library
_install_pkgs libstdc++.i686        # 32-bit C++ standard library
_install_pkgs alsa-plugins-pulseaudio.i686  # 32-bit audio support for PulseAudio
_install_pkgs mesa-libGL.i686       # 32-bit OpenGL library
_install_pkgs mesa-libGLU.i686      # 32-bit OpenGL Utility library
_install_pkgs SDL2.i686             # 32-bit Simple DirectMedia Layer (used by many indie games)
_install_pkgs gtk3.i686             # 32-bit GTK3 (some game launchers need this)
_install_pkgs openal-soft.i686      # 32-bit OpenAL for 3D audio
_install_pkgs libXinerama.i686      # 32-bit X11 multi-monitor support
_install_pkgs libXrandr.i686        # 32-bit X11 display configuration
_install_pkgs libcurl.i686          # 32-bit network transfer library
_install_pkgs openssl-libs.i686     # 32-bit SSL/TLS encryption libraries

# Install Steam for additional gaming libraries and controller support
log "Installing Steam and compatibility tools..."
_install_pkgs steam                 # Steam client (provides many useful game libraries)
_install_pkgs steam-devices         # Udev rules for game controllers and Steam hardware

if [[ "$INSTALL_WINE" == true ]]; then
  _install_pkgs wine wine.i686 winetricks
fi

# Configure DXVK and VKD3D
log "Installing DXVK and VKD3D for DirectX translation..."
for pkg in dxvk dxvk-native vkd3d vkd3d-proton; do
  if rpm -q "$pkg" >/dev/null 2>&1; then
    log "Package $pkg already installed, skipping"
  else
    log "Installing $pkg"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] dnf -y install $pkg"
    else
      if ! dnf -y install "$pkg"; then
        log "Warning: failed to install $pkg (may not be available in repositories)"
      fi
    fi
  fi
done

# Install fonts needed by many Windows games
log "Installing fonts for game compatibility..."
_install_pkgs liberation-fonts      # Open-source alternatives to common Windows fonts
_install_pkgs dejavu-fonts          # High-quality font family
_install_pkgs google-noto-fonts     # Comprehensive Unicode font support

# Optionally install Microsoft core fonts (Arial, Times New Roman, etc.)
log "Attempting to install Microsoft core fonts..."
_install_pkgs curl                  # Needed to download font installer
MSFONTS_RPM="msttcore-fonts-installer-2.6-1.noarch.rpm"
if [[ "$DRY_RUN" == false ]]; then
  if curl -L -O "https://downloads.sourceforge.net/project/mscorefonts2/rpms/$MSFONTS_RPM"; then
    rpm -i "$MSFONTS_RPM" || log "Warning: Microsoft fonts installation failed"
    rm -f "$MSFONTS_RPM"  # Clean up downloaded RPM
  else
    log "Warning: Failed to download Microsoft fonts installer"
  fi
else
  echo "[dry-run] curl -L -O https://downloads.sourceforge.net/project/mscorefonts2/rpms/$MSFONTS_RPM && rpm -i $MSFONTS_RPM"
fi

# Set up dedicated games directory structure
log "Setting up games directory structure..."
GAMES_DIR=""
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  GAMES_DIR="/home/$SUDO_USER/Games"
  
  # Create main games directory and subdirectories
  run_cmd "mkdir -p '$GAMES_DIR'/{Lutris,ROMs,Installers}"
  
  # Set proper ownership to the actual user (not root)
  run_cmd "chown -R '$SUDO_USER:$SUDO_USER' '$GAMES_DIR'"
  
  log "Games directory created at: $GAMES_DIR"
  log "  - Lutris: for Lutris-managed games"
  log "  - ROMs: for emulator game files"
  log "  - Installers: for game installation files"
else
  GAMES_DIR="/root/Games"
  log "Warning: Running as root without sudo. Games directory will be created at: $GAMES_DIR"
  run_cmd "mkdir -p '$GAMES_DIR'/{Lutris,ROMs,Installers}"
fi

# Configure Lutris default settings
log "Configuring Lutris settings..."
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  LUTRIS_CONFIG_DIR="/home/$SUDO_USER/.config/lutris"
  
  # Create Lutris config directory
  run_cmd "mkdir -p '$LUTRIS_CONFIG_DIR'"
  
  # Backup existing config if it exists
  if [[ -f "$LUTRIS_CONFIG_DIR/system.yml" && "$DRY_RUN" == false ]]; then
    BACKUP_FILE="$LUTRIS_CONFIG_DIR/system.yml.backup.$(date +%Y%m%d-%H%M%S)"
    cp "$LUTRIS_CONFIG_DIR/system.yml" "$BACKUP_FILE"
    log "Backed up existing Lutris config to $BACKUP_FILE"
  fi
  
  # Create system configuration file
  # Note: Lutris automatically creates separate Wine prefixes for each game
  # in ~/.local/share/lutris/runners/wine/prefixes/<game-name>/
  if [[ "$DRY_RUN" == false ]]; then
    cat > "$LUTRIS_CONFIG_DIR/system.yml" <<EOF
system:
  # Default directory where Lutris will install games
  game_path: $GAMES_DIR/Lutris

wine:
  # Don't use virtual desktop by default (games run in fullscreen)
  Desktop: false
  # Each game automatically gets its own Wine prefix for isolation
  # Prefixes are stored in: ~/.local/share/lutris/runners/wine/prefixes/
EOF
  else
    echo "[dry-run] Would create $LUTRIS_CONFIG_DIR/system.yml with game_path: $GAMES_DIR/Lutris"
  fi
  
  # Set proper ownership
  run_cmd "chown -R '$SUDO_USER:$SUDO_USER' '$LUTRIS_CONFIG_DIR'"
  
  log "Lutris configured to use $GAMES_DIR/Lutris for game installations"
fi

# Set CPU governor to performance mode for better gaming performance
if [[ "$PERFORMANCE_MODE" == true ]]; then
  log "Configuring performance mode..."
  
  # Install CPU power management tools
  _install_pkgs kernel-tools        # Provides cpupower command
  
  # Set CPU governor to performance (max clock speed)
  log "Setting CPU governor to performance mode..."
  run_cmd "cpupower frequency-set -g performance"
  
  # Create systemd service to make performance mode persistent across reboots
  if [[ "$DRY_RUN" == false ]]; then
    cat > /etc/systemd/system/cpupower-performance.service <<EOF
[Unit]
Description=Set CPU governor to performance mode for gaming
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  else
    echo "[dry-run] Would create /etc/systemd/system/cpupower-performance.service"
  fi
  
  # Reload systemd and enable the service
  run_cmd "systemctl daemon-reload"
  run_cmd "systemctl enable cpupower-performance.service"
  
  log "Performance mode enabled and will persist across reboots"
fi

# Verify gaming setup functionality
verify_setup() {
  log "Verifying gaming setup..."
  
  # Test Vulkan functionality
  if command -v vulkaninfo >/dev/null 2>&1; then
    if vulkaninfo --summary >/dev/null 2>&1; then
      log "✓ Vulkan is working correctly"
    else
      log "✗ Vulkan test failed - check GPU drivers"
    fi
  fi
  
  # Test OpenGL direct rendering (important for performance)
  if command -v glxinfo >/dev/null 2>&1; then
    if glxinfo | grep -i "direct rendering: yes" >/dev/null 2>&1; then
      log "✓ OpenGL direct rendering is working"
    else
      log "✗ OpenGL direct rendering test failed"
    fi
  fi
  
  # Verify 32-bit libraries are installed
  log "Checking 32-bit library support..."
  if ldconfig -p | grep -i "libGL.so.1 (libc6,x86-64)" >/dev/null 2>&1; then
    log "✓ 64-bit libGL found"
  fi
  if ldconfig -p | grep -i "libGL.so.1 (libc6)" | grep -v x86-64 >/dev/null 2>&1; then
    log "✓ 32-bit libGL found (required for many Windows games)"
  else
    log "✗ 32-bit libGL not found - some games may not work"
  fi
}

# Run verification checks
if [[ "$DRY_RUN" == false ]]; then
  verify_setup
fi

# Launch Lutris if requested (always do this last so runners can be configured)
if [[ "$ENABLE_PROTON_GE" == true ]]; then
  log "Launching Lutris for initial setup and runner configuration..."
  if command -v lutris >/dev/null 2>&1; then
    # Launch as the actual user, not root
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
      # Run Lutris in background as user to allow runner downloads
      if su - "$SUDO_USER" -c "nohup lutris >/dev/null 2>&1 & echo \$!" > /tmp/lutris_pid 2>&1; then
        LUTRIS_PID=$(cat /tmp/lutris_pid 2>/dev/null || echo "")
        rm -f /tmp/lutris_pid
        if [[ -n "$LUTRIS_PID" ]]; then
          log "✓ Lutris launched successfully (PID: $LUTRIS_PID)"
          log "Use Lutris to install Wine-GE or Proton-GE runners for best compatibility."
        else
          log "✓ Lutris launch initiated. Use it to install Wine-GE or Proton-GE runners."
        fi
      else
        log "Warning: Failed to launch Lutris. You can start it manually later."
      fi
    else
      # Fallback if no sudo user detected
      if nohup lutris >/dev/null 2>&1 & then
        log "✓ Lutris launched. Use it to install Wine-GE or Proton-GE runners."
      else
        log "Warning: Failed to launch Lutris. You can start it manually later."
      fi
    fi
  else
    log "Warning: Lutris command not found. Installation may have failed."
  fi
fi

log "Setup complete."
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Next steps:"
log "1. Reboot if NVIDIA drivers were installed"
log "2. Open Lutris and install Wine-GE or Proton-GE runners"
log "3. Add your games in Lutris (File → Add Game)"
log "4. Each game will get its own isolated Wine prefix automatically"
log "5. Game files location: $GAMES_DIR"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
exit 0
