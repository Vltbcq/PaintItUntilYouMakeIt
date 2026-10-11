class_name Pal
extends RefCounted
## Palette 16 bits, éléments liés aux couleurs et couleurs d'interface.

enum { NEUTRE, FEU, GLACE, FOUDRE, POISON, ARCANE, LUMIERE }
const COUNT := 7

static var NAMES := ["Ombre", "Feu", "Glace", "Foudre", "Poison", "Arcane", "Lumière"]
static var COLOR_NAMES := ["Noir", "Rouge", "Bleu", "Jaune", "Vert", "Violet", "Blanc"]
const UNLOCK := ["", "pack_primaires", "pack_primaires", "pack_primaires", "pack_secondaires", "pack_secondaires", "pack_secondaires"]

## Bonus donné au perso par la couleur, et effet donné aux armes.
static var CHAR_BONUS := ["", "+Dégâts", "+Armure", "+Vit. d'attaque", "+Régénération", "+Vol de vie", "+Esquive"]
static var WEAPON_EFFECT := ["", "Brûlure", "Gel", "Chaîne d'éclairs", "Poison cumulable", "Marque arcanique", "Éclat de lumière"]

## 3 nuances par élément : sombre, normale, claire.
## 5 nuances par couleur : [foncé, principale, claire, TRÈS foncée, TRÈS claire]
## (les 2 dernières ajoutées en v0.10 ; l'ordre d'affichage est SHADE_ORDER : du plus foncé au plus clair)
const SHADES := [
	[Color("1a1423"), Color("3d3450"), Color("6e6784"), Color("0b0810"), Color("a39cb8")],
	[Color("8c1f2a"), Color("d8433b"), Color("f08a5d"), Color("561119"), Color("f9bf98")],
	[Color("23407a"), Color("3f7fd9"), Color("8cc4f2"), Color("13254b"), Color("c8e4fb")],
	[Color("b07d1c"), Color("f0c43a"), Color("fbe79a"), Color("70500f"), Color("fff5cf")],
	[Color("2c6b3a"), Color("4faa4c"), Color("a4d86a"), Color("173f22"), Color("d2efa8")],
	[Color("4d2a7a"), Color("8c52c9"), Color("c79bea"), Color("2d184a"), Color("e5cdf6")],
	[Color("c8bfae"), Color("f4efe2"), Color("ffffff"), Color("9f9686"), Color("e2dbcb")],
]
const SHADE_ORDER := [3, 0, 1, 2, 4]

# Interface
const INK := Color("1a1423")
const PAPER := Color("e9dcbc")
const PAPER_DARK := Color("d4c29a")
const BG := Color("3e1820")          # mur bordeaux de la galerie
const PANEL := Color("3a2418")       # boiserie
const PANEL_LIGHT := Color("4a2e1f")
const BORDER := Color("8c6414")      # laiton
const TEXT := Color("f4efe2")
const ACCENT := Color("f0c43a")
const DIM := Color("bfa27a")
const DISABLED := Color("6a5040")
const GOOD := Color("7fd66a")
const BAD := Color("f06a5d")
const RARITY := [Color("c9c3b6"), Color("3a86ff"), Color("c071f0"), Color("f0a030")]   # commun gris, rare BLEU
static var RARITY_NAMES := ["Commun", "Rare", "Épique", "Légendaire"]
static var RARITY_NAMES_F := ["Commune", "Rare", "Épique", "Légendaire"]

## Cercle des faiblesses (cercle chromatique des peintres) : chaque couleur bat la suivante.
## Feu → Foudre → Poison → Glace → Arcane → Feu ; la Lumière et l'Ombre (le noir) se battent l'un l'autre.
## Une attaque qui bat la couleur de sa cible fait ×1,5 ; dans l'autre sens ×0,75.
const CYCLE := [FEU, FOUDRE, POISON, GLACE, ARCANE]
const NOIR := -1   # l'Ombre : un dessin surtout noir
const WEAK_MULT := 1.5
const STRONG_MULT := 0.75

static var _cache := {}


## Couleur principale d'un dessin (part de chaque élément) : celle qui couvre au moins `need`
## du dessin, sinon NOIR s'il est surtout noir, sinon 0 (aucune).
static func color_of(frac: Array, need := 0.25) -> int:
	var best := 0
	var best_v := need
	for e in range(1, mini(frac.size(), COUNT)):
		if float(frac[e]) >= best_v:
			best_v = float(frac[e])
			best = e
	if best == 0 and frac.size() > 0 and float(frac[0]) >= 0.5:
		return NOIR
	return best


## Multiplicateur de dégâts d'une attaque de couleur `att` sur une cible de couleur `def`.
static func weakness(att: int, def: int) -> float:
	if att == 0 or def == 0:
		return 1.0
	if (att == LUMIERE and def == NOIR) or (att == NOIR and def == LUMIERE):
		return WEAK_MULT
	var ia := CYCLE.find(att)
	var id := CYCLE.find(def)
	if ia < 0 or id < 0:
		return 1.0
	if (ia + 1) % CYCLE.size() == id:
		return WEAK_MULT
	if (id + 1) % CYCLE.size() == ia:
		return STRONG_MULT
	return 1.0


## Ligne d'infobulle : la couleur principale d'un dessin (cercle des faiblesses).
static func color_line(frac: Array, need := 0.25) -> String:
	var c := color_of(frac, need)
	return Loc.t("Couleur principale : ") + (color_name(c) if c != 0 else Loc.t("aucune"))


## Nom d'une couleur du cercle (« Ombre » pour NOIR).
static func color_name(c: int) -> String:
	return Loc.t("Ombre") if c == NOIR else (NAMES[c] if c > 0 else Loc.t("aucune"))



static func main_color(el: int) -> Color:
	return SHADES[el][1]


## Élément d'une couleur : la nuance de palette la plus proche.
## Un mélange rouge→bleu donne donc du violet (Arcane) au milieu.
static func element_of(c: Color) -> int:
	var key := c.to_rgba32()
	if _cache.has(key):
		return _cache[key]
	var best := 0
	var best_d := 1e9
	for e in COUNT:
		for s: Color in SHADES[e]:
			var d := (c.r - s.r) * (c.r - s.r) + (c.g - s.g) * (c.g - s.g) + (c.b - s.b) * (c.b - s.b)
			if d < best_d:
				best_d = d
				best = e
	_cache[key] = best
	return best
