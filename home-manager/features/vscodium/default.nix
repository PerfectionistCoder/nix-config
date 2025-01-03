{
  lib,
  pkgs,
  config,
  ...
}:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    userSettings = {
      "editor.tabSize" = 2;
      "explorer.confirmDragAndDrop" = false;
      "explorer.confirmDelete" = false;
      "terminal.integrated.defaultProfile.linux" = config.custom.defaultShellCommand;
      "git.confirmSync" = false;
      "workbench.startupEditor" = "none";
      "terminal.integrated.enablePersistentSessions" = false;
      "window.titleBarStyle" = "custom";
      "javascript.updateImportsOnFileMove.enabled" = "always";
      "nix.formatterPath" = "nixfmt";
      "[nix]" = {
        "editor.defaultFormatter" = "jnoortheen.nix-ide";
      };
      "rust-analyzer.check.command" = "clippy";
    };
    extensions = with pkgs; [ vscode-extensions.jnoortheen.nix-ide ];
  };

  xdg.configFile."codium-flags.conf".text = ''
    --enable-features=WaylandWindowDecorations
    --ozone-platform-hint=auto
  '';
}
