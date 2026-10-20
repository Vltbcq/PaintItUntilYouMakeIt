#!/usr/bin/env bash
# Exporte le jeu (Windows + Linux / Steam Deck) depuis ce PC et l'envoie sur Steam avec SteamPipe.
#
#   GODOT=<Godot.exe> STEAMCMD=<steamcmd.exe> STEAM_USER=<ton compte Steam> bash steam/upload.sh
#
# SteamCMD demande lui-même le mot de passe et le code Steam Guard (rien n'est écrit dans un fichier).
# Le build arrive dans Steamworks -> SteamPipe -> Builds : c'est là que tu le mets en ligne.
set -e
cd "$(dirname "$0")/.."
: "${GODOT:?Donne le chemin de Godot : GODOT=...}"
: "${STEAMCMD:?Donne le chemin de steamcmd.exe : STEAMCMD=...}"
: "${STEAM_USER:?Donne ton nom de compte Steam : STEAM_USER=...}"

VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
COMMIT=$(git rev-parse --short HEAD)
DIRTY=$(git status --porcelain --untracked-files=no | grep -q . && echo " +modifs" || true)
echo "== Version $VERSION ($COMMIT$DIRTY)"

# 1. Export (les .dll / .so de GodotSteam et de Steam sont posés à côté du jeu par Godot)
rm -rf steam/content
mkdir -p steam/content/windows steam/content/linux
"$GODOT" --headless --path . --export-release "Windows Desktop" steam/content/windows/PaintIt.exe
"$GODOT" --headless --path . --export-release "Linux" steam/content/linux/PaintIt.x86_64
for f in windows/PaintIt.exe windows/steam_api64.dll linux/PaintIt.x86_64 linux/libsteam_api.so; do
	test -s "steam/content/$f" || { echo "Il manque steam/content/$f : export raté."; exit 1; }
done
echo "== Contenu exporté :"
ls -la steam/content/windows steam/content/linux

# 2. Envoi (SteamCMD veut un chemin Windows complet)
BUILD=$(cd steam && pwd -W 2>/dev/null || pwd)/app_build_5398060.vdf
"$STEAMCMD" +login "$STEAM_USER" +run_app_build -desc "v$VERSION ($COMMIT$DIRTY)" "$BUILD" +quit
echo "== Envoyé. Steamworks -> SteamPipe -> Builds : mets ce build en ligne sur la branche voulue."
