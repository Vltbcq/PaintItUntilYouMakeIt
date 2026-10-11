# Le Géomètre — second boss de la vague 10 sur Le Tableau noir

> Statut : **développé le 2026-10-11** (test `geotest`). Réglages retenus : cercle annoncé 1 s puis brûlant 3 s,
> 46 px entre deux cercles, +50 % de dégâts quand il est planté, 6500 PV et 13 de dégâts, pas de défi.
> Nom : « Le Géomètre » (pas « Le Compas » : une arme s'appelle déjà Compas). C'est un compas géant.
> Il sera tiré au sort avec La Photocopieuse à la vague 10 (comme Le Critique / La Muse sur La Feuille).

## L'idée

Un combat de placement : le Géomètre trace de grands cercles sur le tableau, et le joueur doit
trouver la zone encore libre. C'est de la géométrie, donc du dessin.

## Ses attaques

- **Le cercle** : il plante sa pointe quelque part et trace un grand cercle avec son autre branche.
  Le trait reste au sol quelques secondes et fait mal si on le traverse.
- **Les cercles qui se chevauchent** : il en enchaîne plusieurs ; il faut repérer la zone libre.
- **Pointe plantée = vulnérable** : pendant qu'il trace, il est immobile, c'est le moment de frapper.
- **Sous 50 % de PV** : il trace des arcs plus vite, et lance sa pointe comme une lance à travers
  l'arène.

## À préciser avant de coder

- Les chiffres (PV, dégâts : partir de La Photocopieuse, 6500 PV et 13 de dégâts).
- Combien de temps un trait reste au sol, et s'il est annoncé avant de faire mal.
- S'il fait apparaître des ennemis normaux pendant le combat, comme les autres boss.
- Son déblocage dans le Codex et un éventuel défi lié.

## Idées écartées pour ce boss

Le Squelette de la salle de sciences (se reconstitue), Le Surveillant (punitions), Le
Rétroprojecteur (lumière et diapositives).
