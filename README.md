# Ambxst integration

This flake exposes the **upstream Ambxst package** and one small Home Manager module. It deliberately does not fork QML, patch upstream files, start a shell, edit Niri configuration, or generate application themes.

The package is pinned to upstream commit `c62a7acc443dbb1c9045e83466402528cc522af2` (Ambxst 1.3.8). The package owns the Ambxst process, the generated `XDG_CONFIG_HOME/niri/axctl.generated.kdl`, and its runtime palette under `~/.cache/ambxst`. Nix-conf owns Niri startup, include order, compositor policy, and local key bindings. Shell-conf owns application adapters and consumes the palette through its neutral contract.

The generated Niri file must be included after Ambxst has been installed but must never be linked into the Nix store or rewritten by a Home Manager activation. Local Niri overrides belong after the include. This separation prevents a second shell, a mutable-file race, and a duplicate layer-shell reservation.

The current axctl source resolves the Niri output as `$XDG_CONFIG_HOME/niri/axctl.generated.kdl`, falling back to `$HOME/.config/niri/axctl.generated.kdl`. This repository follows the implementation rather than an older Ambxst README example that referred to `~/.local/share/ambxst/niri.kdl`.

OCR and QR are not declared as `ambxst run` actions because upstream 1.3.8 does not expose those IPC commands. They require a separate, explicitly reviewed capture implementation. Launcher, wallpaper, screenshot, and Lens are upstream actions and are configured in `nix-conf`.
