#!/usr/bin/env bash
set -euo pipefail

ROOT=/mnt/nixos

# Partition the virtual disk
parted /dev/vda -- mklabel gpt
parted /dev/vda -- mkpart ESP fat32 1MB 512MB
parted /dev/vda -- set 1 esp on
parted /dev/vda -- mkpart primary ext4 512MB 100%

# Format
mkfs.fat -F 32 -n BOOT /dev/vda1
mkfs.ext4 -L nixos /dev/vda2

# Mount target
mkdir -p "$ROOT"
mount /dev/vda2 "$ROOT"
mkdir -p "$ROOT/boot/efi"
mount /dev/vda1 "$ROOT/boot/efi"

# Generate hardware config with correct VM UUIDs
nixos-generate-config --root "$ROOT"

# Copy our config (keep the generated hardware-configuration.nix)
cp /mnt/nixos-config/configuration.nix "$ROOT/etc/nixos/configuration.nix"
cp /mnt/nixos-config/home.nix "$ROOT/etc/nixos/home.nix"
cp -r /mnt/nixos-config/dotfiles "$ROOT/etc/nixos/dotfiles"

echo ""
echo "Config installed. Review $ROOT/etc/nixos/configuration.nix then run:"
echo "  nixos-install --root $ROOT"
echo ""
echo "After install completes and you reboot, remove -cdrom and -boot flags from run-qemu.sh"
