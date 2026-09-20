#!/usr/bin/env bash
set -Eeuo pipefail

source_file="${HOME}/.cache/ambxst/colors.json"
destination="${XDG_STATE_HOME:-${HOME}/.local/state}/livara/theme/palette.dark.json"
[[ -s "$source_file" ]] || exit 0
mkdir -p "$(dirname "$destination")"
tmp="$(mktemp "$(dirname "$destination")/.palette.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
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
