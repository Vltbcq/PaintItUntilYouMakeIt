class_name UnlockDB
extends RefCounted
## Déblocages permanents. Encre, Boutique et Mécénat : achetés avec les pigments ("cost").
## Couleurs, Outils et Effets : débloqués par un SUCCÈS (voir AchievementDB, "unlock"), sauf ceux
## marqués "buy" (achetés à l'établi). "req" : autre amélioration nécessaire ; "wins" : victoires nécessaires ;
## "best_wave" : vague à avoir finie au moins une fois.

static var LIST := [
	{"id": "pack_primaires", "cat": "Couleurs", "name": "Pack primaire", "cost": [15], "buy": true, "best_wave": 3,
		"desc": "Rouge (Feu), Bleu (Glace), Jaune (Foudre). Chaque couleur donne une résistance et un effet d'arme."},
	{"id": "pack_secondaires", "cat": "Couleurs", "name": "Pack secondaire", "cost": [140], "buy": true, "wins": 1,
		"desc": "Vert (Poison), Violet (Arcane), Blanc (Lumière).", "req": "pack_primaires"},
	{"id": "ink", "cat": "Encre", "name": "Encrier", "cost": [50, 90, 140, 200, 275],
		"desc": "+25 encre pour ton perso, +10 pour tes armes, +5 pour tes amulettes, +3 pour tes balles."},
	{"id": "canvas", "cat": "Encre", "name": "Grande toile", "cost": [100, 225, 375],
		"desc": "+8 pixels de côté sur les toiles du perso et des armes, +4 sur celles des amulettes et des balles."},
	{"id": "tool_big", "cat": "Outils", "name": "Gros pinceaux", "cost": [40],
		"desc": "Pinceaux de 2 et 3 pixels."},
	{"id": "tool_line", "cat": "Outils", "name": "Ligne", "cost": [40], "desc": "Trace des lignes droites."},
	{"id": "tool_rect", "cat": "Outils", "name": "Rectangle", "cost": [50], "desc": "Trace des rectangles."},
	{"id": "tool_ellipse", "cat": "Outils", "name": "Ellipse", "cost": [60], "desc": "Trace des cercles et ellipses."},
	{"id": "tool_mirror", "cat": "Outils", "name": "Symétrie", "cost": [90],
		"desc": "Dessine en miroir. Un perso symétrique esquive mieux !"},
	{"id": "tool_triangle", "cat": "Outils", "name": "Triangle", "cost": [60], "desc": "Trace des triangles."},
	{"id": "tool_mirror_h", "cat": "Outils", "name": "Symétrie haut / bas", "cost": [90], "buy": true,
		"desc": "Dessine en miroir de haut en bas. Avec la Symétrie : les 4 coins à la fois."},
	{"id": "gradient", "cat": "Effets", "name": "Dégradé", "cost": [125],
		"desc": "Le pinceau passe d'une couleur à l'autre. Les mélanges créent d'autres éléments."},
	{"id": "fx_pulse", "cat": "Effets", "name": "Encre pulsante", "cost": [100],
		"desc": "Effet animé : +10% vit. d'attaque (coûte 15% de l'encre)."},
	{"id": "fx_shimmer", "cat": "Effets", "name": "Encre scintillante", "cost": [150],
		"desc": "Effet animé : +critique et +esquive (coûte 15% de l'encre)."},
	{"id": "fx_rainbow", "cat": "Effets", "name": "Encre arc-en-ciel", "cost": [225],
		"desc": "Effet animé : compte un peu comme chaque élément (coûte 15% de l'encre)."},
	{"id": "shop_slot", "cat": "Boutique", "name": "Étal élargi", "cost": [500], "desc": "+1 offre dans la boutique."},
	{"id": "free_reroll", "cat": "Boutique", "name": "Relance offerte", "cost": [300], "desc": "Première relance gratuite à chaque boutique."},
	{"id": "mecenat_or", "cat": "Mécénat", "name": "Mécène de l'or", "cost": [100, 150, 225, 340, 500],
		"desc": "+2% d'or ramassé par niveau (+10% au niveau 5)."},
	{"id": "mecenat_xp", "cat": "Mécénat", "name": "Mécène du savoir", "cost": [100, 150, 225, 340, 500],
		"desc": "+2% d'expérience par niveau (+10% au niveau 5)."},
	{"id": "start_gold", "cat": "Boutique", "name": "Bourse", "cost": [50, 100, 150], "desc": "+10 or au début de la partie."},
]


## Amélioration achetable avec des pigments (sinon : succès).
static func for_pigments(d: Dictionary) -> bool:
	return d.cat in [Loc.t("Encre"), Loc.t("Boutique"), Loc.t("Mécénat")] or d.get("buy", false)


## Le succès qui débloque cette amélioration ({} si elle s'achète).
static func achievement_for(id: String) -> Dictionary:
	for a in AchievementDB.LIST:
		if a.unlock == id:
			return a
	return {}


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if d.id == id:
			return d
	return {}
