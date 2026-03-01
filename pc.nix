{ config, pkgs, ... }:

{
  networking.hostName = "pc";

  nix.settings = {
    max-jobs = 16;
    cores = 32;
  };

  boot.kernelModules = [
    "kvm-amd"
    "vfio"
    "vfio_iommu_type1"
    "vfio_pci"
    "vfio_virqfd"
    "br_netfilter"
    "v4l2loopback"
    "snd-aloop"
    "nct6683"
  ];

  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "24G";
  };

  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr
    rocmPackages.clr.icd
  ];

  boot.loader.grub = {
    extraInstallCommands = ''
      ${pkgs.coreutils}/bin/cp -r /etc/grub/efi-Microsoft /boot/efi/EFI/Microsoft
    '';
    extraEntries = ''
      menuentry "Gentoo Linux" {
        search --no-floppy --fs-uuid --set=root 1ddfe806-480f-4799-9f8f-a5e8fb376b8f
        linux /boot/vmlinuz-6.12.58-gentoo-x86_64 root=UUID=1ddfe806-480f-4799-9f8f-a5e8fb376b8f ro quiet
        initrd /boot/initramfs-6.12.58-gentoo-x86_64.img
      }
      menuentry "Windows 11" {
        search --no-floppy --fs-uuid --set=root AE65-4697
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
}
