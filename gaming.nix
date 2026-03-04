{ pkgs, lib, ... }:

let
  steamAppsDir = "/mnt/data4/SteamLibrary/steamapps";
  compatBase = "/home/alpineq/.proton-compat";

  dirEntries = builtins.readDir steamAppsDir;

  appIds = lib.concatMap (name:
    let m = builtins.match "appmanifest_([0-9]+)\\.acf" name;
    in if m != null then m else []
  ) (builtins.attrNames dirEntries);

  mkCompatMount = appId: {
    name = "${steamAppsDir}/compatdata/${appId}";
    value = {
      device = "${compatBase}/${appId}";
      fsType = "none";
      options = [ "bind" "nofail" ];
    };
  };
in
{
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      extraPackages = with pkgs; [
        gamescope  # unwrapped binary available inside Steam's FHS sandbox
      ];
    };

    gamescope = {
      enable = true;
      capSysNice = false;  # capability wrapper breaks inside Steam's FHS sandbox
    };

    gamemode.enable = true;
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("com.feralinteractive.GameMode") === 0 &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Xbox wireless controller over Bluetooth
  hardware.xpadneo.enable = true;

  # Udev rules for Steam/Xbox/PS controllers
  hardware.steam-hardware.enable = true;

  # Bind-mount Proton compatdata from ext4 over exFAT so Wine prefixes
  # get proper symlink and permission support.
  fileSystems = builtins.listToAttrs (map mkCompatMount appIds);

  system.activationScripts.protonCompat = lib.concatMapStringsSep "\n"
    (appId: "mkdir -p ${compatBase}/${appId} && chown alpineq:alpineq ${compatBase}/${appId}")
    appIds;

  environment.systemPackages = with pkgs; [
    mangohud
  ];
}
