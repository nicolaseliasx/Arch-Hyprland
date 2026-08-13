# Arch Hyprland PC-base profile

This repository is the versioned, portable profile of one Arch Linux +
Hyprland PC base. A client machine installs the same packages, dotfiles, themes
and fonts stored here; it does **not** create snapshots or write to GitHub.

## Install on a clean Arch machine

Start with Arch Linux, a normal user with `sudo`, networking, and this
repository cloned on `main`. Then run:

```bash
./install.sh
```

The installer asks for the sudo password once and keeps that authorization
alive for the duration of the run. Its `whiptail` terminal UI follows the
guided flow of the base fork: welcome/safety screen, **repair/update** or
**clean reinstall** choice, then an NVIDIA driver choice when a GPU is found.
The actual installation stays visible in the terminal and writes a detailed
log, rather than repeatedly clearing the screen with progress popups.

Repair mode is idempotent and can be run again after an interrupted or failed
installation. Clean reinstall moves the managed Oh My Zsh and Code Flow
runtime directories to a dated backup, then recreates the complete profile.
It does not delete documents, credentials, accounts, or unrelated packages.

The script installs core desktop dependencies first, then mirrors every path in
[`assets/snapshot-paths.txt`](assets/snapshot-paths.txt). Existing files in
those paths are overwritten, and a dated manual backup is stored under
`~/.local/state/arch-hyprland/backups/`. It does not partition disks, create
users, copy SSH keys, enable a snapshot timer, or upload anything.

Package failures are collected and reported with their criticality. Core
packages block only the dependent profile setup; Wallust is a theme warning
because the committed generated palette remains usable; applications listed in
`assets/packages/*-optional.txt` are reported as `OPTIONAL` and never block
Hyprland, dotfiles, Zsh, or the session. A failed AUR build is retried exactly
once after removing only that package's Yay cache and performing a clean build;
package integrity checks are never disabled. The final diagnostic verifies
Hyprland configuration, greetd/UWSM, Waybar selectors, wallpaper, theme, Zsh,
Eza, Codex CLI and Code Flow.

The credential-free Code Flow core is bundled under `assets/code-flow`; the
machine does not need access to its separate source repository. If Codex CLI
is absent, the installer uses the current standalone Linux installer from the
official OpenAI documentation. Authentication remains an explicit first-run
step and no account token is copied by this project.

For non-interactive recovery or testing, use:

```bash
./install.sh --mode repair --nvidia open --yes
./install.sh --mode clean --nvidia skip --yes
```

## PC base: create and publish the profile

Only run these commands on the PC base. Its checkout must be clean, on `main`,
and use an SSH `origin` that can push to GitHub.

```bash
./scripts/snapshot.sh
./install-scripts/setup-monthly-timer.sh --enable-remote
```

`--enable-remote` checks read and dry-run push access before it writes any
systemd unit. The user timer then runs on the first day of each month, captures
the profile, commits only generated snapshot artifacts, and pushes to `main`.
It aborts safely if the checkout is dirty or behind the remote.

Useful commands:

```bash
./install-scripts/setup-monthly-timer.sh --status
./install-scripts/setup-monthly-timer.sh --run-now
./install-scripts/setup-monthly-timer.sh --disable
```

## What is and is not copied

The snapshot mirrors all of `~/.config`, selected shell/profile files, and
wallpapers. It filters caches, browser profiles, local databases, session
state, `.env` files, private-key files, known credential directories (including
GitHub CLI and Codex Mobile), account files and paths named like tokens, secrets or passwords. Large
application state such as JetBrains analyzer workspaces, VS Code history and
workspace storage/extension caches, Hyprland generated wallpaper effects,
Slack/Discord sessions, Anytype/Obsidian/Codex application state, VS Code runtime data and browser profiles is also
excluded. The remote snapshot systemd units are excluded as well. This keeps
the visual and development configuration portable while requiring each machine
to sign in to personal services separately.

Home-directory references are rewritten to `$HOME`. Hyprland's monitor,
workspace, lock-screen and wake configuration is normalized to avoid desktop
connector names, so the profile starts safely on a single-panel notebook.
