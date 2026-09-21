{
  description = "Declarative Ambxst integration for Livara";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ambxst.url = "github:Axenide/Ambxst/2a704c438ddc0b94a11f4e4cf32a16220b62141f";
    ambxst.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
      });
    in {
      packages = forAllSystems ({ pkgs }: {
        default = inputs.ambxst.packages.${pkgs.system}.default;
      });

      homeModules.default = { config, lib, pkgs, ... }:
        let
          package = inputs.ambxst.packages.${pkgs.system}.default;
        in {
          home.packages = [ package ];

          # Ambxst/axctl owns these mutable runtime paths. Home Manager only
          # creates their parents; it never links or rewrites generated files.
          home.activation.ambxstRuntimeDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p \
              "${config.home.homeDirectory}/.cache/ambxst" \
              "${config.home.homeDirectory}/.config/ambxst" \
              "${config.home.homeDirectory}/.config/niri"
          '';
        };

      checks = forAllSystems ({ pkgs }: {
        integration-contract = pkgs.runCommand "ambxst-integration-contract" { } ''
          test -f ${./flake.nix}
          grep -Fq '2a704c438ddc0b94a11f4e4cf32a16220b62141f' ${./flake.nix}
          grep -Fq 'homeModules.default' ${./flake.nix}
          ! grep -Eq 'patches/|run.*ocr|run.*qr|noctalia' ${./flake.nix}
          touch $out
        '';
      });
    };
}
