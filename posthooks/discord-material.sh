#!/usr/bin/env bash

FILE="$HOME/.local/state/caelestia/theme/discord-material.theme.css"

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

rgb_val=$(grep -- '--accent-hue:' "$FILE" | sed 's/.*rgb(\([^)]*\)).*/\1/')
IFS=',' read -r r g b <<< "$rgb_val"
r=${r# }
g=${g# }
b=${b# }

r_f=$(echo "scale=4; $r / 255" | bc)
g_f=$(echo "scale=4; $g / 255" | bc)
b_f=$(echo "scale=4; $b / 255" | bc)

max=$(echo "$r_f $g_f $b_f" | tr ' ' '\n' | sort -n | tail -1)
min=$(echo "$r_f $g_f $b_f" | tr ' ' '\n' | sort -n | head -1)
delta=$(echo "scale=4; $max - $min" | bc)

l=$(echo "scale=4; ($max + $min) / 2" | bc)

if [ "$(echo "$delta == 0" | bc)" -eq 1 ]; then
    h=0
    s=0
else
    if [ "$(echo "$l > 0.5" | bc)" -eq 1 ]; then
        denom=$(echo "scale=4; 2 - 2 * $l" | bc)
    else
        denom=$(echo "scale=4; 2 * $l" | bc)
    fi
    s=$(echo "scale=4; $delta / $denom" | bc)

    if [ "$(echo "$max == $r_f" | bc)" -eq 1 ]; then
        h=$(echo "scale=4; ($g_f - $b_f) / $delta" | bc)
    elif [ "$(echo "$max == $g_f" | bc)" -eq 1 ]; then
        h=$(echo "scale=4; ($b_f - $r_f) / $delta + 2" | bc)
    else
        h=$(echo "scale=4; ($r_f - $g_f) / $delta + 4" | bc)
    fi
fi

h=$(echo "scale=0; $h * 60 / 1" | bc)
if [ "$h" -lt 0 ] 2>/dev/null; then
    h=$((h + 360))
fi

s=$(echo "scale=0; $s * 100 / 1" | bc)
l_pct=$(echo "scale=0; $l * 100 / 1" | bc)

sed -i "s/--accent-hue: rgb($rgb_val);/--accent-hue: $h;/" "$FILE"
sed -i "s/--accent-saturation: rgb($rgb_val);/--accent-saturation: $s%;/" "$FILE"
sed -i "s/--accent-lightness: rgb($rgb_val);/--accent-lightness: $l_pct%;/" "$FILE"

echo "Converted rgb($rgb_val) -> HSL($h, $s%, $l_pct%)"