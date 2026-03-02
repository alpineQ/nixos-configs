{ pkgs, ... }:

{
  programs = {
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
    };

    gamescope = {
      enable = true;
      capSysNice = true;  # lets gamescope renice itself for lower latency
    };

    gamemode.enable = true;
  };

  # Xbox wireless controller over Bluetooth
  hardware.xpadneo.enable = true;

  # Udev rules for Steam/Xbox/PS controllers
  hardware.steam-hardware.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
  ];
}
