#!/bin/bash

gtk_css="$HOME/.config/gtk-3.0/gtk.css"

if [ ! -f "$gtk_css" ]; then
    echo "Error: $gtk_css not found"
    exit 1
fi

accent_color=$(grep "accent_color" "$gtk_css" | sed -n 's/.*#\([a-fA-F0-9]*\);/\1/p')
window_bg=$(grep "window_bg_color" "$gtk_css" | sed -n 's/.*#\([a-fA-F0-9]*\);/\1/p')

if [ -z "$accent_color" ]; then
    echo "Error: accent_color not found in gtk.css"
    exit 1
fi

if [ -z "$window_bg" ]; then
    echo "Error: window_bg_color not found in gtk.css"
    exit 1
fi

if [ -n "$1" ]; then
    mode="$1"
else
    window_brightness=$((16#${window_bg:0:2}))
    if [ "$window_brightness" -lt 128 ]; then
        mode="Dark"
    else
        mode="Light"
    fi
fi

r=$((16#${accent_color:0:2}))
g=$((16#${accent_color:2:2}))
b=$((16#${accent_color:4:2}))

max_val=$((r > g ? (r > b ? r : b) : (g > b ? g : b)))
min_val=$((r < g ? (r < b ? r : b) : (g < b ? g : b)))

brightness=$max_val
saturation=$(( max_val == 0 ? 0 : ((max_val - min_val) * 100) / max_val ))

if [ "$saturation" -lt 15 ]; then
    if [ "$brightness" -lt 85 ]; then
        color="Black"
    elif [ "$brightness" -lt 170 ]; then
        color="Grey"
    else
        color="Grey"
    fi
elif [ "$brightness" -gt 180 ]; then
    if [ "$b" -gt "$r" ] && [ "$b" -gt "$g" ]; then
        color="Blue"
    elif [ "$r" -gt "$g" ] && [ "$r" -gt "$b" ]; then
        color="Magenta"
    elif [ "$g" -gt "$b" ]; then
        color="Cyan"
    else
        color="Grey"
    fi
elif [ "$b" -gt "$r" ] && [ "$b" -gt "$g" ]; then
    color="Blue"
elif [ "$r" -gt "$g" ] && [ "$r" -gt "$b" ]; then
    if [ "$g" -gt $((b + 30)) ]; then
        color="Orange"
    else
        color="Red"
    fi
elif [ "$g" -gt "$b" ]; then
    if [ "$r" -gt $((b + 30)) ]; then
        color="Yellow"
    else
        color="Green"
    fi
else
    color="Grey"
fi

theme="Flat-Remix-${color}-${mode}"
cli_json="$HOME/.config/caelestia/cli.json"

if [ -f "$cli_json" ]; then
    temp_file=$(mktemp)
    jq -r \
        --arg iconTheme "Flat-Remix-${color}-${mode}" \
        --arg iconThemeLight "Flat-Remix-${color}-Light" \
        --arg iconThemeDark "Flat-Remix-${color}-Dark" \
        '.theme.iconTheme = $iconTheme | .theme.iconThemeLight = $iconThemeLight | .theme.iconThemeDark = $iconThemeDark' \
        "$cli_json" > "$temp_file" && mv "$temp_file" "$cli_json"
fi

gsettings set org.gnome.desktop.interface icon-theme "$theme"
echo "Set icon theme to: $theme"