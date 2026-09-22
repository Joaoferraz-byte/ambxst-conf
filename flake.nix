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
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      });

      mkAmbxstPackage = { pkgs, system }:
        let
          lib = pkgs.lib;
          patchedSource = pkgs.applyPatches {
            name = "ambxst-livara-ui-visibility";
            src = inputs.ambxst;
            patches = [ ./patches/livara-ui-visibility.patch ];
          };
        in import "${inputs.ambxst}/nix/packages/default.nix" {
          inherit pkgs lib system;
          self = patchedSource;
          axctl = inputs.ambxst.inputs.axctl;
          # Keep this static: reading applyPatches output with builtins.readFile
          # would require import-from-derivation during NixOS evaluation.
          version = "1.3.8";
        };

      packages = forAllSystems ({ pkgs }: {
        default = mkAmbxstPackage {
          inherit pkgs;
          system = pkgs.stdenv.hostPlatform.system;
        };
      });
    in {
      inherit packages;

      homeModules.default = { config, lib, pkgs, ... }:
        let
          ambxstPackage = packages.${pkgs.stdenv.hostPlatform.system}.default;
          ignoredDockAppPatterns = [
            "^(nm-applet|nm-connection-editor)$"
            "^(blueman-applet|blueman-manager)$"
            "^(com[.]github[.]wwmm[.]easyeffects|easyeffects|easy-effects)$"
          ];
        in {
          home.packages = [ ambxstPackage ];

          # Ambxst owns these mutable runtime paths. Home Manager only creates
          # their parents and applies the user's visibility policy below.
          home.activation.ambxstRuntimeDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p \
              "${config.home.homeDirectory}/.cache/ambxst" \
              "${config.home.homeDirectory}/.config/ambxst" \
              "${config.home.homeDirectory}/.config/niri"
          '';

          # Hide only the special application entries from Ambxst's dock. This
          # does not stop, uninstall, mask, or disable NetworkManager, Blueman,
          # Easy Effects, or their desktop applications.
          home.activation.ambxstSpecialApplicationVisibility = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ -z "''${DRY_RUN:-}" ]; then
              dock_file="${config.xdg.configHome}/ambxst/config/dock.json"
              install -d "$(dirname "$dock_file")"
              ignored_patterns='${builtins.toJSON ignoredDockAppPatterns}'

              if [ -s "$dock_file" ] && ${pkgs.jq}/bin/jq -e . "$dock_file" >/dev/null 2>&1; then
                ${pkgs.jq}/bin/jq --argjson patterns "$ignored_patterns" \
                  '.ignoredAppRegexes = (((.ignoredAppRegexes // []) + $patterns) | unique)' \
                  "$dock_file" > "$dock_file.tmp"
              else
                ${pkgs.jq}/bin/jq -n --argjson patterns "$ignored_patterns" \
                  '{ignoredAppRegexes: $patterns}' > "$dock_file.tmp"
              fi

              install -m 0644 "$dock_file.tmp" "$dock_file"
              rm -f "$dock_file.tmp"
            fi
          '';
        };

      checks = forAllSystems ({ pkgs }: {
        integration-contract = pkgs.runCommand "ambxst-integration-contract" {
          nativeBuildInputs = [ pkgs.git pkgs.patch pkgs.gnugrep ];
        } ''
          cp -R --no-preserve=mode ${inputs.ambxst}/. source
          chmod -R u+w source
          cd source
          patch --batch --forward --dry-run -p1 < ${./patches/livara-ui-visibility.patch}
          grep -Fq 'active: false' modules/bar/BarContent.qml
          grep -Fq 'nm-applet' modules/bar/systray/SysTray.qml
          grep -Fq 'com.github.wwmm.easyeffects' modules/bar/systray/SysTray.qml
          ! grep -Fq 'vesktop' modules/bar/systray/SysTray.qml
          ! grep -Fq 'bitwarden' modules/bar/systray/SysTray.qml
          touch $out
        '';
      });
    };
}
