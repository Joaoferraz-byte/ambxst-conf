#!/usr/bin/env bash
set -Eeuo pipefail

source_file="${AMBXST_COLORS_SOURCE:-${HOME}/.cache/ambxst/colors.json}"
theme_root="${LIVARA_THEME_ROOT:-${XDG_STATE_HOME:-${HOME}/.local/state}/livara/theme}"
destination="${theme_root}/palette.dark.json"
compatibility_destination="${theme_root}/palette.json"
wezterm_scheme="${XDG_CONFIG_HOME:-${HOME}/.config}/wezterm/colors/Ambxst.toml"

if [[ ! -s "$source_file" ]]; then
  printf '%s\n' "[ambxst-palette-bridge] waiting for $source_file" >&2
  exit 0
fi

mkdir -p "$theme_root" "$(dirname "$wezterm_scheme")"

tmp_palette="$(mktemp "$theme_root/.palette.XXXXXX")"
tmp_compatibility="$(mktemp "$theme_root/.palette-compatibility.XXXXXX")"
tmp_wezterm="$(mktemp "${TMPDIR:-/tmp}/.ambxst-wezterm.XXXXXX")"
trap 'rm -f "$tmp_palette" "$tmp_compatibility" "$tmp_wezterm"' EXIT

# Ambxst exposes Material-style semantic colors. Livara adapters consume a
# stable Catppuccin-compatible alias layer. Keep the original Ambxst fields,
# then overlay validated aliases so every downstream consumer sees one source.
jq -e '
  def hex: type == "string" and test("^#[0-9A-Fa-f]{6}$");
  def pick($keys):
    . as $root
    | first($keys[] as $key | $root[$key]? | select(hex));
  def required($label; $keys):
    pick($keys) // error("missing or invalid Ambxst color: " + $label);

  . as $source
  | if ($source | type) != "object" then
      error("Ambxst colors.json must contain an object")
    else
      {
        base: required("base"; ["background"]),
        mantle: required("mantle"; ["surfaceDim", "surface"]),
        crust: required("crust"; ["surfaceContainerLowest", "surfaceDim", "surface"]),
        text: required("text"; ["overBackground", "white", "surface"]),
        subtext0: required("subtext0"; ["outline", "outlineVariant"]),
        subtext1: required("subtext1"; ["outlineVariant", "outline"]),
        surface0: required("surface0"; ["surface"]),
        surface1: required("surface1"; ["surfaceContainer"]),
        surface2: required("surface2"; ["surfaceContainerHigh", "surfaceContainer"]),
        overlay0: required("overlay0"; ["outline"]),
        overlay1: required("overlay1"; ["outlineVariant", "outline"]),
        overlay2: required("overlay2"; ["overSurfaceVariant", "outlineVariant", "outline"]),
        blue: required("blue"; ["blue", "primary"]),
        sapphire: required("sapphire"; ["lightBlue", "primaryContainer", "primary"]),
        peach: required("peach"; ["tertiary", "secondary", "primary"]),
        green: required("green"; ["green", "secondary", "primary"]),
        red: required("red"; ["red", "error", "primary"]),
        mauve: required("mauve"; ["magenta", "tertiary", "primary"]),
        pink: required("pink"; ["lightMagenta", "tertiary", "primary"]),
        maroon: required("maroon"; ["red", "error", "primary"]),
        yellow: required("yellow"; ["yellow", "tertiary", "primary"]),
        teal: required("teal"; ["cyan", "secondary", "primary"]),
        primary: required("primary"; ["primary"]),
        primary_container: required("primary_container"; ["primaryContainer", "surfaceContainer"]),
        secondary: required("secondary"; ["secondary", "primary"]),
        secondary_container: required("secondary_container"; ["secondaryContainer", "surfaceContainer"]),
        tertiary: required("tertiary"; ["tertiary", "primary"]),
        tertiary_container: required("tertiary_container"; ["tertiaryContainer", "surfaceContainer"]),
        error: required("error"; ["error", "red", "primary"]),
        error_container: required("error_container"; ["errorContainer", "surfaceContainer"]),
        on_primary: required("on_primary"; ["overPrimary", "background"]),
        on_secondary: required("on_secondary"; ["overSecondary", "background"]),
        on_tertiary: required("on_tertiary"; ["overTertiary", "background"]),
        on_error: required("on_error"; ["overError", "background"])
      } as $aliases
      | ($source + $aliases)
    end
' "$source_file" > "$tmp_palette"

# Keep the compatibility file in lockstep with the dark canonical palette.
cp -f "$tmp_palette" "$tmp_compatibility"
chmod 0644 "$tmp_palette" "$tmp_compatibility"
mv -f "$tmp_palette" "$destination"
mv -f "$tmp_compatibility" "$compatibility_destination"

read_color() {
  local name="$1"
  jq -er --arg name "$name" '.[$name] // error("missing canonical color: " + $name)' "$destination"
}

cat > "$tmp_wezterm" <<EOF
# Generated from Ambxst ~/.cache/ambxst/colors.json. Do not edit.
[colors]
foreground = "$(read_color text)"
background = "$(read_color base)"
cursor_bg = "$(read_color primary)"
cursor_border = "$(read_color primary)"
cursor_fg = "$(read_color base)"
selection_bg = "$(read_color surface1)"
selection_fg = "$(read_color text)"
ansi = ["$(read_color base)", "$(read_color red)", "$(read_color green)", "$(read_color yellow)", "$(read_color blue)", "$(read_color teal)", "$(read_color sapphire)", "$(read_color text)"]
brights = ["$(read_color surface1)", "$(read_color red)", "$(read_color green)", "$(read_color yellow)", "$(read_color blue)", "$(read_color teal)", "$(read_color sapphire)", "$(read_color text)"]
EOF
chmod 0644 "$tmp_wezterm"
mv -f "$tmp_wezterm" "$wezterm_scheme"
