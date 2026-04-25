#!/bin/bash

set -euo pipefail

INPUT_DIR="$HOME/.local/bin/posthooks/fastfetch/pngs"
OUTPUT_DIR="$INPUT_DIR/generated"
COLOR_FILE="$HOME/.local/state/caelestia/theme/fastfetch"

echo "Debug: Checking dependencies..."
if ! command -v python3 &>/dev/null; then
	echo "python3 not found"
	exit 1
fi

if ! python3 -c "import PIL, numpy" 2>/dev/null; then
	echo "Missing Python modules: PIL or numpy"
	exit 1
fi

echo "Debug: INPUT_DIR=$INPUT_DIR"
echo "Debug: COLOR_FILE=$COLOR_FILE"

if [[ ! -f "$COLOR_FILE" ]]; then
	echo "Color file not found: $COLOR_FILE"
	exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
	echo "Input directory not found: $INPUT_DIR"
	exit 1
fi

# Base palette (4 colors)
BASE_COLORS=("#A9B1D6" "#C79BF0" "#EBBCBA" "#313244")

# Read replacement colors (one per base color)
echo "Debug: Reading colors from $COLOR_FILE"
mapfile -t REPLACEMENT_COLORS < <(
	sed 's/^[[:space:]]*//;s/[[:space:]]*$//' "$COLOR_FILE" |
		grep -Ei '^#?[0-9a-f]{6}$' | head -n ${#BASE_COLORS[@]}
)

echo "Debug: Found ${#REPLACEMENT_COLORS[@]} colors: ${REPLACEMENT_COLORS[*]}"

if [[ ${#REPLACEMENT_COLORS[@]} -ne ${#BASE_COLORS[@]} ]]; then
	echo "Expected ${#BASE_COLORS[@]} replacement colors in $COLOR_FILE, but got ${#REPLACEMENT_COLORS[@]}"
	exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Prepare Python list strings
base_str=$(printf '"%s", ' "${BASE_COLORS[@]}" | sed 's/, $//')
repl_str=$(printf '"%s", ' "${REPLACEMENT_COLORS[@]}" | sed 's/, $//')

png_files=("$INPUT_DIR"/*.png)
echo "Debug: Found ${#png_files[@]} PNG files: ${png_files[*]}"

for filepath in "$INPUT_DIR"/*.png; do
	[[ -f "$filepath" ]] || continue
	filename="$(basename "$filepath")"
	out_path="$OUTPUT_DIR/$filename"

	echo "Debug: Processing $filename -> $out_path"
	python3 <<EOF
from PIL import Image
import numpy as np

base_hex = [${base_str}]
target_hex = [${repl_str}]

def hex_to_rgb(hex_list):
    return [tuple(int(c[i:i+2], 16) for i in (0, 2, 4)) for c in [h.strip("#") for h in hex_list]]

base_rgb = hex_to_rgb(base_hex)
target_rgb = hex_to_rgb(target_hex)

img = Image.open("$filepath").convert("RGBA")
pixels = np.array(img)

# Separate RGB and Alpha
rgb_pixels = pixels[:, :, :3]
alpha_channel = pixels[:, :, 3:]

# Flatten for vector math
flat_pixels = rgb_pixels.reshape(-1, 3)

# Compute distances to base colors
distances = np.array([
    np.linalg.norm(flat_pixels - np.array(color), axis=1)
    for color in base_rgb
])

# Calculate soft weights
with np.errstate(divide='ignore'):
    weights = 1 / (distances + 1e-6)
weights /= weights.sum(axis=0)

# Interpolate output colors
target_matrix = np.array(target_rgb)
blended = np.tensordot(weights.T, target_matrix, axes=([1], [0]))
blended = np.clip(np.round(blended), 0, 255).astype(np.uint8)

# Rebuild output image
output_rgb = blended.reshape(rgb_pixels.shape)
result = np.dstack((output_rgb, alpha_channel))
Image.fromarray(result, "RGBA").save("$out_path")
EOF

done

rm -rf ~/.cache/fastfetch/images
echo "Generated icons saved to: $OUTPUT_DIR"
