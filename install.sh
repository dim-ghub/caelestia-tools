#!/usr/bin/env bash
set -o errexit
set -o pipefail
shopt -s inherit_errexit 2>/dev/null || true

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly CONFIG_DIR="${HOME}/.config/caelestia"

declare -a HOOKS_SORTED=()
declare -a TEMPLATES_SORTED=()
declare -a SELECTED_HOOKS=()
declare -a SELECTED_TEMPLATES=()

declare -A HOOK_TEMPLATE_MAP=(
    [steam]="steam.css"
    [fastfetch]="fastfetch"
    [discord-material]="discord-material.theme.css"
    [beeper]="beeper.css"
)
declare -A HOOK_DESCRIPTIONS=(
    [steam]="Steam theming via AdwSteamGtk"
    [fastfetch]="Generates themed fastfetch images"
    [websites]="Updates Firefox userChrome colors"
    [minecraft]="Recolors Minecraft resource packs"
    [discord-material]="Converts Material Discord theme RGB to HSL"
    [beeper]="Reload Beeper custom CSS"
)

info()    { printf "[INFO] %s\n" "$*"; }
success() { printf "[OK] %s\n" "$*"; }
warn()    { printf "[WARN] %s\n" "$*" >&2; }
error()   { printf "[ERROR] %s\n" "$*" >&2; }

die() { error "$*"; exit 1; }

create_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        info "Created $dir"
    fi
}

show_selection_menu() {
    clear
    echo "=========================================="
    echo "       Caelestia Tools Installer"
    echo "=========================================="
    echo ""
    echo "Select components to install (toggle with number):"
    echo "--------------------------------------------------------"

    local i=1
    for hook in "${HOOKS_SORTED[@]}"; do
        local marker="[ ]"
        if [[ " ${SELECTED_HOOKS[*]} " == *" $hook "* ]]; then
            marker="[x]"
        fi
        local desc="${HOOK_DESCRIPTIONS[$hook]:-}"
        local related_tmpl="${HOOK_TEMPLATE_MAP[$hook]:-}"
        if [[ -n "$related_tmpl" ]]; then
            echo "  $i) $marker ${hook} - ${desc}"
            echo "       └─ (+$related_tmpl)"
        else
            echo "  $i) $marker ${hook} - ${desc}"
        fi
        ((i++))
    done

    echo ""
    echo "  c) Toggle Cursor Switcher"
    echo "  a) Install all selected"
    echo "  q) Quit"
    echo ""
}

toggle_hook() {
    local hook="$1"
    local found=0
    local new_selection=()
    for h in "${SELECTED_HOOKS[@]}"; do
        if [[ "$h" == "$hook" ]]; then
            found=1
        else
            new_selection+=("$h")
        fi
    done
    if [[ $found -eq 0 ]]; then
        new_selection+=("$hook")
        local related_tmpl="${HOOK_TEMPLATE_MAP[$hook]}"
        if [[ -n "$related_tmpl" && " ${SELECTED_TEMPLATES[*]} " != *" $related_tmpl "* ]]; then
            SELECTED_TEMPLATES+=("$related_tmpl")
        fi
    fi
    SELECTED_HOOKS=("${new_selection[@]}")
}

install_posthook() {
    info "Installing PostHook system..."

    create_dir "${INSTALL_DIR}"
    create_dir "${INSTALL_DIR}/posthooks"
    create_dir "${CONFIG_DIR}"

    echo ""
    info "Generating posthook.sh with enabled hooks..."
    {
        echo '#!/usr/bin/env bash'
        echo 'echo $WALLPAPER_PATH'
        echo ""
        for hook in "${HOOKS_SORTED[@]}"; do
            case "$hook" in
                beeper)
                    if [[ " ${SELECTED_HOOKS[*]} " == *" beeper "* ]]; then
                        echo "bash -c 'hyprctl dispatch sendshortcut \"CTRL SHIFT ALT, R, class:^(Beeper)$\"' &"
                    else
                        echo "# bash -c 'hyprctl dispatch sendshortcut \"CTRL SHIFT ALT, R, class:^(Beeper)$\"' &"
                    fi
                    ;;
                *)
                    if [[ -f "${PROJECT_DIR}/posthooks/${hook}.sh" ]]; then
                        if [[ " ${SELECTED_HOOKS[*]} " == *" $hook "* ]]; then
                            echo "~/.local/bin/posthooks/${hook}.sh &"
                        else
                            echo "# ~/.local/bin/posthooks/${hook}.sh &"
                        fi
                    fi
                    ;;
            esac
        done
    } > "${INSTALL_DIR}/posthook.sh"
    chmod +x "${INSTALL_DIR}/posthook.sh"
    success "Generated posthook.sh"

    for hook in "${PROJECT_DIR}/posthooks"/*.sh; do
        if [[ -f "$hook" ]]; then
            cp "$hook" "${INSTALL_DIR}/posthooks/"
            chmod +x "${INSTALL_DIR}/posthooks/$(basename "$hook")"
        fi
    done
    success "Installed posthook scripts"

    if [[ -f "${CONFIG_DIR}/cli.json" ]]; then
        if grep -q '"postHook"' "${CONFIG_DIR}/cli.json" 2>/dev/null; then
            sed -i 's|"postHook": "[^"]*"|"postHook": "~/.local/bin/posthook.sh"|' "${CONFIG_DIR}/cli.json"
        else
            sed -i 's|"wallpaper": {|&\n        "postHook": "~/.local/bin/posthook.sh",|' "${CONFIG_DIR}/cli.json"
        fi
    else
        cat > "${CONFIG_DIR}/cli.json" << 'EOF'
{
    "wallpaper": {
        "postHook": "~/.local/bin/posthook.sh"
    }
}
EOF
    fi
    success "Updated ${CONFIG_DIR}/cli.json"

    echo ""
    if [[ ${#SELECTED_HOOKS[@]} -eq 0 ]]; then
        warn "No hooks enabled - edit ~/.local/bin/posthook.sh to add them"
    else
        success "Enabled hooks: ${SELECTED_HOOKS[*]}"
    fi
}

install_cursor_switcher() {
    info "Installing Cursor Switcher..."
    create_dir "${INSTALL_DIR}"

    if [[ -f "${PROJECT_DIR}/tools/caelestia-cursor-switcher.sh" ]]; then
        cp "${PROJECT_DIR}/tools/caelestia-cursor-switcher.sh" "${INSTALL_DIR}/caelestia-cursor-switcher"
        chmod +x "${INSTALL_DIR}/caelestia-cursor-switcher"
        success "Installed caelestia-cursor-switcher"
    fi
}

install_templates() {
    info "Installing Templates..."

    create_dir "${CONFIG_DIR}/templates"

    for tmpl in "${SELECTED_TEMPLATES[@]}"; do
        local src="${PROJECT_DIR}/templates/$tmpl"
        if [[ -d "$src" ]]; then
            cp -r "$src" "${CONFIG_DIR}/templates/"
        elif [[ -f "$src" ]]; then
            cp "$src" "${CONFIG_DIR}/templates/"
        fi
        success "Installed templates/$tmpl"
    done

    if [[ ${#SELECTED_TEMPLATES[@]} -eq 0 ]]; then
        warn "No templates selected"
    else
        success "Installed templates: ${SELECTED_TEMPLATES[*]}"
    fi
}

setup_arrays() {
    while IFS= read -r hook; do
        HOOKS_SORTED+=("$(basename "$hook" .sh)")
    done < <(find "${PROJECT_DIR}/posthooks" -maxdepth 1 -name "*.sh" -type f | sort)

    HOOKS_SORTED+=("beeper")

    while IFS= read -r tmpl; do
        TEMPLATES_SORTED+=("$(basename "$tmpl")")
    done < <(find "${PROJECT_DIR}/templates" -maxdepth 1 \( -type f -o -type d \) | tail -n +2 | sort)
}

main() {
    local install_cursor="no"

    if [[ ! -d "${PROJECT_DIR}/posthooks" ]]; then
        die "posthooks directory not found. Are you running from the correct location?"
    fi

    setup_arrays

    while true; do
        show_selection_menu

        echo -n "Enter choice: "
        read -r choice

        case "$choice" in
            q|Q) exit 0 ;;
            c|C) 
                if [[ "$install_cursor" == "yes" ]]; then
                    install_cursor="no"
                else
                    install_cursor="yes"
                fi
                ;;
            a|A)
                install_posthook
                echo ""
                if [[ "$install_cursor" == "yes" ]]; then
                    install_cursor_switcher
                fi
                echo ""
                install_templates
                echo ""
                success "Installation complete!"
                break
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    local idx=$((choice - 1))
                    if ((idx >= 0 && idx < ${#HOOKS_SORTED[@]})); then
                        toggle_hook "${HOOKS_SORTED[$idx]}"
                    fi
                fi
                ;;
        esac
    done

    echo ""
    info "Make sure ~/.local/bin is in your PATH."
}

main "$@"