# Ambxst integration

This flake packages the upstream Ambxst shell and provides a small Home Manager module. It does not maintain a wholesale fork of Ambxst, start a shell, edit Niri's main configuration, or generate application themes; it carries the tracked [`livara-ui-visibility.patch`](patches/livara-ui-visibility.patch) for Livara's bar and system-tray visibility policy.

The package tracks upstream [release 1.4.1](https://github.com/Axenide/Ambxst/releases/tag/1.4.1), commit `5db90ba000713b5cb991a2abce1b766ab47fbd2b`. Ambxst owns its process, generated `XDG_CONFIG_HOME/niri/axctl.generated.kdl`, and runtime palette under `~/.cache/ambxst`. Nix-conf owns Niri startup, include order, compositor policy, and local key bindings. Shell-conf owns application adapters and consumes the palette through its neutral contract.

The generated Niri file must be included after Ambxst has been installed but must never be linked into the Nix store or rewritten by a Home Manager activation. Local Niri overrides belong after the include. This separation prevents a second shell, a mutable-file race, and a duplicate layer-shell reservation.

The axctl revision locked by Ambxst 1.4.1 writes the Niri file to `$XDG_CONFIG_HOME/niri/axctl.generated.kdl`, falling back to `$HOME/.config/niri/axctl.generated.kdl`. This integration follows that implementation rather than an older Ambxst README example that referred to `~/.local/share/ambxst/niri.kdl`.

In Ambxst 1.4.1, OCR and QR are capture modes inside the screenshot UI, not standalone `ambxst run` actions in the upstream action catalog. The integration therefore leaves them available through that UI and keeps launcher, wallpaper, screenshot, and Lens bindings in `nix-conf`.
