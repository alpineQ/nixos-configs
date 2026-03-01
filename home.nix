{ config, pkgs, lib, ... }:

{
  home = {
    stateVersion = "25.11";
    username = "alpineq";
    homeDirectory = "/home/alpineq";

    # ── Custom scripts ───────────────────────────────────────────────────
    file.".local/bin/sync-audio-volumes.sh" = {
      executable = true;
      text = ''
        #!/bin/bash
        pactl subscribe | grep --line-buffered "sink #" | while read -r event; do
            sink_vol=$(pactl get-sink-volume @DEFAULT_SINK@ | head -1 | awk '{print $5}')
            pactl list short sink-inputs | while read -r input; do
                id=$(echo "$input" | awk '{print $1}')
                pactl set-sink-input-volume "$id" "$sink_vol"
            done
        done
      '';
    };

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

        case $1''' in
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
      };
    };
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

  # ── GTK theming ─────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme.name = "Dracula";
    iconTheme.name = "Dracula";
    cursorTheme.name = "Dracula-cursors";
    font = {
      name = "Roboto";
      size = 11;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

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
          ExecStart = "%h/.local/bin/sync-audio-volumes.sh";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
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
          Environment = "RUST_LOG=loctok_server=info";
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
