echo $WALLPAPER_PATH

# Adwsteamgtk
~/.local/bin/posthooks/steam.sh &

# Fastfetch
~/.local/bin/posthooks/fastfetch.sh &

# Websites
~/.local/bin/posthooks/websites.sh &

# Minecraft
~/.local/bin/posthooks/minecraft.sh &

# SDDM
# sudo /usr/share/sddm/themes/caelestia/scripts/sync.sh &

# Material Discord
~/.local/bin/posthooks/discord-material.sh &
# NOTE: If you use a different Discord client, change the symlink path below to match:
#   - BetterDiscord: ~/.config/BetterDiscord/themes/
#   - Vencord: ~/.config/Vencord/themes/
#   - Stella: ~/.config/Stella/themes/
#   - etc.
ln -nsf ~/.local/state/caelestia/theme/discord-material.css ~/.config/Equicord/themes/discord-material.css
