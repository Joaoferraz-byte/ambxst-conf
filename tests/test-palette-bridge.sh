#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bridge="$repo_root/scripts/ambxst-palette-bridge.sh"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

export HOME="$root/home"
export XDG_CONFIG_HOME="$root/config"
export XDG_STATE_HOME="$root/state"
export AMBXST_COLORS_SOURCE="$HOME/.cache/ambxst/colors.json"
export LIVARA_THEME_ROOT="$XDG_STATE_HOME/livara/theme"
mkdir -p "$(dirname "$AMBXST_COLORS_SOURCE")"

cat > "$AMBXST_COLORS_SOURCE" <<'EOF'
{
  "background": "#111318",
  "surface": "#1a2029",
  "surfaceContainer": "#242b36",
  "surfaceContainerHigh": "#303946",
  "surfaceContainerLowest": "#07090d",
  "surfaceDim": "#0b0d12",
  "overBackground": "#eef2f7",
  "outline": "#596575",
  "outlineVariant": "#6d7a8b",
  "overSurfaceVariant": "#8b9aaa",
  "primary": "#7bb7ff",
  "primaryContainer": "#263b55",
  "secondary": "#70d7c3",
  "secondaryContainer": "#254634",
  "tertiary": "#e7a9c3",
  "tertiaryContainer": "#4d3447",
  "error": "#f0878a",
  "errorContainer": "#512d34",
  "overPrimary": "#0c1420",
  "overSecondary": "#0d1a13",
  "overTertiary": "#2b1927",
  "overError": "#2a1218",
  "blue": "#7bb7ff",
  "cyan": "#70d7c3",
  "green": "#83d6a3",
  "red": "#f0878a",
  "magenta": "#c2a4f5",
  "lightMagenta": "#e7a9c3",
  "yellow": "#e8cf85",
  "lightBlue": "#72d4e6"
}
EOF

bash "$bridge"
canonical="$LIVARA_THEME_ROOT/palette.dark.json"
compatibility="$LIVARA_THEME_ROOT/palette.json"
wezterm="$XDG_CONFIG_HOME/wezterm/colors/Ambxst.toml"
[[ -s "$canonical" && -s "$compatibility" && -s "$wezterm" ]]
jq -e '.base == .background and .surface0 == .surface and .surface1 == .surfaceContainer and .blue == .primary and .overlay0 == .outline' "$canonical" >/dev/null
jq -e 'to_entries | all(.value | type == "string" and test("^#[0-9A-Fa-f]{6}$"))' "$canonical" >/dev/null
grep -q 'foreground = "#eef2f7"' "$wezterm"
! grep -q 'browser/firefox.css' "$bridge"

before="$(sha256sum "$canonical" "$compatibility" "$wezterm")"
printf '%s\n' '{"background":"not-a-color"}' > "$AMBXST_COLORS_SOURCE"
if bash "$bridge" >/dev/null 2>&1; then
  echo 'invalid colors.json was accepted' >&2
  exit 1
fi
after="$(sha256sum "$canonical" "$compatibility" "$wezterm")"
[[ "$before" == "$after" ]]

printf '%s\n' 'Ambxst palette bridge contract passed'
