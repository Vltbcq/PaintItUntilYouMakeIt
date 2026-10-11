class_name AchievementDB
extends RefCounted
## Succès : chacun débloque une amélioration de l'Atelier (couleurs, outils, effets).
## Les améliorations d'encre et de boutique, elles, s'achètent avec les pigments.
## kind : "wave" (vague atteinte et finie), "kills" (ennemis effacés, toutes parties),
## "gallery" (dessins dans la galerie), "level" (niveau dans une partie), "legend" (arme légendaire),
## "clean" (vague finie sans perdre de PV), "win" (partie gagnée, difficulté >= v).
## "wave" et "win" acceptent "map" : le défi ne vaut que sur cette carte (deux défis sur dix sont
## liés au Tableau noir et à L'Écran). Aucun défi n'a la même condition qu'un objet (ItemUnlockDB).

static var LIST := [
	{"id": "rature", "name": "Sans rature", "desc": "Vaincs le boss de la vague 5.", "kind": "wave", "v": 5, "unlock": "tool_triangle"},
	{"id": "kills", "name": "Gomme à tout", "desc": "Tue 500 ennemis (toutes parties).", "kind": "kills", "v": 500, "unlock": "tool_big"},
	{"id": "galerie", "name": "Carnet bien rempli", "desc": "Aie 15 dessins dans ta galerie.", "kind": "gallery", "v": 15, "unlock": "tool_line"},
	{"id": "vague8", "name": "Coup de crayon", "desc": "Termine la vague 8.", "kind": "wave", "v": 8, "unlock": "tool_rect"},
	{"id": "boss10", "name": "Critique élogieuse", "desc": "Vaincs le boss de la vague 10 sur Le Tableau noir.", "kind": "wave", "v": 10, "map": 2, "unlock": "tool_ellipse"},
	{"id": "niveau10", "name": "Main sûre", "desc": "Atteins le niveau 10 dans une partie.", "kind": "level", "v": 10, "unlock": "tool_mirror"},
	{"id": "legende", "name": "Œuvre légendaire", "desc": "Possède une arme légendaire.", "kind": "legend", "v": 1, "unlock": "gradient"},
	{"id": "propre", "name": "Sans une tache", "desc": "Termine une vague sans perdre de PV.", "kind": "clean", "v": 1, "unlock": "fx_pulse"},
	{"id": "victoire", "name": "Vernissage", "desc": "Gagne une partie.", "kind": "win", "v": 0, "unlock": "fx_shimmer"},
	{"id": "maitre", "name": "Maître peintre", "desc": "Gagne une partie sur L'Écran.", "kind": "win", "v": 0, "map": 3, "unlock": "fx_rainbow"},
]


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if d.id == id:
			return d
	return {}


## Le succès est-il rempli dans ce contexte ? ctx : voir Run.achievement_ctx().
static func met(d: Dictionary, ctx: Dictionary) -> bool:
	if d.has("map") and int(ctx.get("map", 0)) != int(d.map):
		return false
	match d.kind:
		"wave":
			return int(ctx.get("cleared", 0)) >= int(d.v)
		"kills":
			return int(ctx.get("total_kills", 0)) >= int(d.v)
		"gallery":
			return int(ctx.get("gallery", 0)) >= int(d.v)
		"level":
			return int(ctx.get("level", 0)) >= int(d.v)
		"legend":
			return bool(ctx.get("legend", false))
		"clean":
			return bool(ctx.get("clean", false))
		"win":
			return bool(ctx.get("win", false)) and int(ctx.get("diff", 0)) >= int(d.v)
	return false
