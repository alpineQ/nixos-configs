#!/usr/bin/env bash
# Boot NixOS minimal ISO in QEMU for testing the configuration
# Run from: /home/alpineq/projects/nixos-server/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ISO="$SCRIPT_DIR/nixos-minimal.iso"
VM_DIR="/mnt/data4/nixos"
DISK="$VM_DIR/nixos-disk.qcow2"
OVMF="/usr/share/edk2/OvmfX64/OVMF_CODE.fd"
OVMF_VARS="$VM_DIR/OVMF_VARS.fd"

# Create a 60G virtual disk if it doesn't exist
if [ ! -f "$DISK" ]; then
    echo "Creating 60G virtual disk..."
    qemu-img create -f qcow2 "$DISK" 60G
fi

# Copy OVMF vars for EFI boot (writable per-VM copy)
if [ ! -f "$OVMF_VARS" ]; then
    cp /usr/share/edk2/OvmfX64/OVMF_VARS.fd "$OVMF_VARS"
fi

# Share the nix config into the VM via 9p
# Inside the VM: mount -t 9p -o trans=virtio nixos-config /mnt/nixos-config
CONFIG_SHARE="$SCRIPT_DIR"

qemu-system-x86_64 \
    -name "NixOS" \
    -machine q35,accel=kvm \
    -cpu host \
    -smp 8,sockets=1,cores=8,threads=1 \
    -m 8G \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive file="$DISK",format=qcow2,if=virtio,cache=writeback \
    -cdrom "$ISO" \
    -boot d \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -virtfs local,path="$CONFIG_SHARE",mount_tag=nixos-config,security_model=mapped-xattr,id=nixos-config \
    -vga none \
    -device virtio-vga,max_outputs=1 \
    -display egl-headless,rendernode=/dev/dri/renderD128 \
    -spice port=5930,disable-ticketing=on \
    -device virtio-serial-pci \
    -chardev spicevmc,id=vdagent,debug=0,name=vdagent \
    -device virtserialport,chardev=vdagent,name=com.redhat.spice.0 \
    -usb \
    -device usb-tablet \
    -device virtio-keyboard-pci \
    &

QEMU_PID=$!

for i in {1..30}; do
  ss -tln | grep -q ':5930 ' && break
  sleep 0.2
done

remote-viewer spice://localhost:5930

kill $QEMU_PID 2>/dev/null
