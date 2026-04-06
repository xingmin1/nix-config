{pkgs, ...}: {
  home.packages = with pkgs; [
    pass
    pinentry-curses
  ];

  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
