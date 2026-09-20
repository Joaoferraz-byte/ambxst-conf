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
              dock_dir="${config.xdg.configHome}/ambxst/config"
              dock_file="$dock_dir/dock.json"
              pinned_dir="${config.xdg.dataHome}/ambxst"
              pinned_file="$pinned_dir/pinnedapps.json"
              ignored_patterns='["^(nm-applet|nm-connection-editor)$","^(blueman-applet|blueman-manager)$"]'
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
                  '.apps = (((.apps // []) + $apps) | unique)' \
                  "$pinned_file" > "$pinned_file.tmp"
              else
                jq -n --argjson apps "$pinned_apps" \
                  '{apps: $apps}' > "$pinned_file.tmp"
              fi
              install -m 0644 "$pinned_file.tmp" "$pinned_file"
              rm -f "$pinned_file.tmp"

              wallpaper_dir="${config.home.homeDirectory}/Wallpapers"
              wallpaper_file="${config.xdg.cacheHome}/ambxst/wallpapers.json"
              install -d "$(dirname "$wallpaper_file")"
              if [ -s "$wallpaper_file" ] && jq -e . "$wallpaper_file" >/dev/null 2>&1; then
                jq --arg path "$wallpaper_dir" '.wallPath = $path | .tintEnabled = true | .activeColorPreset = ""' "$wallpaper_file" > "$wallpaper_file.tmp"
              else
                jq -n --arg path "$wallpaper_dir" \
                  '{currentWall:"", wallPath:$path, matugenScheme:"scheme-tonal-spot", activeColorPreset:"", tintEnabled:true, perScreenWallpapers:{}}' \
                  > "$wallpaper_file.tmp"
              fi
              install -m 0644 "$wallpaper_file.tmp" "$wallpaper_file"
              rm -f "$wallpaper_file.tmp"
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
