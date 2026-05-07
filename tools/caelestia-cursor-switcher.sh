#!/usr/bin/env bash
# Interactive cursor pack installer
# ==============================================================================
#  CURSOR INSTALLER (INTERACTIVE)
#  - Scans for installed cursor themes (no duplicates)
#  - Shows supported sizes
#  - Installs to /usr/share/icons if needed
#  - Updates system and user index.theme
#  - Updates ~/.config/caelestia/hypr-vars.conf
#  - Updates SDDM cursor config
#  - Updates Hyprland session live
# ==============================================================================

set -o errexit
set -o pipefail
shopt -s inherit_errexit 2>/dev/null || true

readonly CAELESTIA_VARS="${HOME}/.config/caelestia/hypr-vars.conf"
readonly XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly ICON_DIR="${XDG_DATA_HOME}/icons"
readonly SYSTEM_ICON_DIR="/usr/share/icons"
readonly SYSTEM_DEFAULT="/usr/share/icons/default"
readonly SDDM_CONF_DIR="/etc/sddm.conf.d"

readonly SOBER_CURSOR_DIR="$HOME/.var/app/org.vinegarhq.Sober/data/sober/asset_overlay/content/textures/Cursors/KeyboardMouse"
readonly SOBER_MOUSE_DIR="$HOME/.var/app/org.vinegarhq.Sober/data/sober/asset_overlay/content/textures"

if [[ -t 1 ]]; then
    BLUE=$(tput setaf 4)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    RESET=$(tput sgr0)
    BOLD=$(tput bold)
else
    BLUE="" GREEN="" YELLOW="" RED="" RESET="" BOLD=""
fi

log_info()    { printf "%s[INFO]%s %s\n" "${BLUE}" "${RESET}" "$*"; }
log_success() { printf "%s[OK]%s %s\n" "${GREEN}" "${RESET}" "$*"; }
log_warn()    { printf "%s[WARN]%s %s\n" "${YELLOW}" "${RESET}" "$*" >&2; }
log_error()   { printf "%s[ERROR]%s %s\n" "${RED}" "${RESET}" "$*" >&2; }
prompt_yes_no() {
    local prompt="$1"
    local response
    echo ""
    echo -n "${YELLOW}${prompt} [Y/n]: ${RESET}"
    read -r response < /dev/tty
    case "$response" in
        [Nn]) return 1 ;;
        *) return 0 ;;
    esac
}

die() { log_error "$*"; exit 1; }

get_available_cursors() {
    local -a themes=()

    for dir in "$SYSTEM_ICON_DIR" "$ICON_DIR"; do
        [[ -d "$dir" ]] || continue
        for theme_dir in "$dir"/*; do
            [[ -d "$theme_dir" ]] || continue
            local name
            name=$(basename "$theme_dir")
            if [[ -d "$theme_dir/cursors" || -d "$theme_dir/cursors_scalable" ]]; then
                themes+=("$name")
            fi
        done
    done

    printf '%s\n' "${themes[@]}" | sort -u
}

install_to_system() {
    local theme_name="$1"
    local source_path

    if [[ -d "${ICON_DIR}/${theme_name}" ]]; then
        source_path="${ICON_DIR}/${theme_name}"
    elif [[ -d "${HOME}/.local/share/icons/${theme_name}" ]]; then
        source_path="${HOME}/.local/share/icons/${theme_name}"
    else
        log_error "Theme not found in local icons."
        return 1
    fi

    if [[ -d "${SYSTEM_ICON_DIR}/${theme_name}" ]]; then
        log_info "Theme already in system icons."
        return 0
    fi

    log_info "Installing ${theme_name} to system icons..."
    if sudo cp -r "$source_path" "$SYSTEM_ICON_DIR/"; then
        log_success "Installed to ${SYSTEM_ICON_DIR}/${theme_name}"
        return 0
    else
        log_error "Failed to install to system icons."
        return 1
    fi
}

update_system_index() {
    local theme_name="$1"
    sudo mkdir -p "$SYSTEM_DEFAULT"
    sudo tee "${SYSTEM_DEFAULT}/index.theme" > /dev/null <<EOF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=${theme_name}
EOF
    log_success "Updated system index.theme."
}

get_cursor_sizes() {
    local theme_name="$1"
    local theme_path

    if [[ -d "${SYSTEM_ICON_DIR}/${theme_name}" ]]; then
        theme_path="${SYSTEM_ICON_DIR}/${theme_name}"
    elif [[ -d "${ICON_DIR}/${theme_name}" ]]; then
        theme_path="${ICON_DIR}/${theme_name}"
    else
        printf '24\n28\n32\n'
        return
    fi

    if [[ -d "${theme_path}/cursors_scalable" ]]; then
        printf '24\n28\n32\n36\n40\n48\n64\n72\n96\n'
        return
    fi

    local -a valid_sizes=(8 10 12 14 16 18 20 22 24 28 32 36 40 48 64 72 80 96 128 256)
    local -a found_sizes=()

    if [[ -d "${theme_path}/cursors" ]]; then
        for cursor_file in "${theme_path}"/cursors/*; do
            [[ -f "$cursor_file" ]] || continue
            local basename
            basename=$(basename "$cursor_file")
            for size in "${valid_sizes[@]}"; do
                if [[ "$basename" == "${size}"* ]]; then
                    found_sizes+=("$size")
                    break
                fi
            done
        done
    fi

    if [[ ${#found_sizes[@]} -gt 0 ]]; then
        printf '%s\n' "${found_sizes[@]}" | sort -n | uniq
    else
        printf '24\n28\n32\n'
    fi
}

update_caelestia_vars() {
    local theme="$1"
    local size="$2"

    if [[ ! -f "$CAELESTIA_VARS" ]]; then
        die "Caelestia vars file not found: ${CAELESTIA_VARS}"
    fi

    local tmp_file
    tmp_file=$(mktemp)

    local skip_block=false
    local in_cursor_block=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\$cursorTheme ]]; then
            in_cursor_block=true
            skip_block=true
            printf '$cursorTheme = %s\n' "$theme"
        elif [[ "$in_cursor_block" && "$line" =~ ^\$cursorSize ]]; then
            printf '$cursorSize = %s\n' "$size"
            in_cursor_block=false
            skip_block=false
        elif [[ "$in_cursor_block" && "$line" =~ ^env.*XCURSOR_THEME ]]; then
            printf 'env = XCURSOR_THEME,%s\n' "$theme"
        elif [[ "$in_cursor_block" && "$line" =~ ^env.*XCURSOR_SIZE ]]; then
            printf 'env = XCURSOR_SIZE,%s\n' "$size"
            in_cursor_block=false
            skip_block=false
        elif [[ "$skip_block" && "$line" =~ ^\$ ]]; then
            in_cursor_block=false
            skip_block=false
            printf '%s\n' "$line"
        elif [[ "$skip_block" && "$line" =~ ^env ]]; then
            in_cursor_block=false
            skip_block=false
            printf '%s\n' "$line"
        else
            printf '%s\n' "$line"
        fi
    done < "$CAELESTIA_VARS" > "$tmp_file"

    mv "$tmp_file" "$CAELESTIA_VARS"
    log_success "Updated Caelestia vars: ${theme} @ ${size}"
}

update_legacy_index() {
    local theme_name="$1"
    local default_dir="${ICON_DIR}/default"
    mkdir -p "$default_dir"
    cat > "${default_dir}/index.theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=${theme_name}
EOF
    log_info "Updated legacy index.theme fallback."
}

update_xresources() {
    local theme="$1"
    local size="$2"
    local xresources="${HOME}/.Xresources"

    mkdir -p "$(dirname "$xresources")"

    local tmp_file
    tmp_file=$(mktemp)

    local found_theme=false
    local found_size=false
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^Xcursor\.theme ]]; then
            printf 'Xcursor.theme: %s\n' "$theme"
            found_theme=true
        elif [[ "$line" =~ ^Xcursor\.size ]]; then
            printf 'Xcursor.size: %s\n' "$size"
            found_size=true
        else
            printf '%s\n' "$line"
        fi
    done < "$xresources" > "$tmp_file" 2>/dev/null || true

    if [[ "$found_theme" == "false" ]]; then
        printf '\nXcursor.theme: %s\n' "$theme" >> "$tmp_file"
    fi
    if [[ "$found_size" == "false" ]]; then
        printf 'Xcursor.size: %s\n' "$size" >> "$tmp_file"
    fi

    mv "$tmp_file" "$xresources"
    log_success "Updated .Xresources"
}

update_gtk_settings() {
    local theme="$1"
    local size="$2"
    local gtk_dir="$3"
    local settings_file="${gtk_dir}/settings.ini"

    mkdir -p "$gtk_dir"

    local tmp_file
    tmp_file=$(mktemp)

    local has_settings=false
    local found_theme=false
    local found_size=false

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "[Settings]" ]]; then
            has_settings=true
            printf '%s\n' "$line"
        elif [[ "$has_settings" && "$line" =~ ^gtk-cursor-theme-name ]]; then
            printf 'gtk-cursor-theme-name=%s\n' "$theme"
            found_theme=true
        elif [[ "$has_settings" && "$line" =~ ^gtk-cursor-theme-size ]]; then
            printf 'gtk-cursor-theme-size=%s\n' "$size"
            found_size=true
        else
            printf '%s\n' "$line"
        fi
    done < "$settings_file" > "$tmp_file" 2>/dev/null || true

    if [[ "$has_settings" == "false" ]]; then
        printf '[Settings]\n' > "$tmp_file"
        cat >> "$tmp_file" < "$settings_file" 2>/dev/null || true
    fi

    if [[ "$found_theme" == "false" ]]; then
        printf 'gtk-cursor-theme-name=%s\n' "$theme" >> "$tmp_file"
    fi
    if [[ "$found_size" == "false" ]]; then
        printf 'gtk-cursor-theme-size=%s\n' "$size" >> "$tmp_file"
    fi

    mv "$tmp_file" "$settings_file"
    log_success "Updated ${settings_file}"
}

update_sddm() {
    local theme="$1"
    local size="$2"

    sudo mkdir -p "$SDDM_CONF_DIR"

    if [[ -f "${SDDM_CONF_DIR}/caelestia.conf" ]]; then
        local current_size
        current_size=$(sudo grep -i "CursorSize" "${SDDM_CONF_DIR}/caelestia.conf" 2>/dev/null | head -1 || true)
        if [[ -n "$current_size" ]]; then
            log_info "Found existing SDDM config: ${current_size}"
        fi
    fi

    if prompt_yes_no "Apply to SDDM?"; then
        sudo tee "${SDDM_CONF_DIR}/cursor.conf" > /dev/null <<EOF
[Theme]
CursorTheme=${theme}
CursorSize=${size}
EOF
        log_success "Created ${SDDM_CONF_DIR}/cursor.conf"
    else
        log_info "Skipped SDDM update."
    fi
}

apply_cursor() {
    local theme_name="$1"
    local size="$2"

    if command -v hyprctl &>/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        log_info "Applying to Hyprland..."
        if hyprctl setcursor "${theme_name}" "${size}" >/dev/null; then
            log_success "Cursor active."
        else
            log_warn "hyprctl failed to set cursor (check logs)."
        fi
    else
        log_warn "Hyprland not running/detected. Cursor installed but not active."
    fi
}

apply_to_sober() {
    local theme_name="$1"
    local size="$2"

    if [[ ! -d "$HOME/.var/app/org.vinegarhq.Sober" ]]; then
        log_info "Sober not installed. Skipping Sober update."
        return
    fi

    if [[ ! -d "$SOBER_CURSOR_DIR" ]]; then
        log_info "Sober cursor directory not found. Skipping Sober update."
        return
    fi

    local theme_path
    if [[ -d "${SYSTEM_ICON_DIR}/${theme_name}" ]]; then
        theme_path="${SYSTEM_ICON_DIR}/${theme_name}"
    elif [[ -d "${ICON_DIR}/${theme_name}" ]]; then
        theme_path="${ICON_DIR}/${theme_name}"
    else
        log_error "Theme not found."
        return 1
    fi

    local cursors_path
    if [[ -d "${theme_path}/cursors_scalable" ]]; then
        cursors_path="${theme_path}/cursors_scalable"
    elif [[ -d "${theme_path}/cursors" ]]; then
        cursors_path="${theme_path}/cursors"
    else
        log_error "No cursors directory found in theme."
        return 1
    fi

    if ! command -v xcur2png &>/dev/null; then
        log_error "xcur2png not found. Install xcursor-to-png package."
        return 1
    fi

    log_info "Applying cursors to Sober..."

    local extract_dir
    extract_dir="$HOME/.cache/cursors"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    extract_cursor() {
        local name="$1"
        local xcursor_file
        xcursor_file=$(find "$cursors_path" -maxdepth 1 -name "*${name}*" -type f 2>/dev/null | head -1)
        if [[ -z "$xcursor_file" ]]; then
            local link_target
            link_target=$(readlink "$cursors_path/${name}" 2>/dev/null)
            if [[ -n "$link_target" ]]; then
                xcursor_file=$(find "$cursors_path" -maxdepth 1 -name "${link_target}" -type f 2>/dev/null | head -1)
            fi
        fi
        if [[ -z "$xcursor_file" ]]; then
            log_warn "Cursor ${name} not found."
            return 1
        fi
        local cursor_dir="$extract_dir/$name"
        mkdir -p "$cursor_dir"
        xcur2png -d "$cursor_dir" "$xcursor_file"
        local png_file
        png_file=$(find "$cursor_dir" -name "*.png" -type f | sort -V | tail -1)
        printf '%s' "$png_file"
    }

generate_sober_cursor_from_png() {
        local png_src="$1"
        local final_dst="$2"
        local offset_x="$3"
        local offset_y="$4"
        local label="$5"
        local cursor_size="$6"

        if [[ ! -f "$png_src" ]]; then
            log_warn "Source PNG not found. Skipping ${label}."
            return 0
        fi

        if ! command -v magick &>/dev/null; then
            log_warn "ImageMagick not found, skipping ${label}."
            return 0
        fi

        local temp_dst
        temp_dst=$(mktemp /tmp/sober_cursor_XXXX.png)

log_info "Creating ${label} for Sober..."
        local actual_size=$(( cursor_size ))
        local offset_x offset_y
        offset_x=$(( (64 - actual_size) / 2 ))
        offset_y=$(( (64 - actual_size) / 2 ))
        magick "$png_src" -resize ${actual_size}x${actual_size} \
            -background none -gravity NorthWest -splice "${offset_x}x${offset_y}" \
            -background none -extent 64x64 "$temp_dst"
        install -Dm644 "$temp_dst" "$final_dst"
        rm -f "$temp_dst"
        log_success "Installed ${label} to Sober."
    }

    local arrow_png=$(extract_cursor "hand2")
    local arrowfar_png=$(extract_cursor "left_ptr")
    local text_png=$(extract_cursor "ibeam")
    local crosshair_png=$(extract_cursor "crosshair")

    generate_sober_cursor_from_png "$arrow_png" \
        "$SOBER_CURSOR_DIR/ArrowCursor.png" \
        0 0 "ArrowCursor" "$size"

    generate_sober_cursor_from_png "$arrowfar_png" \
        "$SOBER_CURSOR_DIR/ArrowFarCursor.png" \
        0 0 "ArrowFarCursor" "$size"

    generate_sober_cursor_from_png "$text_png" \
        "$SOBER_CURSOR_DIR/IBeamCursor.png" \
        0 0 "IBeamCursor" "$size"

    generate_sober_cursor_from_png "$crosshair_png" \
        "$SOBER_MOUSE_DIR/MouseLockedCursor.png" \
        0 0 "MouseLockedCursor" "$size"
}

main() {
    local theme size

    if [[ -n "${1:-}" && -n "${2:-}" ]]; then
        theme="$1"
        size="$2"
    else
        local -a themes=($(get_available_cursors))

        if [[ ${#themes[@]} -eq 0 ]]; then
            die "No cursor themes found on system."
        fi

        echo ""
        echo "${BOLD}Select Cursor Theme${RESET}"
        echo "===================="
        echo ""

        PS3="Enter number: "
        select theme in "${themes[@]}" "Quit"; do
            [[ "$theme" == "Quit" ]] && exit 0
            [[ -n "$theme" ]] && break
        done

        [[ -z "$theme" ]] && exit 1

        local -a sizes=($(get_cursor_sizes "$theme"))

        echo ""
        echo "${BOLD}Select Cursor Size${RESET}"
        echo "===================="
        echo ""

        PS3="Enter number: "
        select size in "${sizes[@]}" "Custom" "Quit"; do
            [[ "$size" == "Quit" ]] && exit 0
            if [[ "$size" == "Custom" ]]; then
                echo ""
                echo -n "Enter custom size: "
                read -r size
                [[ -n "$size" ]] && break
            fi
            [[ -n "$size" ]] && break
        done

        [[ -z "$size" ]] && exit 1
    fi

    log_info "Cursor setup: ${theme} @ ${size}px"

    if [[ ! -d "${SYSTEM_ICON_DIR}/${theme}" ]]; then
        if prompt_yes_no "${theme} not in system icons. Install to system?"; then
            install_to_system "$theme"
        fi
    fi

    update_system_index "$theme"
    update_legacy_index "$theme"
    update_caelestia_vars "$theme" "$size"
    update_sddm "$theme" "$size"
    update_xresources "$theme" "$size"
    update_gtk_settings "$theme" "$size" "$HOME/.config/gtk-3.0"
    update_gtk_settings "$theme" "$size" "$HOME/.config/gtk-4.0"

    # Check the base Sober directory instead of the deep cursor path
    if [[ -d "$HOME/.var/app/org.vinegarhq.Sober" ]] && prompt_yes_no "Apply to Sober app?"; then
        # Create the necessary overlay directories before applying
        mkdir -p "$SOBER_CURSOR_DIR" "$SOBER_MOUSE_DIR"
        
        echo ""
        echo -n "Sober cursor size [${size}]: "
        read -r sober_size < /dev/tty
        sober_size=${sober_size:-$size}
        apply_to_sober "$theme" "$sober_size"
    else
        log_info "Skipped Sober update."
    fi

    apply_cursor "$theme" "$size"
}

main "$@"