{ config, pkgs, lib, ... }:

let
  tree-sitter-vim-fixed = pkgs.tree-sitter-grammars.tree-sitter-vim.overrideAttrs {
    version = "0.8.1";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter-grammars";
      repo = "tree-sitter-vim";
      tag = "v0.8.1";
      hash = "sha256-MnLBFuJCJbetcS07fG5fkCwHtf/EcNP+Syf0Gn0K39c=";
    };
  };

  # Build a vim grammar plugin from the fixed grammar, matching how nixpkgs does it
  vim-grammar-plugin = pkgs.runCommand "vim-grammar-fixed" {} ''
    mkdir -p $out/parser
    ln -s ${tree-sitter-vim-fixed}/parser $out/parser/vim.so
  '';

  unstable = import (fetchTarball "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz") {
    config.allowUnfree = true;
  };

  unstableVim = unstable.vimPlugins;
  nvim-treesitter-unstable = unstableVim.nvim-treesitter;

  isNixOS = builtins.pathExists /etc/NIXOS;
  openvpnBin = if isNixOS then "/run/wrappers/bin/openvpn" else "/usr/sbin/openvpn";
in
{
  home = {
    stateVersion = "25.11";
    username = "alpineq";
    homeDirectory = "/home/alpineq";

    # ── Custom scripts ───────────────────────────────────────────────────
    file.".local/bin/sync-audio-volumes.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        pactl subscribe | grep --line-buffered "sink #" | while read -r event; do
            sink_vol=$(pactl get-sink-volume @DEFAULT_SINK@ | head -1 | awk '{print $5}')
            pactl list short sink-inputs | while read -r input; do
                id=$(echo "$input" | awk '{print $1}')
                pactl set-sink-input-volume "$id" "$sink_vol"
            done
        done
      '';
    };

    file.".local/bin/sway-logout" = {
      executable = true;
      text = ''
        #!/bin/sh
        swaymsg -t exit
        systemctl --user stop graphical-session.target
        loginctl terminate-session "$XDG_SESSION_ID"
      '';
    };

    file.".cargo/config.toml".text = ''
      [target.x86_64-unknown-linux-musl]
      linker = "x86_64-unknown-linux-musl-gcc"

      [env]
      CC_x86_64_unknown_linux_musl = "x86_64-unknown-linux-musl-gcc"
    '';

    file.".local/bin/inhibit-idle" = {
      executable = true;
      text = ''
        #!/bin/sh

        status() {
            ps -ef | grep -v grep | grep -m 1 -q "systemd-inhibit --what=idle"
        }

        inhibit() {
            systemd-inhibit --what=idle --who=swayidle-inhibit --why=commanded --mode=block sleep $1 &
            waybar-signal idle
        }

        case $1 in
        'interactive')
            MINUTES=$(echo -e "1\n10\n15\n20\n30\n45\n60\n90\n120\nUnlimited" | rofi -dmenu -p "Select how many minutes to inhibit idle:")
            if [ "$MINUTES" = "Unlimited" ]; then
                SECONDS=$((365 * 24 * 60 * 60))
            else
                SECONDS=$((MINUTES * 60))
            fi
            inhibit $SECONDS
            ;;
        'off')
            pkill -U $USER -f "systemd-inhibit --what=idle" || true
            waybar-signal idle
            ;;
        esac

        if status; then
            class="on"
            text="Inhibiting idle (Mid click to clear)"
        else
            class="off"
            text="Idle not inhibited"
        fi

        printf '{"alt":"%s","tooltip":"%s"}\n' "$class" "$text"
      '';
    };
  };

  # ── XDG ──────────────────────────────────────────────────────────────
  xdg = {
    configFile = {
      # Sway
      "sway/config".source = ./dotfiles/sway/config;
      "sway/definitions".source = ./dotfiles/sway/definitions;
      "sway/idle.yaml".source = ./dotfiles/sway/idle.yaml;
      "sway/night-cabin.jpg".source = ./dotfiles/sway/night-cabin.jpg;
      "sway/background.jpg".source = ./dotfiles/sway/background.jpg;
      "sway/world.png".source = ./dotfiles/sway/world.png;

      "sway/modes/recording".source = ./dotfiles/sway/modes/recording;
      "sway/modes/screenshot".source = ./dotfiles/sway/modes/screenshot;
      "sway/modes/shutdown".source = ./dotfiles/sway/modes/shutdown;
      "sway/modes/vpn".source = ./dotfiles/sway/modes/vpn;

      "sway/scripts/enable-gtk-theme.sh" = {
        source = ./dotfiles/sway/scripts/enable-gtk-theme.sh;
        executable = true;
      };
      "sway/scripts/monitors.sh" = {
        source = ./dotfiles/sway/scripts/monitors.sh;
        executable = true;
      };
      "sway/scripts/once.sh" = {
        source = ./dotfiles/sway/scripts/once.sh;
        executable = true;
      };
      "sway/scripts/recorder.sh" = {
        source = ./dotfiles/sway/scripts/recorder.sh;
        executable = true;
      };
      "sway/scripts/weather.py" = {
        source = ./dotfiles/sway/scripts/weather.py;
        executable = true;
      };

      "sway/themes/dracula/theme.conf".source = ./dotfiles/sway/themes/dracula/theme.conf;
      "sway/themes/dracula/foot-theme.ini".source = ./dotfiles/sway/themes/dracula/foot-theme.ini;
      "sway/themes/dracula/packages".source = ./dotfiles/sway/themes/dracula/packages;
      "sway/themes/dracula/Dracula-purple-solid/Dracula-purple-solid.kvconfig".source = ./dotfiles/sway/themes/dracula/Dracula-purple-solid/Dracula-purple-solid.kvconfig;
      "sway/themes/dracula/Dracula-purple-solid/Dracula-purple-solid.svg".source = ./dotfiles/sway/themes/dracula/Dracula-purple-solid/Dracula-purple-solid.svg;

      # Waybar
      "waybar/config.jsonc".source = ./dotfiles/waybar/config.jsonc;
      "waybar/style.css".source = ./dotfiles/waybar/style.css;
      "waybar/weather.cfg".source = ./dotfiles/waybar/weather.cfg;

      # Neovim
      "nvim/lua".source = ./dotfiles/nvim/lua;
      "nvim/parser".source =
        let
          parsers = pkgs.symlinkJoin {
            name = "treesitter-parsers";
            paths = (nvim-treesitter-unstable.withPlugins (p: with p; [
              bash c cpp css diff go html javascript json lua luadoc
              markdown markdown-inline nix python query regex rust
              toml tsx typescript vimdoc xml yaml
            ])).dependencies ++ [ vim-grammar-plugin ];
          };
        in
        "${parsers}/parser";

      # Foot
      "foot/foot.ini".source = ./dotfiles/foot/foot.ini;

      # Rofi
      "rofi/config.rasi".source = ./dotfiles/rofi/config.rasi;

      # Sworkstyle
      "sworkstyle/config.toml".source = ./dotfiles/sworkstyle/config.toml;

      # Kvantum
      "Kvantum/kvantum.kvconfig".source = ./dotfiles/Kvantum/kvantum.kvconfig;
      "Kvantum/Dracula-purple-solid/Dracula-purple-solid.kvconfig".source = ./dotfiles/Kvantum/Dracula-purple-solid/Dracula-purple-solid.kvconfig;
      "Kvantum/Dracula-purple-solid/Dracula-purple-solid.svg".source = ./dotfiles/Kvantum/Dracula-purple-solid/Dracula-purple-solid.svg;
    };

    # File associations
    mimeApps = {
      enable = true;
      defaultApplications = {
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "image/gif" = "imv.desktop";
        "image/webp" = "imv.desktop";
        "image/bmp" = "imv.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        "text/html" = [ "firefox.desktop" "firefox-bin.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" "firefox-bin.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" "firefox-bin.desktop" ];
        "x-scheme-handler/about" = [ "firefox.desktop" "firefox-bin.desktop" ];
      };
    };
  };

  # ── Neovim / LazyVim ────────────────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;

    extraPackages = with pkgs; [
      # LSPs
      lua-language-server
      nil
      gopls
      nodePackages.typescript-language-server

      # Formatters
      stylua
      tree-sitter
      gotools
      gofumpt

      # Linters
      golangci-lint
      markdownlint-cli2

      # Go tools
      gomodifytags
      impl
      delve
    ];

    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];

    extraLuaConfig =
      let
        plugins = with pkgs.vimPlugins; [
          # Core
          unstableVim.LazyVim

          # UI
          snacks-nvim
          bufferline-nvim
          lualine-nvim
          mini-icons
          nvim-web-devicons
          noice-nvim
          nui-nvim
          nvim-notify
          dashboard-nvim
          dressing-nvim
          indent-blankline-nvim
          which-key-nvim

          # Editor
          neo-tree-nvim
          gitsigns-nvim
          flash-nvim
          todo-comments-nvim
          trouble-nvim
          vim-illuminate

          # Coding
          blink-cmp
          friendly-snippets
          nvim-lspconfig
          conform-nvim
          nvim-lint
          lazydev-nvim
          mini-pairs
          mini-ai
          mini-surround
          ts-comments-nvim

          # Treesitter
          (nvim-treesitter-unstable.withPlugins (p: with p; [
            bash c cpp css diff go html javascript json lua luadoc
            markdown markdown-inline nix python query regex rust
            toml tsx typescript vimdoc xml yaml
          ]))
          unstableVim.nvim-treesitter-textobjects
          unstableVim.nvim-ts-autotag

          # Telescope
          telescope-nvim
          telescope-fzf-native-nvim

          # Colorschemes
          tokyonight-nvim
          catppuccin-nvim

          # Go
          neotest
          neotest-golang
          nvim-dap
          nvim-dap-go
          none-ls-nvim

          # Claude Code
          claudecode-nvim

          # Markdown
          render-markdown-nvim
          markdown-preview-nvim

          # Misc
          plenary-nvim
          persistence-nvim
          vim-startuptime
        ];
        mkEntryFromDrv = drv:
          if lib.isDerivation drv then
            { name = "${lib.getName drv}"; path = drv; }
          else
            drv;
        lazyPath = pkgs.linkFarm "lazy-plugins" (builtins.map mkEntryFromDrv plugins);
      in
      ''
        require("lazy").setup({
          dev = {
            path = "${lazyPath}",
            patterns = { "" },
            fallback = true,
          },
          spec = {
            { "LazyVim/LazyVim", import = "lazyvim.plugins" },
            { import = "lazyvim.plugins.extras.ai.claudecode" },
            { import = "lazyvim.plugins.extras.lang.go" },
            { import = "lazyvim.plugins.extras.lang.markdown" },
            { import = "plugins" },
          },
          performance = {
            reset_packpath = false,
            rtp = {
              disabled_plugins = {
                "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin",
              },
            },
          },
        })
      '';
  };

  # ── Fish shell ──────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      if test -z "$SSH_AUTH_SOCK"
        eval (ssh-agent -c)
      end
      fish_add_path -m ~/.local/bin
    '';
  };


  # Re-activate home-manager on login to ensure symlinks survive GC
  systemd.user.startServices = "sd-switch";

  # ── Systemd user units ──────────────────────────────────────────────
  systemd.user = {
    services = {
      mako = {
        Unit.Description = "Wayland notifications manager";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.mako}/bin/mako --font 'JetBrainsMono NF' --text-color '#f8f8f2' --border-color '#bd93f9' --background-color '#141a1b' --border-size 3 --width 400 --height 200 --padding 20 --margin 20 --default-timeout 15000";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      autotiling = {
        Unit.Description = "Wayland autotiling";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.autotiling}/bin/autotiling";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      waybar = {
        Unit.Description = "Wayland bar";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.waybar}/bin/waybar -c %h/.config/waybar/config.jsonc -s %h/.config/waybar/style.css";
          Environment = "PATH=/run/current-system/sw/bin:%h/.local/bin";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      foot-server = {
        Unit = {
          Description = "Foot terminal server";
          Documentation = "man:foot(1)";
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.foot}/bin/foot --server";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      swayidle = {
        Unit.Description = "Sway idle service";
        Service = {
          Type = "simple";
          ExecStart = builtins.concatStringsSep " " [
            "${pkgs.swayidle}/bin/swayidle -w"
            "timeout 300 '${pkgs.swaylock-effects}/bin/swaylock --daemonize --show-failed-attempts --screenshots --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5 --fade-in 0.2'"
            "timeout 600 'swaymsg \"output * power off\"'"
            "resume 'swaymsg \"output * power on\"'"
            "before-sleep '${pkgs.swaylock-effects}/bin/swaylock --daemonize --show-failed-attempts --screenshots --clock --indicator --effect-blur 7x5 --effect-vignette 0.5:0.5 --fade-in 0.2'"
          ];
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      swayrd = {
        Unit = {
          Description = "Window switcher for Sway";
          Documentation = "https://sr.ht/~tsdh/swayr/";
          PartOf = [ "sway-session.target" ];
          After = [ "sway-session.target" ];
        };
        Service = {
          Type = "simple";
          Environment = "RUST_BACKTRACE=1";
          ExecStart = "${pkgs.swayr}/bin/swayrd";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      sworkstyle = {
        Unit.Description = "Sway icons on waybar";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.swayest-workstyle}/bin/sworkstyle -d -l error";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      wl-paste = {
        Unit.Description = "Wayland clipboard hook";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      polkit-agent = {
        Unit.Description = "Polkit Gnome Agent";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "always";
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      telegram = {
        Unit = {
          Description = "Telegram Desktop";
          After = [ "waybar.service" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.telegram-desktop}/bin/Telegram -startintray";
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      qbittorrent = {
        Unit.Description = "Qbittorrent";
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.qbittorrent}/bin/qbittorrent";
          Environment = "QT_STYLE_OVERRIDE=kvantum";
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      sync-audio-volumes = {
        Unit = {
          Description = "Sync audio device volume to application volumes";
          After = [ "pipewire.service" ];
          Wants = [ "pipewire.service" ];
        };
        Service = {
          Type = "simple";
          Environment = "PATH=/run/current-system/sw/bin";
          ExecStart = "%h/.local/bin/sync-audio-volumes.sh";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      dehox = {
        Unit = {
          Description = "Dehox OpenVPN";
          After = [ "network.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${openvpnBin} /etc/openvpn/dehox.ovpn";
          SyslogIdentifier = "dehox";
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      devment = {
        Unit = {
          Description = "Devment OpenVPN";
          After = [ "network.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${openvpnBin} /etc/openvpn/devment.ovpn";
          SyslogIdentifier = "devment";
        };
        Install.WantedBy = [ "sway-session.target" ];
      };

      loctok = {
        Unit = {
          Description = "LocTok video processing server";
          After = [ "network.target" ];
        };
        Service = {
          Type = "simple";
          WorkingDirectory = "/home/alpineq/projects/loctok";
          ExecStart = "/home/alpineq/projects/loctok/target/release/loctok-server --config config.toml";
          Environment = [
            "RUST_LOG=loctok_server=info"
            "PATH=/run/current-system/sw/bin:/usr/bin:/bin"
          ];
          Restart = "on-failure";
          RestartSec = 3;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };

    # sway-session.target for user services to bind to
    targets.sway-session = {
      Unit = {
        Description = "Sway compositor session";
        Documentation = [ "man:systemd.special(7)" ];
        BindsTo = [ "graphical-session.target" ];
        Wants = [ "graphical-session-pre.target" ];
        After = [ "graphical-session-pre.target" ];
      };
    };
  };
}
