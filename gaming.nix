{ pkgs, ... }:

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

  environment.systemPackages = with pkgs; [
    mangohud
  ];
}
