# Caelestia Tools

Tools and scripts for the [Caelestia](https://github.com/AryanTheJavaStrider/Caelestia) Hyprland dotfiles.

## Installer

Run the interactive installer to set up all components:

```bash
./install.sh
```

The installer allows you to select which components to install:
- PostHook scripts (with associated templates auto-selected)
- Cursor Switcher tool

## Tools

### Cursor Switcher

Interactive cursor theme installer that:

- Scans for installed cursor themes
- Installs themes to system icons (requires sudo)
- Updates Caelestia vars, SDDM, Xresources, and GTK settings
- Applies cursors to Hyprland live and Sober app
- Supports custom cursor sizes

```bash
./caelestia-cursor-switcher.sh [theme_name] [size]
```

## Templates

The `templates/` directory contains scripted templates used by the Caelestia CLI for generating theme files.

### Setup

Copy the templates to `~/.config/caelestia/templates/`:

```bash
mkdir -p ~/.config/caelestia/templates
cp -r templates/* ~/.config/caelestia/templates/
```

### Available Templates

- `fastfetch/` - fastfetch config template
- `steam.css` - Steam theme CSS
- `discord-material.theme.css` - Material Discord theme template
- `beeper.css` - Beeper.app custom CSS theme

## PostHook System

The postHook system runs custom scripts after wallpaper changes to update theming across the system. Scripts are installed to `~/.local/bin/posthook.sh` and `~/.local/bin/posthooks/`.

### Setup

Configure the postHook path in `~/.config/caelestia/cli.json`:

```json
{
    "wallpaper": {
        "postHook": "~/.local/bin/posthook.sh"
    }
}
```

### Available PostHooks

| Hook | Purpose |
|------|---------|
| `steam.sh` | Applies theme to Steam via AdwSteamGtk |
| `fastfetch.sh` | Generates themed fastfetch images |
| `discord-material.sh` | Converts Material Discord theme RGB to HSL (see note below) |
| [caelestia-websites](https://github.com/dim-ghub/caelestia-websites) | Updates Firefox userChrome colors |
| [Minecraft-Caelestia](https://github.com/dim-ghub/Minecraft-Caelestia) | Recolors Minecraft resource packs |

> **Discord Note:** If you use a client other than Equicord, edit `~/.local/bin/posthook.sh` and change the `ln` command path to match your client's themes directory:
> - BetterDiscord: `~/.config/BetterDiscord/themes/`
> - Vencord: `~/.config/Vencord/themes/`
> - Stella: `~/.config/Stella/themes/`

> **Beeper Note:** The posthook sends `Ctrl+Shift+Alt+R` to the Beeper window to automatically reload the custom CSS installed at `~/.config/Beeper/custom.css`.
