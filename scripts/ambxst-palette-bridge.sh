#!/usr/bin/env bash
set -Eeuo pipefail

source_file="${HOME}/.cache/ambxst/colors.json"
destination="${XDG_STATE_HOME:-${HOME}/.local/state}/livara/theme/palette.dark.json"
[[ -s "$source_file" ]] || exit 0
mkdir -p "$(dirname "$destination")"
tmp="$(mktemp "$(dirname "$destination")/.palette.XXXXXX")"
browser_css="$(dirname "$destination")/browser/firefox.css"
wezterm_css="${XDG_CONFIG_HOME:-${HOME}/.config}/wezterm/colors/Ambxst.toml"
mkdir -p "$(dirname "$browser_css")"
mkdir -p "$(dirname "$wezterm_css")"
browser_tmp="$(mktemp "$(dirname "$browser_css")/.firefox.XXXXXX")"
wezterm_tmp="$(mktemp "${TMPDIR:-/tmp}/.ambxst-wezterm.XXXXXX")"
trap 'rm -f "$tmp" "$browser_tmp" "$wezterm_tmp"' EXIT
jq -e '
  def color($name; $fallback): (.[$name] // $fallback);
  {
    base: color("background"; "#111318"),
    primary: color("primary"; "#7bb7ff"),
    secondary: color("secondary"; "#70d7c3"),
    tertiary: color("tertiary"; "#e2c28c"),
    surface0: color("surface"; "#1a2029"),
    surface1: color("surfaceContainer"; "#242b36"),
    text: color("overBackground"; "#eef2f7"),
    subtext0: color("outline"; "#b2bdca"),
    blue: color("blue"; "#7bb7ff"),
    teal: color("cyan"; "#70d7c3"),
    red: color("red"; "#f0878a"),
    sapphire: color("lightBlue"; "#9bc9ff"),
    crust: color("surfaceContainerLowest"; "#07090d"),
    mantle: color("surfaceDim"; "#0b0d12"),
    overlay0: color("outline"; "#596575"),
    overlay1: color("outlineVariant"; "#6d7a8b")
  }
' "$source_file" > "$tmp"
mv -f "$tmp" "$destination"

read_color() {
  jq -r --arg name "$1" --arg fallback "$2" '.[$name] // .[$fallback] // .background // "#111318"' "$source_file"
}

background="$(read_color background surface)"
surface="$(read_color surface surfaceContainer)"
surface_variant="$(read_color surfaceVariant outlineVariant)"
foreground="$(read_color onBackground overBackground)"
primary="$(read_color primary blue)"
secondary="$(read_color secondary cyan)"

cat > "$browser_tmp" <<EOF
/* Generated from Ambxst ~/.cache/ambxst/colors.json. Do not edit. */
:root {
  --lwt-accent-color: ${background} !important;
  --lwt-text-color: ${foreground} !important;
  --toolbar-bgcolor: ${surface} !important;
  --toolbar-color: ${foreground} !important;
  --lwt-selected-tab-background-color: ${primary} !important;
  --tab-selected-bgcolor: ${primary} !important;
  --lwt-toolbar-field-background-color: ${surface_variant} !important;
  --lwt-toolbar-field-color: ${foreground} !important;
  --toolbar-field-focus-border-color: ${secondary} !important;
  --urlbarView-highlight-background: ${surface_variant} !important;
  --button-hover-bgcolor: ${surface_variant} !important;
}
EOF
chmod 0644 "$browser_tmp"
mv -f "$browser_tmp" "$browser_css"

cat > "$wezterm_tmp" <<EOF
# Generated from Ambxst ~/.cache/ambxst/colors.json. Do not edit.
[colors]
foreground = "${foreground}"
background = "${background}"
cursor_bg = "${primary}"
cursor_border = "${primary}"
cursor_fg = "${background}"
selection_bg = "${surface_variant}"
selection_fg = "${foreground}"
ansi = ["${background}", "$(read_color red primary)", "$(read_color green secondary)", "$(read_color yellow tertiary)", "${primary}", "${secondary}", "$(read_color cyan secondary)", "${foreground}"]
brights = ["${surface_variant}", "$(read_color red primary)", "$(read_color green secondary)", "$(read_color yellow tertiary)", "${primary}", "${secondary}", "$(read_color cyan secondary)", "${foreground}"]
EOF
chmod 0644 "$wezterm_tmp"
mv -f "$wezterm_tmp" "$wezterm_css"
