# Envoyer le jeu sur Steam (SteamPipe)

AppID **5398060** · dépôt Windows **5398061** · dépôt Linux / Steam Deck **5398062**
(si les numéros sont différents dans Steamworks → SteamPipe → Dépôts, change-les dans les trois `.vdf`).

## Une seule fois

1. **Steamworks → SteamPipe → Dépôts** : crée les deux dépôts (Windows, Linux) et règle leur OS ;
   ajoute-les au paquet du jeu.
2. **Installation → Général → Options de lancement** : `PaintIt.exe` (Windows), `PaintIt.x86_64` (Linux).
3. **Publier** la configuration (onglet *Publier*). La page boutique reste cachée tant que tu ne la publies pas.
4. Télécharge **SteamCMD** sur le site de Valve (il est aussi dans le SDK Steamworks :
   `sdk/tools/ContentBuilder/builder/steamcmd.exe`) et lance-le une première fois pour qu'il se mette à jour.
5. Modèles d'export Godot 4.7.2 installés pour **Windows et Linux** (Godot → Éditeur → Gérer les modèles d'export).

## À chaque version

```bash
GODOT="C:/chemin/Godot_v4.7.2-stable_win64_console.exe" STEAMCMD="C:/chemin/steamcmd.exe" STEAM_USER=ton_compte bash steam/upload.sh
```

- Le script exporte le jeu dans `steam/content/` (ignoré par Git et par Godot), vérifie que les
  `.dll` / `.so` de Steam sont bien là, puis lance SteamCMD.
- **SteamCMD demande lui-même ton mot de passe et le code Steam Guard** : rien n'est écrit dans un fichier.
- Le build arrive dans **Steamworks → SteamPipe → Builds**, avec la version et le commit en description.
  Choisis-y la branche (par défaut, ou une branche testeurs) et clique sur *Mettre en ligne*.
- Les journaux d'envoi sont dans `steam/output/`.

## À savoir

- Avant la sortie, seuls les comptes qui ont une **clé** (clés « Release State Override ») peuvent
  télécharger le jeu.
- Linux envoyé depuis Windows : Windows ne garde pas le droit d'exécution des fichiers. Si le jeu ne se
  lance pas sur Steam Deck (« permission denied »), il faudra envoyer le dépôt Linux depuis Linux
  (ou depuis la GitHub Action).
