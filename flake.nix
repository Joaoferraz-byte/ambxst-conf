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
      url = "github:Joaoferraz-byte/shell-conf/eb44268704cac46b8cb81befa7b86a1e329011e2";
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
          ambxstBasePackage = import "${ambxst}/nix/packages" {
            inherit pkgs lib system;
            axctl = axctlFixed;
            self = ambxst.outPath;
            version = "1.3.7";
          };
          ambxstPatched = pkgs.applyPatches {
            name = "ambxst-livara-shell";
            src = ambxst;
            patches = [ ./patches/livara-defaults.patch ];
          };
          ambxstPackage = pkgs.runCommand "Ambxst-1.3.7" {
            nativeBuildInputs = [ pkgs.makeWrapper ];
            meta.mainProgram = "ambxst";
          } ''
            mkdir -p "$out/bin"
            makeWrapper "${ambxstBasePackage}/bin/ambxst" "$out/bin/ambxst" \
              --set AMBXST_SHELL "${ambxstPatched}"
          '';
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
          ambxstDefaultPreset = "${ambxst}/assets/presets/Ambxst Default";
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
          # Ambxst persists dock preferences outside the Nix store. Seed only
          # the Livara policy and merge it with existing user preferences so
          # the shell remains free to update its JSON files at runtime.
          home.activation.livaraAmbxstDockPolicy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if [ -z "''${DRY_RUN:-}" ]; then
              ambxst_config_dir="${config.xdg.configHome}/ambxst"
              ambxst_config_files="$ambxst_config_dir/config"
              ambxst_preset_state="$ambxst_config_dir/presets/active_preset"
              if [ ! -s "$ambxst_preset_state" ]; then
                install -d "$ambxst_config_files" "$(dirname "$ambxst_preset_state")"
                for preset_file in bar compositor desktop dock lockscreen notch overview performance theme workspaces; do
                  if [ ! -e "$ambxst_config_files/$preset_file.json" ]; then
                    install -m 0644 "${ambxstDefaultPreset}/$preset_file.json" "$ambxst_config_files/$preset_file.json"
                  fi
                done
                printf '%s\n' 'Ambxst Default' > "$ambxst_preset_state"
              fi

              workspaces_file="$ambxst_config_files/workspaces.json"
              if [ -s "$workspaces_file" ] && jq -e . "$workspaces_file" >/dev/null 2>&1; then
                jq '.showAppIcons = false | .shown = 3' "$workspaces_file" > "$workspaces_file.tmp"
                install -m 0644 "$workspaces_file.tmp" "$workspaces_file"
                rm -f "$workspaces_file.tmp"
              fi

              dock_dir="${config.xdg.configHome}/ambxst/config"
              dock_file="$dock_dir/dock.json"
              pinned_dir="${config.xdg.dataHome}/ambxst"
              pinned_file="$pinned_dir/pinnedapps.json"
              ignored_patterns='["^(nm-applet|nm-connection-editor)$","^(blueman-applet|blueman-manager)$","^(com[.]github[.]wwmm[.]easyeffects|easyeffects|easy-effects)$"]'
              pinned_apps='["vesktop","nvim","org.telegram.desktop","com.github.xournalpp.xournalpp","zen-beta"]'

              install -d "$dock_dir" "$pinned_dir"

              if [ -s "$dock_file" ] && jq -e . "$dock_file" >/dev/null 2>&1; then
                jq --argjson patterns "$ignored_patterns" \
                  '.ignoredAppRegexes = (((.ignoredAppRegexes // []) + $patterns) | unique)' \
                  "$dock_file" > "$dock_file.tmp"
              else
                printf '%s\n' '{"ignoredAppRegexes":["quickshell.*","xdg-desktop-portal.*"]}' > "$dock_file.tmp"
                jq --argjson patterns "$ignored_patterns" \
                  '.ignoredAppRegexes = (((.ignoredAppRegexes // []) + $patterns) | unique)' \
                  "$dock_file.tmp" > "$dock_file.tmp2"
                mv -f "$dock_file.tmp2" "$dock_file.tmp"
              fi
              install -m 0644 "$dock_file.tmp" "$dock_file"
              rm -f "$dock_file.tmp"

              if [ -s "$pinned_file" ] && jq -e . "$pinned_file" >/dev/null 2>&1; then
                jq --argjson apps "$pinned_apps" \
                  --arg managed_easyeffects '^(com[.]github[.]wwmm[.]easyeffects|easyeffects|easy-effects)$' \
                  '.apps = ([ (.apps // [])[] | select((tostring | test($managed_easyeffects; "i")) | not) ] + $apps | unique)' \
                  "$pinned_file" > "$pinned_file.tmp"
              else
                jq -n --argjson apps "$pinned_apps" \
                  '{apps: $apps}' > "$pinned_file.tmp"
              fi
              install -m 0644 "$pinned_file.tmp" "$pinned_file"
              rm -f "$pinned_file.tmp"

            fi
          '';
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
        patch-applies = pkgs.runCommand "ambxst-livara-patch-check" {
          nativeBuildInputs = [ pkgs.git ];
        } ''
          cp -R --no-preserve=mode ${ambxst}/. source
          chmod -R u+w source
          cd source
          git apply --check --unidiff-zero ${self}/patches/livara-defaults.patch
          touch "$out"
        '';

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
