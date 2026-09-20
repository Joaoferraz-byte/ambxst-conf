{
  description = "Livara Ambxst shell integration for Niri and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/20b1ddd1aa5ace70c9468305030aa4f9ef79671b";
    ambxst = {
      url = "github:Axenide/Ambxst/7f0ac49b82497c6d273f7cd7e49d302904f440ed";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.axctl.url = "github:Axenide/axctl/dedcaa6769a577b0a0ea767631f5f4ec317fff59";
    };
    shell-conf = {
      url = "github:Joaoferraz-byte/shell-conf/807cfb5fe0f3ef9e1db3f16a02cf085021edc1b3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ambxst, shell-conf, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = nixpkgs.lib.genAttrs systems;

      fixedPackages = forEachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          lib = nixpkgs.lib;
          go1271 = pkgs.go_1_27.overrideAttrs (old: {
            version = "1.27.1";
            src = pkgs.fetchurl {
              url = "https://go.dev/dl/go1.27.1.src.tar.gz";
              hash = "sha256-TkCKuuEm2Ra2FkYnGT8sVPDjyhMS1pO4bbRfhiqyOLE=";
            };
          });
          buildGoModule = pkgs.buildGoModule.override { go = go1271; };
          axctlFixed = {
            packages.${system}.default = buildGoModule {
              pname = "axctl";
              version = "0.0.21";
              src = ambxst.inputs.axctl;
              subPackages = [ "." ];
              ldflags = [ "-X" "main.Version=0.0.21" ];
              vendorHash = "sha256-4PUs37IRhUPtuXi4KU8wOUErIkVlcnaoj94zBDBsMdk=";
            };
          };
          ambxstPackage = import "${ambxst}/nix/packages" {
            inherit pkgs lib system;
            axctl = axctlFixed;
            self = ambxst.outPath;
            version = lib.removeSuffix "\n" (builtins.readFile "${ambxst}/version");
          };
        in {
          default = ambxstPackage;
          Ambxst = ambxstPackage;
        });
    in {
      packages = fixedPackages;

      overlays.default = final: prev: {
        ambxst = fixedPackages.${final.stdenv.hostPlatform.system}.default;
      };

      nixosModules.default = { pkgs, lib, ... }:
        {
          imports = [ ambxst.nixosModules.default ];
          programs.ambxst.enable = lib.mkDefault true;
          programs.ambxst.package = lib.mkForce fixedPackages.${pkgs.stdenv.hostPlatform.system}.default;
        };
      nixosModules.ambxst = self.nixosModules.default;

      homeModules.default = { config, lib, pkgs, ... }:
        let
          ambxstPackage = fixedPackages.${pkgs.stdenv.hostPlatform.system}.default;
          paletteBridge = pkgs.writeShellApplication {
            name = "livara-ambxst-palette-bridge";
            runtimeInputs = with pkgs; [ bash coreutils jq ];
            text = builtins.readFile ./scripts/ambxst-palette-bridge.sh;
          };
        in {
          imports = [ shell-conf.homeModules.support-core ];
          home.packages = [ ambxstPackage paletteBridge ];
          home.sessionVariables = {
            AMBXST_VERSION = "1.3.7";
            LIVARA_AMBXST_THEME_ROOT = "${config.home.homeDirectory}/.cache/ambxst";
          };
          systemd.user.services.livara-ambxst-palette-bridge = {
            Unit = {
              Description = "Bridge Ambxst colors to Livara application adapters";
              After = [ "graphical-session.target" ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${paletteBridge}/bin/livara-ambxst-palette-bridge";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
          systemd.user.paths.livara-ambxst-palette-bridge = {
            Path = {
              PathChanged = "${config.home.homeDirectory}/.cache/ambxst/colors.json";
              Unit = "livara-ambxst-palette-bridge.service";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
      homeModules.ambxst = self.homeModules.default;

      checks = forEachSystem (system: let pkgs = import nixpkgs { inherit system; }; in {
        bridge-script = pkgs.runCommand "ambxst-palette-bridge-check" {
          nativeBuildInputs = [ pkgs.bash ];
        } ''
          bash -n ${self}/scripts/ambxst-palette-bridge.sh
          test -s ${self}/README.md
          touch "$out"
        '';
      });
    };
}
