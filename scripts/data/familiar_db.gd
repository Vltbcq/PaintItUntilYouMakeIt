class_name FamiliarDB
extends RefCounted
## Familiers : des compagnons que tu DESSINES, qui se baladent sur la page avec chacun son
## comportement (attaquer, soigner, gêner, encaisser...). Tous uniques, nombre illimité.
## « Woinic » : en hommage au chien de Theorus. « Yuki » et « Teemeo » : clins d'œil à League of Legends.

static var LIST := [
	# Communs
	{"id": "moustique", "name": "Moustique", "rar": 0, "ink": 40,
		"desc": "Pique les ennemis et te rend un peu de PV."},
	{"id": "taupe", "name": "Taupe", "rar": 0, "ink": 50,
		"desc": "Surgit sous les ennemis : dégâts de zone, et sa cible est étourdie."},
	{"id": "pie", "name": "Pie", "rar": 0, "ink": 45,
		"desc": "Va chercher des pièces d'or bonus et te les rapporte."},
	{"id": "pigeon", "name": "Pigeon", "rar": 0, "ink": 40,
		"desc": "Vole au-dessus de toi et lâche une fiente toutes les 3 s sur un ennemi proche (dégâts + ralenti)... et une fois sur 10, sur toi."},
	# Rares
	{"id": "herisson_f", "name": "Hérisson", "rar": 1, "ink": 55,
		"desc": "Roule partout sur la page et blesse les ennemis qu'il percute."},
	{"id": "luciole", "name": "Luciole", "rar": 1, "ink": 40,
		"desc": "Son aura fait subir +15% de dégâts aux ennemis."},
	{"id": "perroquet", "name": "Perroquet", "rar": 1, "ink": 50,
		"desc": "Se balade sur la page et répète les attaques de tes armes."},
	# Épiques
	{"id": "corbeau", "name": "Corbeau", "rar": 2, "ink": 60,
		"desc": "Plonge sur les ennemis les plus forts."},
	{"id": "grenouille", "name": "Grenouille", "rar": 2, "ink": 60,
		"desc": "Coup de langue circulaire qui touche tous les ennemis autour d'elle."},
	{"id": "fantome", "name": "Fantôme", "rar": 2, "ink": 55,
		"desc": "Traverse la page : blesse et aveugle les ennemis sur son passage."},
	{"id": "paon", "name": "Le Paon", "rar": 2, "ink": 65,
		"desc": "Toutes les 10 s, fait la roue : les ennemis proches sont CHARMÉS 3 s et attaquent les autres (pas les boss)."},
	# Légendaires
	{"id": "yuki", "name": "Yuki", "rar": 3, "ink": 70,
		"desc": "Reste sur toi : te soigne, bloque des coups et t'accélère quand tu es en danger."},
	{"id": "pavel", "name": "Woinic", "rar": 3, "ink": 80,
		"desc": "Tank de poche : les ennemis proches l'attaquent lui. Revient après un K.O."},
	{"id": "teemeo", "name": "Teemeo", "rar": 3, "ink": 70,
		"desc": "Plante des champignons empoisonnés et tire des fléchettes qui aveuglent et empoisonnent."},
	{"id": "chimere", "name": "Chimère", "rar": 3, "ink": 85,
		"desc": "Toutes les 5 s, prend le pouvoir d'un AUTRE familier au hasard."},
]

## Pouvoirs que la Chimère peut prendre (tous les familiers sauf elle).
const CHIMERA_FORMS := ["moustique", "taupe", "pie", "pigeon", "herisson_f", "luciole", "perroquet", "corbeau",
	"grenouille", "fantome", "paon", "yuki", "pavel", "teemeo"]

const PRICE := [16, 30, 52, 88]
const RAR_INK := [1.0, 1.3, 1.6, 2.0]


static func get_def(id: String) -> Dictionary:
	for d in LIST:
		if d.id == id:
			return d
	return {}


static func of_rarity(rar: int) -> Array:
	return LIST.filter(func(d): return int(d.rar) == rar)


static func ink(def: Dictionary) -> int:
	return roundi(def.ink * RAR_INK[int(def.rar)]) + 15


## La TAILLE du dessin (part de l'encre max utilisée) : gros = frappe fort mais lent,
## petit = rapide et agit plus souvent mais tape moins fort.
## dmg : ×0,8 → ×1,4 ; spd (déplacement et fréquence des actions) : ×1,2 → ×0,85.
static func size_mult(def: Dictionary, pixels: int) -> Dictionary:
	var fill := clampf(float(pixels) / maxf(1.0, float(ink(def))), 0.0, 1.0)
	return {"fill": fill, "dmg": 0.8 + 0.6 * fill, "spd": 1.2 - 0.35 * fill}


static func canvas(def: Dictionary) -> int:
	return [24, 24, 28, 32][int(def.rar)]
