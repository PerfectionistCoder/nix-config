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

    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      home-manager-unstable,
      flake-utils,
      rust-overlay,
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
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (import rust-overlay)
          ];
        };
      in
      {
        formatter = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
        devShells = with pkgs; {
          rust = mkShell {
            nativeBuildInputs = [
              (pkgs.rust-bin.stable.latest.default.override {
                extensions = [
                  "rust-src"
                  "cargo"
                  "rustc"
                ];
              })
              gcc
            ];

            RUST_SRC_PATH = "${
              pkgs.rust-bin.stable.latest.default.override {
                extensions = [ "rust-src" ];
              }
            }/lib/rustlib/src/rust/library";

            buildInputs = [
              clippy
            ];
            shellHook = ''
              PATH+=":/home/desktop/.cargo/bin"

              cd ~/Code/rust

              codium --profile Rust .
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
