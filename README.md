# Fedora Gaming Setup for Lutris

Automated setup script for transforming Fedora 43+ into a complete gaming environment optimized for running local game files through Lutris.

## What This Script Does

### Core Features

- **GPU Driver Installation**: Automatically detects and installs drivers for NVIDIA, AMD, or Intel GPUs (including 32-bit libraries)
- **Lutris Configuration**: Sets up Lutris with automatic per-game Wine prefix isolation and config backup
- **Gaming Stack**: Installs Vulkan, DXVK, VKD3D, GameMode, and MangoHud with improved error handling
- **32-bit Library Support**: Installs all essential libraries for Windows game compatibility
- **Steam Integration**: Adds Steam client for additional libraries and controller support
- **Directory Structure**: Creates organized folders for games, ROMs, and installers (works with sudo and root)
- **Font Support**: Installs Liberation, DejaVu, Google Noto, and Microsoft core fonts with automatic cleanup
- **Performance Mode**: Optional CPU governor optimization for gaming
- **Verification**: Tests Vulkan, OpenGL (with glxinfo), and 32-bit library functionality
- **Smart Error Handling**: Detailed logging and graceful fallbacks for all operations

### NVIDIA-Specific Features

- Blacklists the nouveau driver
- Installs proprietary NVIDIA drivers with CUDA support
- Smart reboot logic (only when necessary)
- Rebuilds initramfs automatically

### Lutris Configuration

Each game installed through Lutris automatically gets its own isolated Wine prefix:

- **Game installations**: `~/Games/Lutris/`
- **Wine prefixes**: `~/.local/share/lutris/runners/wine/prefixes/<game-name>/`
- **No cross-contamination** between games

## Requirements

- Fedora 43 or newer
- Root/sudo access
- Active internet connection

## Installation & Usage

### Basic Usage (Interactive)

```bash
# Download the script
git clone https://github.com/eijiotieno-official/fedora-gaming-lutris.git
cd fedora-gaming-lutris

# Make it executable
chmod +x fedora_gaming_lutris.bash

# Run with sudo
sudo ./fedora_gaming_lutris.bash
```

### Command-Line Options

```bash
Usage: sudo ./fedora_gaming_lutris.bash [options]

Options:
  --noninteractive    Run without prompting (assume yes for installs and reboots)
  --no-reboot         Do not reboot automatically even if required
  --dry-run           Print actions but do not execute (safe preview)
  --install-wine      Install Wine and Winetricks
  --enable-proton-ge  Launch Lutris after setup for runner configuration
  --performance-mode  Set CPU governor to performance mode for gaming
  --log-file PATH     Write logs to PATH (default: /var/log/fedora-gaming-setup.log)
  -h, --help          Show help message
```

### Common Use Cases

**Preview what the script will do:**

```bash
sudo ./fedora_gaming_lutris.bash --dry-run
```

**Full gaming setup with Wine and performance mode:**

```bash
sudo ./fedora_gaming_lutris.bash --install-wine --performance-mode --enable-proton-ge
```

**Automated/unattended installation (CI/CD):**

```bash
sudo ./fedora_gaming_lutris.bash --noninteractive --install-wine --performance-mode
```

**Setup without automatic reboot:**

```bash
sudo ./fedora_gaming_lutris.bash --no-reboot --install-wine
```

## What Gets Installed

### GPU Drivers

- **NVIDIA**: akmod-nvidia, CUDA drivers, 32-bit libraries, nvidia-settings
- **AMD**: Mesa drivers, Vulkan drivers, firmware (64-bit and 32-bit)
- **Intel**: Mesa drivers, Vulkan drivers, firmware (64-bit and 32-bit)

### Gaming Software

- Lutris (game manager)
- GameMode (performance optimization)
- MangoHud (performance overlay)
- Steam (for libraries and controller support)
- DXVK & VKD3D (DirectX to Vulkan translation)
- mesa-demos (provides glxinfo for verification)
- Optional: Wine, Winetricks

### 32-bit Libraries (for Windows game compatibility)

- glibc.i686, libgcc.i686, libstdc++.i686
- mesa-libGL.i686, mesa-libGLU.i686
- SDL2.i686, gtk3.i686
- openal-soft.i686, alsa-plugins-pulseaudio.i686
- libXinerama.i686, libXrandr.i686
- libcurl.i686, openssl-libs.i686

### Fonts

- Liberation Fonts
- DejaVu Fonts
- Google Noto Fonts
- Microsoft Core Fonts (Arial, Times New Roman, etc.)

### Repositories

- RPM Fusion Free
- RPM Fusion Nonfree

## Directory Structure

After installation, you'll have:

```text
~/Games/
├── Lutris/      # Lutris-managed game installations
├── ROMs/        # Emulator game files
└── Installers/  # Game installation files
```

**Note**: If run as root without sudo, directory will be created at `/root/Games` instead.

Wine prefixes are automatically created per game:

```text
~/.local/share/lutris/runners/wine/prefixes/
├── game-name-1/
├── game-name-2/
└── ...
```

Lutris configuration is backed up before modification:

```text
~/.config/lutris/
├── system.yml                      # Current config
└── system.yml.backup.YYYYMMDD-HHMMSS  # Auto-backup (if config existed)
```

## Post-Installation Steps

1. **Reboot if needed** (script will prompt for NVIDIA installations)
2. **Open Lutris**: Launch from applications menu or run `lutris`
3. **Install runners**: In Lutris, go to Preferences → Runners and install:
   - Wine-GE (recommended for games)
   - Proton-GE (for Steam games)
4. **Add games**: File → Add Game → Choose your game executable
5. **Configure per game**: Each game gets its own Wine prefix automatically

## Performance Mode

When using `--performance-mode`, the script:

- Sets CPU governor to "performance" for maximum clock speeds
- Creates a systemd service to persist across reboots
- Install kernel-tools (cpupower utility)

To disable later:

```bash
sudo systemctl disable cpupower-performance.service
sudo cpupower frequency-set -g powersave
```

## Logs

All actions are logged to `/var/log/fedora-gaming-setup.log` (customizable with `--log-file`)

The script provides detailed logging including:
- Package installation status and warnings
- GPU detection results
- Configuration backups
- Verification test results
- Process launch confirmations

View logs:

```bash
sudo tail -f /var/log/fedora-gaming-setup.log
```

## Troubleshooting

### NVIDIA drivers not loading

- Ensure you rebooted after installation
- Check if nouveau is blacklisted: `lsmod | grep nouveau` (should return nothing)
- Verify driver loaded: `lsmod | grep nvidia`

### Games not launching

- Check 32-bit library support: `ldconfig -p | grep libGL`
- Verify Vulkan: `vulkaninfo --summary`
- Check OpenGL: `glxinfo | grep "direct rendering"` (glxinfo now auto-installed)
- Review detailed logs: `sudo grep "Warning\|Error" /var/log/fedora-gaming-setup.log`

### Wine prefix issues

- Each game should have its own prefix in `~/.local/share/lutris/runners/wine/prefixes/`
- Delete a game's prefix to reset it: `rm -rf ~/.local/share/lutris/runners/wine/prefixes/<game-name>`
- Restore Lutris config backup if needed: `cp ~/.config/lutris/system.yml.backup.* ~/.config/lutris/system.yml`

### Controller not detected

- Ensure steam-devices is installed: `rpm -q steam-devices`
- Reconnect controller after Steam installation

### Lutris not launching with --enable-proton-ge

- Check if Lutris installed correctly: `command -v lutris`
- Launch manually: `lutris` (the script will report if auto-launch failed)
- Review launch logs for PID confirmation or error messages

## Recent Improvements

**Version 2.0** (November 2025)

- ✅ **Enhanced Error Handling**: All package installations now report specific failures instead of silent errors
- ✅ **Auto-Cleanup**: Microsoft fonts installer RPM is automatically removed after installation
- ✅ **Config Backup**: Lutris `system.yml` is backed up before modification with timestamps
- ✅ **Root Support**: Script works correctly when run as root (creates `/root/Games` directory)
- ✅ **Better Verification**: Added `mesa-demos` installation for reliable `glxinfo` testing
- ✅ **Launch Validation**: Lutris launch with `--enable-proton-ge` now confirms success with PID
- ✅ **Improved Logging**: More detailed status messages and warnings throughout execution

## Security Considerations

- **Dry run first**: Use `--dry-run` to preview actions
- **Review logs**: Check `/var/log/fedora-gaming-setup.log` for issues
- **Secure Boot**: Script detects Secure Boot status (NVIDIA drivers may need manual signing)
- **Root required**: Script needs sudo for system-wide changes

## Uninstallation

To remove installed components:

```bash
# Remove gaming packages
sudo dnf remove lutris gamemode mangohud steam wine

# Remove NVIDIA drivers (if installed)
sudo dnf remove akmod-nvidia xorg-x11-drv-nvidia*

# Remove performance mode service
sudo systemctl disable cpupower-performance.service
sudo rm /etc/systemd/system/cpupower-performance.service

# Remove games directory (optional)
rm -rf ~/Games
```

## Contributing

Issues and pull requests welcome! Please test changes with `--dry-run` first.

## Author

Eiji Otieno ([@eijiotieno-official](https://github.com/eijiotieno-official))
