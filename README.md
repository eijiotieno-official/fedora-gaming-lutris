# Fedora Gaming Setup for Lutris

Automated setup script for transforming Fedora 43+ into a complete gaming environment optimized for running local game files through Lutris.

## What This Script Does

### Core Features
- **GPU Driver Installation**: Automatically detects and installs drivers for NVIDIA, AMD, or Intel GPUs (including 32-bit libraries)
- **Lutris Configuration**: Sets up Lutris with automatic per-game Wine prefix isolation
- **Gaming Stack**: Installs Vulkan, DXVK, VKD3D, GameMode, and MangoHud
- **32-bit Library Support**: Installs all essential libraries for Windows game compatibility
- **Steam Integration**: Adds Steam client for additional libraries and controller support
- **Directory Structure**: Creates organized folders for games, ROMs, and installers
- **Font Support**: Installs Liberation, DejaVu, Google Noto, and Microsoft core fonts
- **Performance Mode**: Optional CPU governor optimization for gaming
- **Verification**: Tests Vulkan, OpenGL, and 32-bit library functionality

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
git clone <your-repo-url>
cd <repo-directory>

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

```
~/Games/
├── Lutris/      # Lutris-managed game installations
├── ROMs/        # Emulator game files
└── Installers/  # Game installation files
```

Wine prefixes are automatically created per game:
```
~/.local/share/lutris/runners/wine/prefixes/
├── game-name-1/
├── game-name-2/
└── ...
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
- Check OpenGL: `glxinfo | grep "direct rendering"`

### Wine prefix issues
- Each game should have its own prefix in `~/.local/share/lutris/runners/wine/prefixes/`
- Delete a game's prefix to reset it: `rm -rf ~/.local/share/lutris/runners/wine/prefixes/<game-name>`

### Controller not detected
- Ensure steam-devices is installed: `rpm -q steam-devices`
- Reconnect controller after Steam installation

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

## License

[Your License Here]

## Author

[Your Name/Handle]
