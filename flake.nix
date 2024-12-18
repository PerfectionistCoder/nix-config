{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      home-manager-unstable,
      flake-utils,
      ...
    }@inputs:
    let
      customLib = import ./custom-lib { inherit inputs; };
    in
    with builtins;
    with customLib;
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
        devShells = {
          py = pkgs.mkShell {
            packages = with pkgs; [
              (pkgs.python312.withPackages (python-pkgs: with python-pkgs; [ ]))
              poetry
            ];
            shellHook = ''
              export VIRTUAL_ENV_DISABLE_PROMPT=1

              codium --profile Python
            '';
          };
        };
      }
    )
    // (
      let
        nixosModules = import ./nixos-modules;
        homeManagerModules = import ./home-manager;
        hostsDir = ./hosts;

        mkHost =
          params:
          with params;
          (if stable then nixpkgs else nixpkgs-unstable).lib.nixosSystem {
            pkgs = getPkgs system stable;
            specialArgs = {
              inherit inputs customLib;
            } // params;
            modules = [
              configPath
              nixosModules
            ];
          };
        mkHomeManager =
          params:
          with params;
          (if stable then home-manager else home-manager-unstable).lib.homeManagerConfiguration {
            pkgs = getPkgs system stable;
            extraSpecialArgs = {
              inherit inputs customLib flakeHostname;
              stable-pkgs = getPkgs system true;
            } // params;
            modules = [
              configPath
              homeManagerModules
            ];
          };
        genConfiguration =
          path: type:
          assert builtins.match "home-configuration|configuration" type != null;
          builtins.listToAttrs (
            map (
              hostPath:
              let
                flakeHostname = customLib.subDirName hostPath;
                value = (if type == "home-configuration" then mkHomeManager else mkHost) (
                  {
                    inherit flakeHostname;
                    configPath = hostPath + "/${type}.nix";
                  }
                  // import (hostPath + "/params.nix")
                );
              in
              {
                inherit value;
                name = flakeHostname;
              }
            ) (customLib.dirsIn path)
          );
      in
      {
        nixosConfigurations = genConfiguration hostsDir "configuration";
        homeConfigurations = genConfiguration hostsDir "home-configuration";
      }
    );
}
