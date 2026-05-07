mkdir -p "$HOME/.config/AdwSteamGtk"
gsettings set io.github.Foldex.AdwSteamGtk prefs-install-custom-css true || :
gsettings set io.github.Foldex.AdwSteamGtk window-controls-layout-options 'None' || :
ln -nfs "$HOME/.local/state/caelestia/theme/steam.css" "$HOME/.config/AdwSteamGtk/custom.css";
sed -i 's/rgb(//g; s/)//g; s/,/, /g; s/; *}/ }/g' "$HOME/.local/state/caelestia/theme/steam.css"
adwaita-steam-gtk -i || :