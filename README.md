# Caelestia Tools

Tools and scripts for the [Caelestia](https://github.com/AryanTheJavaStrider/Caelestia) Hyprland dotfiles.

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

The `templates/` directory contains scripted templates used by the Caelestia CLI for generating theme files:

- `fastfetch/` - fastfetch config template
- `steam.css` - Steam theme CSS

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
| [caelestia-websites](https://github.com/dim-ghub/caelestia-websites) | Updates Firefox userChrome colors |
| [Minecraft-Caelestia](https://github.com/dim-ghub/Minecraft-Caelestia) | Recolors Minecraft resource packs |