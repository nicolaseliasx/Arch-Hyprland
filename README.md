# Arch Hyprland Personal Bootstrap & Snapshot

This repository contains a clean, automated, and reproducible snapshot & installation system for **Arch Linux + Hyprland**.

Designed for seamless deployment across multiple machines (e.g. Laptop and Desktop PC).

---

## 🚀 Quick Start (Fresh Install)

```bash
git clone https://github.com/nicolaseliasx/arch-hyprland.git
cd arch-hyprland
./install.sh
```

---

## 🛠️ Management & Maintenance Scripts

- **Manual Snapshot** (Extract latest dotfiles & explicit packages from your system into repo):
  ```bash
  ./scripts/snapshot.sh
  ```
- **Apply Snapshot** (Restore dotfiles & install missing packages without full reinstall):
  ```bash
  ./scripts/apply.sh
  ```
- **Monthly Auto-Snapshot & Push**:
  - Automatically runs on the 1st of every month at 00:00 (via systemd user timer).
  - Triggers a GUI error popup (**"Erro ao tirar snapshot do sistema"**) via `yad` / `rofi` if any error occurs.
  - Setup / Manage Timer:
    ```bash
    # Enable monthly timer:
    ./install-scripts/setup-monthly-timer.sh

    # Test auto-snapshot now:
    ./install-scripts/setup-monthly-timer.sh --run-now

    # Disable timer:
    ./install-scripts/setup-monthly-timer.sh --disable
    ```

---

## 🖥️ Display & Hardware Features

- **Multi-Monitor / Display Toggle**: Select between Laptop / Single Monitor (`monitor = , preferred, auto, 1`) and Desktop Dual Monitor (DP-3 + DP-2 setup) during installation or via `install-scripts/monitors.sh`.
- **NVIDIA GPU Support**: Automatic detection and installation of `nvidia-dkms` & hyprland environment configuration.
- **Embedded Dotfiles**: Self-contained snapshot located in `assets/dotfiles/` (Hyprland, Waybar, Rofi, Quickshell, Kitty, Ghostty, Swaync, Wallust, Zsh, Wallpapers, etc.).
- **Package Lists**: Explicit native and AUR package lists maintained in `assets/packages/`.
