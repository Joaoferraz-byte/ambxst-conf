{
  description = "Livara Ambxst shell integration for Niri and NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ambxst = {
      url = "github:Axenide/Ambxst/7f0ac49b82497c6d273f7cd7e49d302904f440ed";
      inputs.nixpkgs.follows = "nixpkgs";
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
    in {
      packages = forEachSystem (system: {
        default = ambxst.packages.${system}.default;
        Ambxst = ambxst.packages.${system}.Ambxst;
      });

      overlays.default = final: prev: {
        ambxst = ambxst.packages.${final.system}.default;
      };

      nixosModules.default = { pkgs, lib, ... }:
        {
          imports = [ ambxst.nixosModules.default ];
          programs.ambxst.enable = lib.mkDefault true;
          programs.ambxst.package = lib.mkDefault self.packages.${pkgs.system}.default;
        };
      nixosModules.ambxst = self.nixosModules.default;

      homeModules.default = { config, lib, pkgs, ... }:
        let
          ambxstPackage = ambxst.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
