{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    "${builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz"}/nixos"
  ];

  # ── Boot ──────────────────────────────────────────────────────────────
  boot = {
    loader = {
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = false;
        device = "nodev";
        useOSProber = true;
        configurationLimit = 3;
      };
      efi.canTouchEfiVariables = true;
    };

    kernelParams = [
      "quiet"
      "console=tty1"
      "loglevel=4"
    ];

    # Modules matching your Gentoo kernel config
    kernelModules = [
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

    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];

    # 24G tmpfs for /tmp (matches your fstab)
    tmp = {
      useTmpfs = true;
      tmpfsSize = "24G";
    };

    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.disable_ipv6" = 1;
      "net.ipv6.conf.default.disable_ipv6" = 1;
      "kernel.nmi_watchdog" = 0;
      "kernel.perf_event_paranoid" = 1;
    };
  };

  # ── Networking ────────────────────────────────────────────────────────
  networking = {
    hostName = "pc";
    firewall.enable = false; # Docker manages its own iptables
    networkmanager = {
      enable = true;
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
    };

    extraHosts = ''
      # LOCAL
      10.27.0.7       kafka

      # DEVMENT
      10.30.0.8       src.devment.tech
      10.30.0.1       athens.devment.tech
      10.30.0.1       bitwarden.devment.tech
      10.30.0.1       static.devment.tech

      # DEHOX
      10.84.0.100     src.dehox.com
      10.84.0.1       files.dehox.com
    '';
  };

  # ── Time / Locale ────────────────────────────────────────────────────
  time.timeZone = "Europe/Moscow";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "en_GB.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ALL = "en_US.UTF-8";
    };
  };

  console.keyMap = "us";

  # ── Nix settings ─────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = 16;
    cores = 32;
  };

  nixpkgs.config.allowUnfree = true;

  # ── Hardware ──────────────────────────────────────────────────────────
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
      ];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    enableRedistributableFirmware = true;
  };

  # ── Services ─────────────────────────────────────────────────────────
  services = {
    # Audio (PipeWire)
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # greetd + tuigreet (matches your Gentoo setup)
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --remember --asterisks --cmd sway";
          user = "greeter";
        };
      };
    };

    openssh.enable = true;

    jellyfin = {
      enable = true;
      openFirewall = true;
    };

    plex = {
      enable = true;
      openFirewall = true;
    };

    samba = {
      enable = true;
      openFirewall = true;
    };

    openntpd.enable = true;

    ntfy-sh = {
      enable = true;
      settings = {
        base-url = "http://localhost:8080";
        listen-http = ":8080";
        log-level = "warn";
      };
    };

    locate = {
      enable = true;
      package = pkgs.plocate;
    };

    openvpn.servers = {
      dehox.config = "config /etc/openvpn/dehox.ovpn";
      devment.config = "config /etc/openvpn/devment.ovpn";
    };

    udev.extraRules = ''
      # Disable USB wake for specific devices
      ACTION=="add", ATTRS{devpath}=="6", ATTR{power/wakeup}="disabled"
      ACTION=="add", ATTRS{devpath}=="9", ATTR{power/wakeup}="disabled"

      # Android device access (Asus Zenfone)
      SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", MODE="0660", GROUP="plugdev"
    '';
  };

  # ── Display / Sway ───────────────────────────────────────────────────
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # ── Virtualisation ──────────────────────────────────────────────────
  virtualisation = {
    docker.enable = true;

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_full;
        swtpm.enable = true;
      };
    };
  };

  # ── Programs ─────────────────────────────────────────────────────────
  programs = {
    sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraPackages = with pkgs; [
        swaylock-effects
        swayidle
        swaybg
        swayr
        autotiling
        swayest-workstyle
        waybar
        mako
        rofi
        foot
        sway-contrib.grimshot
        swappy
        wf-recorder
        wl-clipboard
        cliphist
        imv
        swayimg
      ];
    };

    fish.enable = true;

    neovim = {
      enable = true;
      defaultEditor = true;
    };

    git.enable = true;
  };

  # ── Security ─────────────────────────────────────────────────────────
  security = {
    rtkit.enable = true;
    sudo.enable = true;
    polkit.enable = true;
  };

  # ── Users ────────────────────────────────────────────────────────────
  users.groups.alpineq.gid = 1000;

  users.users.alpineq = {
    isNormalUser = true;
    home = "/home/alpineq";
    shell = pkgs.fish;
    group = "alpineq";
    extraGroups = [
      "wheel"
      "video"
      "kvm"
      "render"
      "plugdev"
      "docker"
      "networkmanager"
      "libvirtd"
    ];
  };

  # ── Environment ─────────────────────────────────────────────────────
  environment = {
    systemPackages = with pkgs; [
      # Editors
      (runCommand "vim-symlink" {} ''mkdir -p $out/bin && ln -s ${neovim}/bin/nvim $out/bin/vim'')
      vscode

      # Shells / terminal tools
      fish
      fzf
      tmux
      btop
      htop
      nvtopPackages.amd
      fd
      jq
      tree
      progress
      parallel

      # Dev tools
      rustup
      gcc
      tree-sitter
      clang
      nodejs
      github-cli
      lazygit
      ccache
      perf
      luarocks
      lua54Packages.lua-cjson
      (import (fetchTarball "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz") { config.allowUnfree = true; }).claude-code
      lmstudio
      go

      # Containers / VM
      qemu_full
      virt-viewer
      docker-buildx
      docker-compose

      # Networking
      nmap
      wireshark
      ethtool
      openvpn
      networkmanager-openvpn
      kcat

      # Media
      ffmpeg-full
      ffmpegthumbnailer
      vlc
      imagemagick
      speex

      # 3D printing / CAD
      openscad
      (pkgs.appimageTools.wrapType2 {
         pname = "bambu-studio";
         version = "PR-9540";
         src = /home/alpineq/.local/bin/bambu-studio;
         extraPkgs = pkgs: [ pkgs.webkitgtk_4_1 ];
      })

      # Office / productivity
      libreoffice-qt
      keepassxc
      firefox-bin
      chromium
      telegram-desktop
      qbittorrent

      # Wayland / desktop utilities
      pcmanfm
      gparted
      file-roller
      zenity
      xdg-user-dirs

      # Themes
      dracula-theme       # GTK theme
      dracula-icon-theme
      libsForQt5.qtstyleplugin-kvantum
      kdePackages.qtstyleplugin-kvantum  # Qt6

      # GPU / compute
      rocmPackages.rocm-smi
      mesa-demos

      # System tools
      usbutils
      dmidecode
      powertop
      btrfs-progs
      dosfstools
      exfatprogs
      ntfs3g
      mtpfs
      fuse
      lvm2
      appimage-run
      file

      # Android
      android-tools

      # Misc
      graphviz
      upx
      enchant

      # Bluetooth
      bluetuith

      # Audio
      pulseaudio
      pulsemixer
      playerctl
      (python3.withPackages (ps: [ ps.requests ]))
    ];

    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "sway";
      XCURSOR_THEME = "Dracula-cursors";
      XCURSOR_SIZE = "24";
    };
  };

  # ── Qt theming ───────────────────────────────────────────────────────
  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };

  # ── Fonts ────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      font-awesome
      roboto
      roboto-mono
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font" ];
      sansSerif = [ "Roboto" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # ── Home Manager ─────────────────────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.alpineq = import ./home.nix;
  };

  system.stateVersion = "25.11";
}
