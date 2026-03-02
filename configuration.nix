{ config, pkgs, lib, ... }:

let
  tree-sitter-latest = pkgs.tree-sitter.overrideAttrs (old: rec {
    version = "0.26.6";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter";
      repo = "tree-sitter";
      tag = "v${version}";
      hash = "sha256-ZtzwhEmNZg5brghKNiTRZSmY8FwQeWcemY2blq9j2GM=";
      fetchSubmodules = true;
    };
    cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "tree-sitter-${version}-vendor.tar.gz";
      hash = "sha256-u6RmwNR4QVwyuij5RlHTLC5lNNQpWMVrlQwfwF78pYc=";
    };
    patches = [];
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.libclang ];
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.glibc.dev}/include -isystem ${pkgs.libclang.lib}/lib/clang/${lib.versions.major pkgs.libclang.version}/include";
  });
in
{
  imports = [
    ./hardware-configuration.nix
    ./pc.nix
    ./gaming.nix
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
        useOSProber = false;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot/efi";
      };
    };

    kernelParams = [
      "quiet"
      "console=tty1"
      "loglevel=4"
    ];

    # Modules matching your Gentoo kernel config
    extraModulePackages = with config.boot.kernelPackages; [
      v4l2loopback
    ];

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
    firewall.enable = false; # Docker manages its own iptables
    networkmanager = {
      enable = true;
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
      ensureProfiles.profiles.wired = {
        connection = {
          id = "Wired connection 1";
          type = "802-3-ethernet";
          interface-name = "enp12s0";
        };
        ipv4.method = "auto";
        ipv6.method = "disabled";
      };
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

      193.106.150.249 m1kfkne.srv
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
  };

  nixpkgs.config.allowUnfree = true;


  # ── Hardware ──────────────────────────────────────────────────────────
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
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

    udev.extraRules = ''
      # Disable USB wake for specific devices
      ACTION=="add", ATTRS{devpath}=="6", ATTR{power/wakeup}="disabled"
      ACTION=="add", ATTRS{devpath}=="9", ATTR{power/wakeup}="disabled"

      # Android device access (Asus Zenfone)
      SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", MODE="0660", GROUP="plugdev"
    '';
  };

  # ── Docker CLI plugins (workaround for compose not finding buildx) ──
  systemd.tmpfiles.rules = [
    "d /usr/local/libexec/docker/cli-plugins 0755 root root -"
    "L /usr/local/libexec/docker/cli-plugins/docker-buildx - - - - ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx"
  ];

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

    nix-ld.enable = true;

    git.enable = true;

    wireshark.enable = true;
  };

  # ── Security ─────────────────────────────────────────────────────────
  security = {
    rtkit.enable = true;
    sudo.enable = true;
    polkit = {
      enable = true;
      extraConfig = lib.mkMerge [
        ''
          polkit.addRule(function(action, subject) {
            if ((action.id === "org.freedesktop.login1.power-off" ||
                 action.id === "org.freedesktop.login1.power-off-multiple-sessions" ||
                 action.id === "org.freedesktop.login1.reboot" ||
                 action.id === "org.freedesktop.login1.reboot-multiple-sessions" ||
                 action.id === "org.freedesktop.login1.suspend" ||
                 action.id === "org.freedesktop.login1.suspend-multiple-sessions") &&
                subject.isInGroup("wheel")) {
              return polkit.Result.YES;
            }
          });
        ''
        (lib.mkAfter ''
          polkit.addRule(function(action, subject) {
            if (subject.isInGroup("wheel")) {
              return polkit.Result.AUTH_ADMIN_KEEP;
            }
          });
        '')
      ];
    };
    wrappers.openvpn = {
      source = "${pkgs.openvpn}/bin/openvpn";
      capabilities = "cap_net_admin+ep";
      owner = "root";
      group = "root";
    };
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
      "wireshark"
    ];
  };

  # ── Environment ─────────────────────────────────────────────────────
  environment = {
    systemPackages = with pkgs; [
      # Editors
      vscode

      # Shells / terminal tools
      fish
      fzf
      tmux
      btop
      htop
      nvtopPackages.amd
      fd
      ripgrep
      jq
      tree
      progress
      parallel

      # Dev tools
      rustup
      gcc
      tree-sitter-latest
      clang
      clang-tools
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
      gopls
      sqlite
      glibc.static

      # Containers / VM
      qemu_full
      virt-viewer
      docker-buildx
      docker-compose

      # Networking
      nmap
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
         src = pkgs.fetchurl {
           url = "https://github.com/bambulab/BambuStudio/releases/download/v02.05.00.67/Bambu_Studio_ubuntu-24.04_PR-9540.AppImage";
           hash = "sha256-3ubZblrsOJzz1p34QiiwiagKaB7nI8xDeadFWHBkWfg=";
         };
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

    etc."xdg/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-theme-name=Dracula
      gtk-icon-theme-name=Dracula
      gtk-cursor-theme-name=Dracula-cursors
      gtk-application-prefer-dark-theme=true
      gtk-font-name=Roboto 11
    '';

    etc."xdg/gtk-4.0/settings.ini".text = ''
      [Settings]
      gtk-icon-theme-name=Dracula
      gtk-cursor-theme-name=Dracula-cursors
      gtk-application-prefer-dark-theme=true
      gtk-font-name=Roboto 11
    '';

    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      XDG_SESSION_TYPE = "wayland";
      XDG_CURRENT_DESKTOP = "sway";
      XCURSOR_THEME = "Dracula-cursors";
      XCURSOR_SIZE = "24";
      LIBRARY_PATH = "${pkgs.glibc.static}/lib";
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
