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

The script asks for `INSTALL` before it starts. It installs the package
manifests with `yay`, then mirrors every path in
[`assets/snapshot-paths.txt`](assets/snapshot-paths.txt). Existing files in
those paths are overwritten, and a dated manual backup is stored under
`~/.local/state/arch-hyprland/backups/`. It does not partition disks, create
users, copy SSH keys, enable a snapshot timer, or upload anything.

Some old Arch/AUR packages may disappear. Those failures are written to the
installation log and do not stop the remaining profile from being applied.

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
