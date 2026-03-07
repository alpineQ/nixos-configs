# NixOS Configuration

Personal NixOS desktop config for host `pc`. Edit here, then copy to `/etc/nixos` and `nixos-rebuild switch`.

## Structure

```
configuration.nix     # Main system config (boot, networking, services, packages, users, fonts, theming)
pc.nix                # Host-specific: hostname, extra hosts (server fleet), kernel modules (AMD/VFIO), GRUB dual-boot (Gentoo, Windows 11), ROCm GPU
gaming.nix            # Steam, gamescope, gamemode, xpadneo controller, Proton compatdata bind-mounts from exFAT→ext4
home.nix              # home-manager config: neovim (LazyVim), fish, systemd user services, XDG dotfile symlinks, custom scripts
dotfiles/             # Raw config files symlinked via home-manager xdg.configFile
  sway/               # Sway WM config, modes (shutdown/screenshot/recording/vpn), scripts, Dracula theme, wallpapers
  waybar/             # Bar config (jsonc), style, weather widget
  nvim/lua/            # LazyVim plugin specs and overrides (config/, plugins/)
  foot/               # Terminal config
  rofi/               # Launcher config
  sworkstyle/         # Workspace icon mapping
  Kvantum/            # Qt theme (Dracula)
install-vm.sh         # Partition + install NixOS in QEMU VM for testing
run-qemu.sh           # Launch QEMU VM with this config shared via 9p
```

## Key Details

- **User**: `alpineq`, shell: fish, groups: wheel/docker/libvirtd/wireshark
- **Desktop**: Sway (Wayland) + Waybar + Mako + Foot + Rofi, Dracula theme everywhere
- **Editor**: Neovim via LazyVim, plugins pinned from nixpkgs (some from unstable channel)
- **Services (system)**: PipeWire, greetd+tuigreet, OpenSSH, Jellyfin, Plex, Samba, ntfy-sh, NTP
- **Services (user systemd)**: waybar, mako, autotiling, swayidle/swaylock, sworkstyle, swayr, foot-server, wl-paste/cliphist, polkit-agent, telegram, qbittorrent, sync-audio-volumes, OpenVPN tunnels (dehox, devment), loctok
- **Virtualization**: Docker, libvirtd/QEMU
- **GPU**: AMD with ROCm, 32-bit graphics enabled
- **Gaming**: Steam + Gamescope + GameMode, Proton compat dirs bind-mounted from ext4 over exFAT
- **Dual-boot**: GRUB with Gentoo and Windows 11 entries
- **Nix features**: flakes enabled, unfree allowed, unstable channel used for claude-code and some vim plugins
- **hardware-configuration.nix**: Not tracked (generated per-machine, in .gitignore)

## Conventions

- System packages go in `configuration.nix` `environment.systemPackages`
- User-level services go in `home.nix` `systemd.user.services`, bound to `sway-session.target`
- Dotfiles live in `dotfiles/` and are wired through `home.nix` `xdg.configFile`
- Package overrides (version pins, wrappers) use `overrideAttrs` or `symlinkJoin` inline
- Unstable channel packages fetched via `fetchTarball` of nixos-unstable, not flake inputs
