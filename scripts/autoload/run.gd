extends Node
## État de la partie en cours : dessins, armes, amulettes, PV, or, niveau...
##
## Chaque type d'arme et chaque amulette se dessine UNE fois par partie (weapon_art /
## amulet_art) ; les exemplaires achetés ensuite réutilisent ce dessin.

const WAVES := 15          # une partie = 15 vagues, un boss toutes les 5 vagues
const XP_MULT := 0.7        # expérience gagnée (-30%)
const GOLD_MULT := 0.625    # or gagné : 62,5% de la valeur de chaque goutte (0.5 × 1.25)
## Or dégressif : les vagues tardives ont bien plus d'ennemis (et durent plus longtemps), l'or ramassé
## grimpait presque au carré. Chaque pièce vaut ÷ (1 + 0,15 × (vague − 1)) : ×0,49 en v8 ; mais pleine
## valeur jusqu'à la vague 3, puis transition douce jusqu'à la vague 8 (début de partie plus généreux).
## (Seules les pièces ramassées : pas l'XP, ni le pourboire, les commandes, le Mécène, les ventes...)
const GOLD_DECAY := 0.15
const PAD := 22         # marge autour du perso pour poser amulettes et marques (zone "aura" large)
const MAX_WEAPONS := 6

## Bonus proposés en montant de niveau : [stat, valeur de base, texte]
static var UPGRADES := [
	["max_hp", 3.0, "+{v} PV max"], ["regen", 1.5, "+{v} régénération"], ["armor", 1.0, "+{v} armure"],
	["dodge", 3.0, "+{v}% esquive"], ["speed", 5.0, "+{v}% vitesse"], ["dmg", 5.0, "+{v}% dégâts"],
	["atk_speed", 5.0, "+{v}% vit. d'attaque"], ["crit", 3.0, "+{v}% critique"], ["range", 8.0, "+{v}% portée"],
	["lifesteal", 2.0, "+{v}% vol de vie"], ["luck", 5.0, "+{v} chance"], ["harvest", 3.0, "+{v} pourboire"],
	["el_power", 10.0, "+{v}% puissance élém."], ["thorns", 2.0, "+{v} épines"],
]
const UPGRADE_MULT := [1.0, 1.5, 2.2, 3.0]
const PACT_CHANCE := 0.3     # un choix sur 3 peut être un « pacte » : bonus doublé, mais un malus

## Synergies : 3 armes (ou plus) d'un même élément dominant.
const SYNERGY_NEED := 3   # (2 avec Accord parfait : voir synergy_need)
static var SYNERGY_DESC := ["", "Brûlure contagieuse", "Éclats de glace à la mort des ennemis gelés",
	"Chaînes d'éclairs plus longues (4 cibles)", "Nuage toxique à la mort des empoisonnés",
	"Marque arcanique doublée (+50% dégâts subis)", "Toutes tes explosions sont 33% plus grandes"]

static var HEALS := {
	"potion": {"name": "Fiole d'encre", "heal": 0.3, "price": 7, "desc": "Soigne 30% de tes PV max."},
	"grande_potion": {"name": "Grand flacon", "heal": 0.7, "price": 15, "desc": "Soigne 70% de tes PV max."},
	"encre": {"name": "Pot d'encre", "heal": 0.0, "ink": 40, "price": 12,
		"desc": "+40 d'encre pour retoucher ton perso (tu replaces ensuite tes armes et amulettes)."},
	"seve": {"name": "Élixir de sève", "heal": 0.0, "regen": 10.0, "price": 10,
		"desc": "Vague suivante : régénération ×4 (au moins +8) pendant les 10 premières secondes."},
}
## Roulette de la boutique : 37 cases (0 = vert, puis rouge / noir en alternance)
const ROULETTE_PAY := {"rouge": 2, "noir": 2, "vert": 36}   # comme au casino : 35 contre 1 + la mise
## Boutique : une case « potion » (1 fois sur 2) et, à part, une case « événement »
## (35 % des boutiques, un des événements au hasard : ~7 % chacun).
const POTION_CHANCE := 0.5
## Case opening : la boutique ne vend plus que des caisses (Bois / Argent / Or, Armes ou Amulettes).
## CASE_ODDS[caisse] = % de [commune, rare, épique, légendaire] ; prix = valeur moyenne du contenu −20 %.
static var CASE_NAMES := ["Caisse en bois", "Caisse d'argent", "Caisse dorée", "Caisse de diamant"]
const CASE_ODDS := [[80.0, 18.0, 2.0, 0.0], [15.0, 70.0, 13.0, 2.0], [0.0, 20.0, 70.0, 10.0], [0.0, 0.0, 55.0, 45.0]]
const CASE_DISCOUNT := 0.8
const EVENTS := ["roulette", "scratch", "auction", "restorer", "patron"]
const EVENT_CHANCE := 0.35
const SCRATCH_PRICE := 8
const RESTORE_PRICE := [10.5, 21.0, 35.0]   # Restaurateur : selon la rareté de l'amulette donnée (15 / 30 / 50 - 30 %)
## Mécène : [id, multiplicateur d'or, texte du contrat] ; or = (20 + 8 × vague) × multiplicateur
static var PATRON_DEALS := [["more", 1.0, "+15% d'ennemis à la vague suivante"], ["elites", 1.25, "8 élites en plus à la vague suivante"]]
const PATRON_MORE := 1.15   # contrat I : ennemis en plus
const PATRON_ELITES := 8    # contrat II : élites en plus

var active := false
var map := 1                 # carte de la partie (MapDB)
var difficulty := 0
var wave := 0
var hp := 0.0               # les PV sont conservés d'une vague à l'autre
var character: Image
var char_effect := ""
var char_outline := false
var char_a := {}
var weapon_art := {}        # "type#rareté" -> {image, effect, a, bullet, beffect, ba} : un dessin par rareté
var boss_plan := {}         # vague -> boss de cette partie
var weapons: Array = []     # {type, rar, price, anchor, rot, flip, st}
var amulet_art := {}        # id -> {image, effect, a}
var amulets: Array = []     # {id, image, pos, zone, mag, a, outline}
var familiar_art := {}      # id -> {image, effect, outline}
var familiars: Array = []   # ids des familiers possédés (uniques)
var dev_jump := 0           # outil de dev : prochaine vague forcée (0 = non)
var enemy_art := {}         # type -> {image, effect, a, mods}
var elite_art := {}         # type -> version élite redessinée (difficultés hautes)
var enemy_colors := {}      # Aquarelle et plus : type d'ennemi -> élément imposé à son dessin
var oculist_ok := -1        # Lunettes de l'oculiste : -1 pas encore testé, 0 raté, 1 réussi
var run_damage := 0.0       # statistiques de la partie : dégâts infligés, or ramassé, ennemi fatal
var run_gold := 0
var killer := ""
var seed_v := 0             # seed de la partie (boss, boutiques, niveaux, événements)
var seeded := false         # partie lancée AVEC une seed : elle ne débloque rien
var endless := false        # mode infini : la partie continue après la victoire (vague 15)
var endless_base := {}      # ce qui a déjà été compté à la victoire {kills, elites, pigments, bosses}
var eproj_art := {}         # type -> {image, a, mods}
var gold := 0
const START_GOLD := 20      # or au début de chaque partie (+10 par niveau de l'amélioration d'Atelier)
var xp := 0
var xp_rest := 0.0          # fractions d'XP pas encore comptées
var level := 0
var kills := 0
var party_kills := 0       # Chapeau de fête : ennemis tués depuis la fin de la dernière fête
var bosses := 0
var gorilla := 0            # Biscuit pour gorille : vagues finies depuis l'achat
var spent := 0              # or dépensé dans la partie (Investisseur)
var constel: Array = []     # Constellation : [stat qui gagne 40 %, stat qui perd 20 %] pour la vague
const CONSTEL_STATS := [["dmg", "Dégâts"], ["atk_speed", "Vit. d'attaque"], ["speed", "Vitesse"], ["range", "Portée"], ["max_hp", "PV max"]]
var bonus := {}             # bonus de stats choisis en montant de niveau
var marks: Array = []       # marques d'encre dessinées sur le perso {image, pos, a, outline}
var pending_levels := 0     # niveaux gagnés pendant la vague, à choisir après
var stats := {}
var shop_offers: Array = []
var rerolls := 0
var joconde := 0            # vagues finies avec La Joconde (+15% dégâts chacune)
var revived := false        # Renaissance déjà utilisée
var levelup_choices: Array = []   # les 3 bonus proposés au niveau en attente (sauvegardés)
var char_ink_bonus := 0     # Pots d'encre achetés : encre en plus pour retoucher le perso
var order: Dictionary = {}  # Carnet de commandes : {kind, n, progress, reward, done, text}
var legend_buys := 0        # légendaires achetées dans cette partie (succès Vernissage)
var boss_clean := false     # un boss vaincu sans perdre de PV (succès Bâche)
var boss_crit := false      # un boss achevé d'un critique (succès Monocle)
var wave_kills_best := 0    # record d'ennemis tués en une vague (succès Performance live)
var play_time := 0.0        # temps de jeu de la partie, en secondes (succès Speed painting)
var regen_boost := 0.0      # Élixir de sève : secondes de régénération boostée au début de la vague suivante
var star_buff := 0.0        # Grattage (étoile) : +X % dégâts à la vague suivante (en attente)
var wave_dmg := 0.0         # ... actif pendant la vague en cours
var patron := ""            # Mécène : contrat signé pour la vague suivante ("more" / "elites")
var event_used := false     # un événement a déjà été joué dans cette boutique
var journal: Array = []     # ce que le joueur a fait dans la partie : {w (vague), k (type), t (texte)}
var wave_stats := {}        # stats au début de la dernière vague : {wave, text}
var elite_kills := 0        # élites effacées dans la partie
var boss_ids := {}          # boss vaincus dans la partie (id -> true)


func start(d: int, map_id := 1, with_seed := -1) -> void:
	active = true
	map = map_id
	difficulty = d
	seeded = with_seed >= 0
	seed_v = with_seed if seeded else randi() % SEED_MAX
	wave = 0
	hp = 0.0
	character = null
	char_effect = ""
	char_a = {}
	weapon_art = {}
	rseed("boss")
	boss_plan = MapDB.boss_plan(map)
	unseed()
	weapons = []
	amulet_art = {}
	amulets = []
	familiar_art = {}
	familiars = []
	dev_jump = 0
	enemy_art = {}
	elite_art = {}
	enemy_colors = {}
	eproj_art = {}
	gold = START_GOLD + 10 * Meta.level("start_gold")
	xp = 0
	xp_rest = 0.0
	level = 0
	kills = 0
	party_kills = 0
	bosses = 0
	gorilla = 0
	spent = 0
	constel = []
	bonus = {}
	marks = []
	pending_levels = 0
	stats = {}
	shop_offers = []
	joconde = 0
	revived = false
	levelup_choices = []
	elite_kills = 0
	boss_ids = {}
	regen_boost = 0.0
	char_ink_bonus = 0
	journal = []
	wave_stats = {}
	star_buff = 0.0
	wave_dmg = 0.0
	patron = ""
	order = {}
	legend_buys = 0
	boss_clean = false
	boss_crit = false
	wave_kills_best = 0
	play_time = 0.0
	endless = false
	endless_base = {}
	run_damage = 0.0
	run_gold = 0
	oculist_ok = -1
	killer = ""


func diff() -> Dictionary:
	return Meta.DIFFICULTIES[difficulty]


func set_character(img: Image, effect: String, outline := false) -> void:
	character = img
	char_effect = effect
	char_outline = outline
	char_a = Analyzer.analyze(img)
	recompute()
	if hp <= 0.0:
		hp = stats.max_hp


## Recalcule les stats. Si les PV max montent, les PV actuels montent d'autant.
func recompute() -> void:
	var old_max: float = stats.get("max_hp", 0.0)
	stats = Stats.player(self)
	if old_max > 0.0 and stats.max_hp > old_max:
		hp += stats.max_hp - old_max
	hp = minf(hp, stats.max_hp)


func heal(amount: float) -> void:
	hp = minf(stats.max_hp, hp + amount)


## Ce qu'on peut dépenser : l'or en poche, plus 100 de découvert avec la Carte de crédit.
func cash() -> int:
	return gold + (100 if amulet_count("carte_credit") > 0 else 0)


## Faut-il montrer les amulettes sur le perso ? (Satellite : non, elles tournent autour de lui.)
func show_amulets() -> bool:
	return bool(Meta.setting("show_amulets")) and amulet_count("satellite") == 0


## Constellation : tire les deux stats de la vague (une qui gagne, une qui perd).
func roll_constellation() -> void:
	var pool := CONSTEL_STATS.map(func(r): return r[0])
	pool.shuffle()
	constel = [pool[0], pool[1]]


func constellation_text() -> String:
	var names := {}
	for r in CONSTEL_STATS:
		names[r[0]] = Loc.t(r[1])
	return Loc.t("+40%% %s · -20%% %s") % [names[constel[0]], names[constel[1]]]


## Nombre d'objets légendaires possédés (armes et amulettes) : Musée.
func legend_count() -> int:
	var n := 0
	for w in weapons:
		n += 1 if int(w.rar) == 3 else 0
	for am in amulets:
		n += 1 if int(AmuletDB.get_def(am.id).rar) == 3 else 0
	return n


## Emplacements d'armes (Musée ambulant : +1).
func max_weapons() -> int:
	return MAX_WEAPONS + amulet_count("musee")


func amulet_count(id: String) -> int:
	var n := 0
	for am in amulets:
		if am.id == id:
			n += 1
	return n


# ------------------------------------------------------------------ Armes

## Vague « effective » pour la difficulté : la vague 15 est aussi dure que l'ancienne vague 20.
# ------------------------------------------------------------------ Fin de partie plus dure
## Passé la vague 8, le joueur grandit plus vite que les ennemis : à partir de la vague 9, chaque
## vague ajoute (cumulé, jusqu'à la 15e) PV ennemis ×1,12, dégâts ennemis ×1,06 (boss compris),
## prix ×1,05 et or ramassé ×0,96. Les bonus de niveau baissent de 3 % par niveau après le 10e.
const LATE_FROM := 8
const LATE_HP := 1.12
const LATE_DMG := 1.06
const LEVEL_BONUS := 0.85   # bonus de niveau (le même à tous les niveaux : plus de baisse après le niveau 10)
var late_on := true   # (les tests de réglage comparent avec / sans)


func gold_decay() -> float:
	var w := mini(wave, WAVES)
	var d := 1.0 / (1.0 + GOLD_DECAY * maxi(0, w - 1))
	# Début de partie un peu plus généreux : pleine valeur jusqu'à la vague 3, puis on rejoint
	# la courbe en douceur (vague 8 et après : inchangé)
	if w <= 3:
		return 1.0
	if w < 8:
		return lerpf(1.0, d, (w - 3) / 5.0)
	return d


func late_waves() -> int:
	return clampi(wave - LATE_FROM, 0, WAVES - LATE_FROM) if late_on else 0


func late_hp() -> float:
	return pow(LATE_HP, late_waves())


func late_dmg() -> float:
	return pow(LATE_DMG, late_waves())


## Bonus de niveau dégressifs : ×0,97 par niveau au-delà du 10e (jamais sous ×0,5).
func eff_wave() -> float:
	return 1.0 + (wave - 1) * 19.0 / (WAVES - 1)


static func art_key(type: String, rar: int) -> String:
	return "%s#%d" % [type, rar]


## Clé du Codex pour le dessin d'une arme à une rareté. La rareté de base (commune, ou la
## rareté minimum des armes spéciales) garde la clé historique "arme_<type>".
static func weapon_key(type: String, rar: int) -> String:
	if rar <= int(WeaponDB.get_def(type).get("min_rar", 0)):
		return "arme_" + type
	return "arme_%s_r%d" % [type, rar]


func has_art(type: String, rar: int) -> bool:
	return weapon_art.has(art_key(type, rar))


func has_any_art(type: String) -> bool:
	return not closest_art(type, 0).is_empty()


## Dessin le plus proche pour ce type : même rareté, sinon en dessous, sinon au-dessus.
func closest_art(type: String, rar: int) -> Dictionary:
	for r in [rar, rar - 1, rar - 2, rar - 3, rar + 1, rar + 2, rar + 3]:
		if r >= 0 and r <= 3 and weapon_art.has(art_key(type, r)):
			return weapon_art[art_key(type, r)]
	return {}


func art_of(w: Dictionary) -> Dictionary:
	return weapon_art[art_key(w.type, w.rar)]


## Chaque rareté a son propre dessin : les exemplaires moins rares gardent le leur.
func set_weapon_art(type: String, rar: int, img: Image, effect: String, bullet: Image, beffect: String,
		outline := false, boutline := false) -> void:
	var art := {"image": img, "effect": effect, "a": Analyzer.analyze(img), "bullet": bullet, "beffect": beffect,
		"outline": outline, "boutline": boutline}
	if bullet:
		art.ba = Analyzer.analyze(bullet)
	weapon_art[art_key(type, rar)] = art
	for w in weapons:
		if w.type == type and w.rar == rar:
			rebuild_weapon(w)


## Première arme (même type, même rareté < légendaire) qu'un achat pourrait fusionner.
func fusion_match(type: String, rar: int) -> int:
	if rar >= 3:
		return -1
	for i in weapons.size():
		if weapons[i].type == type and weapons[i].rar == rar:
			return i
	return -1


func add_weapon(type: String, rar: int, price: int, anchor: Vector2, rot := 0, flip := false) -> void:
	var w := {"type": type, "rar": rar, "price": price, "anchor": anchor, "rot": rot, "flip": flip}
	rebuild_weapon(w)
	weapons.append(w)


## Applique les déplacements faits dans l'écran de rangement (un par arme existante).
## Rangement : nouvelles positions (et orientations) des amulettes.
func apply_amulet_moves(moves: Array) -> void:
	for i in mini(moves.size(), amulets.size()):
		var m: Dictionary = moves[i]
		amulets[i].pos = m.pos
		amulets[i].image = m.image
	recompute()


func apply_weapon_moves(moves: Array) -> void:
	for i in mini(moves.size(), weapons.size()):
		var m: Dictionary = moves[i]
		weapons[i].anchor = m.anchor
		weapons[i].rot = m.rot
		weapons[i].flip = m.flip


func rebuild_weapon(w: Dictionary) -> void:
	var art: Dictionary = art_of(w)
	w.st = Stats.weapon({"type": w.type, "rar": w.rar, "a": art.a, "effect": art.effect,
		"bullet": art.bullet, "ba": art.get("ba", {}), "beffect": art.beffect})


## Image de cet exemplaire d'arme (tourné / retourné au moment de la pose).
func weapon_image(w: Dictionary) -> Image:
	return Gfx.transformed(Analyzer.trim(art_of(w).image), w.get("rot", 0), w.get("flip", false))


func weapon_count(type: String) -> int:
	var n := 0
	for w in weapons:
		if w.type == type:
			n += 1
	return n


# ------------------------------------------------------------------ Amulettes

func set_familiar_art(id: String, img: Image, effect: String, outline := false) -> void:
	familiar_art[id] = {"image": Analyzer.trim(img), "effect": effect, "outline": outline}


func add_familiar(id: String) -> void:
	if not id in familiars:
		familiars.append(id)


func set_amulet_art(id: String, img: Image, effect: String, outline := false) -> void:
	amulet_art[id] = {"image": Analyzer.trim(img), "effect": effect, "a": Analyzer.analyze(img), "outline": outline}


## img = dessin de l'amulette déjà tourné / retourné par le joueur.
func add_amulet(id: String, img: Image, pos: Vector2i) -> void:
	var def := AmuletDB.get_def(id)
	var a: Dictionary = amulet_art[id].a
	var am := {"id": id, "image": img, "pos": pos, "a": a, "mag": Stats.amulet_mag(a, def),
		"outline": amulet_art[id].get("outline", false)}
	am.zone = zone_at(pos, img.get_size())
	amulets.append(am)
	recompute()


## Zone du perso où tombe le centre de l'amulette.
func zone_at(pos: Vector2i, size: Vector2i) -> String:
	var r: Rect2i = char_a.rect
	r.position += Vector2i(PAD, PAD)
	var c := Vector2(pos) + Vector2(size) / 2.0
	var rf := Rect2(r).grow(1)
	if not rf.has_point(c):
		return Loc.t("Aura")
	var ty := (c.y - r.position.y) / float(r.size.y)
	var tx := (c.x - r.position.x) / float(r.size.x)
	if ty < 0.33:
		return Loc.t("Tête")
	if ty > 0.7:
		return Loc.t("Pieds")
	if tx < 0.22 or tx > 0.78:
		return Loc.t("Mains")
	return Loc.t("Cœur")


## Centre du dessin du perso dans l'image composite (origine du joueur en jeu).
func char_center() -> Vector2:
	var r: Rect2i = char_a.rect
	return Vector2(r.position) + Vector2(r.size) / 2.0 + Vector2(PAD, PAD)


## Image du perso avec ses amulettes, avec une marge PAD tout autour.
func build_player_image(with_amulets := true) -> Image:
	var s := character.get_size()
	var img := Image.create_empty(s.x + PAD * 2, s.y + PAD * 2, false, Image.FORMAT_RGBA8)
	img.blit_rect(character, Rect2i(Vector2i.ZERO, s), Vector2i(PAD, PAD))
	for m in marks:
		var mi: Image = m.image
		var mp: Vector2i = m.pos
		if m.get("outline", false):
			mi = Gfx.baked_outline(mi)
			mp -= Vector2i.ONE
		img.blend_rect(mi, Rect2i(Vector2i.ZERO, mi.get_size()), mp)
	for am in (amulets if with_amulets else []):
		var ai: Image = am.image
		var pos: Vector2i = am.pos
		if am.id == "tache":
			_ink_blob(img, pos + ai.get_size() / 2)
		if am.get("outline", false):
			ai = Gfx.baked_outline(ai)
			pos -= Vector2i.ONE
		img.blend_rect(ai, Rect2i(Vector2i.ZERO, ai.get_size()), pos)
	return img


## Tache indélébile : une grosse tache d'encre irrégulière sur le perso.
func _ink_blob(img: Image, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = c.x * 131 + c.y
	var blobs := [[Vector2(c), 6.5]]
	for i in 5:
		blobs.append([Vector2(c) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 8.0), rng.randf_range(1.5, 3.5)])
	for bl in blobs:
		var p: Vector2 = bl[0]
		var r: float = bl[1]
		for y in range(int(p.y - r), int(p.y + r) + 1):
			for x in range(int(p.x - r), int(p.x + r) + 1):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(p) <= r:
					img.set_pixel(x, y, Pal.INK)


# ------------------------------------------------------------------ Ennemis

func set_enemy_art(id: String, img: Image, effect: String, outline := false) -> void:
	var def := EnemyDB.get_def(id)
	var a := Analyzer.analyze(img)
	enemy_art[id] = {"image": img, "effect": effect, "a": a, "mods": Stats.enemy_art(a, def.ink, effect), "outline": outline}


## Version élite : le dessin de base + des ajouts du joueur (plus d'encre).
func set_elite_art(id: String, img: Image, effect: String, outline := false) -> void:
	var def := EnemyDB.get_def(id)
	var a := Analyzer.analyze(img)
	elite_art[id] = {"image": img, "effect": effect, "a": a, "mods": Stats.enemy_art(a, roundi(def.ink * 1.4), effect), "outline": outline}


## Élément dominant d'une arme (arme + balles), ou 0 si aucun ne domine.
func weapon_element(w: Dictionary) -> int:
	var frac: Array = w.st.frac
	var best := 0
	var best_v := 0.3
	for e in range(1, Pal.COUNT):
		if frac[e] >= best_v:
			best_v = frac[e]
			best = e
	return best


func synergy_counts() -> Dictionary:
	var c := {}
	for w in weapons:
		var e := weapon_element(w)
		if e > 0:
			c[e] = int(c.get(e, 0)) + 1
	return c


## Armes d'un même élément pour activer sa synergie (Accord parfait : 2).
func synergy_need() -> int:
	return 2 if amulet_count("accord_parfait") > 0 else SYNERGY_NEED


func active_synergies() -> Dictionary:
	var out := {}
	var c := synergy_counts()
	for e in c:
		if c[e] >= synergy_need():
			out[e] = c[e]
	return out


## Projectile ennemi automatique : une goutte d'encre de la couleur de l'ennemi.
func auto_eproj(id: String) -> void:
	var def := EnemyDB.get_def(id)
	var el: int = enemy_art[id].mods.element
	var col: Color = Pal.main_color(el) if el > 0 else Pal.SHADES[0][1]
	var n := 9 if def.has("boss") else 7
	var img := Image.create_empty(n, n + 2, false, Image.FORMAT_RGBA8)
	var c := Vector2((n - 1) / 2.0, n / 2.0 + 1.0)
	for y in n + 2:
		for x in n:
			var d := Vector2(x, y) - c
			# Rond + pointe vers le haut = goutte
			var inside := d.length() <= n / 2.0 - 0.3 or (y < c.y and absf(d.x) <= (y - 0.5) * 0.45)
			if inside:
				img.set_pixel(x, y, col)
	img.set_pixel(int(c.x) - 1, int(c.y) - 1, col.lightened(0.6))
	set_eproj_art(id, img, "", true)
	eproj_art[id].mods.speed = 1.0


func set_eproj_art(id: String, img: Image, effect: String, outline := false) -> void:
	var a := Analyzer.analyze(img)
	eproj_art[id] = {"image": img, "effect": effect, "a": a, "mods": Stats.eproj_art(a), "outline": outline}


## Contexte pour les succès (vagues finies, niveau, arme légendaire...).
func achievement_ctx(cleared := -1, clean := false, win := false) -> Dictionary:
	var legends := 0
	var melee := 0
	for w in weapons:
		legends += 1 if w.rar == 3 else 0
		melee += 1 if String(WeaponDB.get_def(w.type).kind) == "melee" else 0
	var legend := legends > 0
	var els := {}
	for w in weapons:
		els[weapon_element(w)] = true
	var mono6 := weapons.size() >= 6 and els.size() == 1 and not els.has(0)
	return {"mono6": mono6 and cleared >= 0, "boss_clean": boss_clean, "boss_crit": boss_crit,
		"wave_kills": wave_kills_best, "legend_buys": legend_buys, "play_time": play_time,
		"cleared": wave - 1 if cleared < 0 else cleared, "kills": kills, "level": level,
		"legend": legend, "legends": legends, "melee": melee, "ranged": weapons.size() - melee, "clean": clean, "win": win, "diff": difficulty, "map": map,
		"stats": stats, "gold": gold, "colors": int(char_a.get("elements", 0)), "pixels": int(char_a.get("pixels", 0)),
		"weapons": weapons.size(), "amulets": amulets.size(), "pets": familiars.size(), "elites": elite_kills, "bosses": boss_ids, "syn": active_synergies()}


# ------------------------------------------------------------------ Sauvegarde de la partie en cours

## Photo de la partie à un point d'étape (stage = "wave" : la vague `wave` va commencer ;
## "after" : la vague `wave` est finie, reste les niveaux et la boutique).
## Les dessins sont stockés en PNG ; tout ce qui se recalcule (stats, analyses) ne l'est pas.
func to_save(stage: String) -> Dictionary:
	var d := {"version": 1, "stage": stage, "map": map, "difficulty": difficulty, "wave": wave, "hp": hp,
		"character": _png(character), "char_effect": char_effect, "char_outline": char_outline,
		"boss_plan": boss_plan.duplicate(), "gold": gold, "xp": xp, "xp_rest": xp_rest, "level": level,
		"kills": kills, "bosses": bosses, "gorilla": gorilla, "spent": spent, "bonus": bonus.duplicate(),
		"pending_levels": pending_levels, "shop_offers": shop_offers.duplicate(true), "rerolls": rerolls,
		"joconde": joconde, "revived": revived, "levelup_choices": levelup_choices.duplicate(true),
		"elite_kills": elite_kills, "boss_ids": boss_ids.duplicate(), "regen_boost": regen_boost,
		"star_buff": star_buff, "patron": patron, "event_used": event_used,
		"journal": journal.duplicate(true), "char_ink_bonus": char_ink_bonus, "wave_stats": wave_stats.duplicate(),
		"order": order.duplicate(), "legend_buys": legend_buys, "boss_clean": boss_clean, "boss_crit": boss_crit,
		"wave_kills_best": wave_kills_best, "play_time": play_time, "enemy_colors": enemy_colors.duplicate(),
		"endless": endless, "endless_base": endless_base.duplicate(), "seed": seed_v, "seeded": seeded,
		"run_damage": run_damage, "run_gold": run_gold, "oculist_ok": oculist_ok}
	var wa := {}
	for k in weapon_art:
		var e: Dictionary = weapon_art[k]
		wa[k] = {"image": _png(e.image), "effect": e.effect, "bullet": _png(e.bullet), "beffect": e.beffect,
			"outline": e.get("outline", false), "boutline": e.get("boutline", false)}
	d.weapon_art = wa
	d.weapons = weapons.map(func(w): return {"type": w.type, "rar": w.rar, "price": w.price, "anchor": w.anchor,
		"rot": w.get("rot", 0), "flip": w.get("flip", false)})
	var aa := {}
	for k in amulet_art:
		aa[k] = {"image": _png(amulet_art[k].image), "effect": amulet_art[k].effect, "outline": amulet_art[k].get("outline", false)}
	d.amulet_art = aa
	d.amulets = amulets.map(func(am): return {"id": am.id, "image": _png(am.image), "pos": am.pos})
	var fa := {}
	for k in familiar_art:
		fa[k] = {"image": _png(familiar_art[k].image), "effect": familiar_art[k].effect, "outline": familiar_art[k].get("outline", false)}
	d.familiar_art = fa
	d.familiars = familiars.duplicate()
	d.marks = marks.map(func(m): return {"image": _png(m.image), "pos": m.pos, "outline": m.get("outline", false)})
	for field in ["enemy_art", "elite_art", "eproj_art"]:
		var src: Dictionary = get(field)
		var out := {}
		for k in src:
			out[k] = {"image": _png(src[k].image), "effect": src[k].effect, "outline": src[k].get("outline", false)}
		d[field] = out
	return d


## Recrée la partie depuis une photo (to_save). Retourne false si elle est illisible.
func from_save(d: Dictionary) -> bool:
	if d.is_empty() or not d.has("character"):
		return false
	start(int(d.difficulty), int(d.get("map", 1)))
	boss_plan = d.boss_plan
	for k in d.get("enemy_colors", {}):
		enemy_colors[k] = int(d.enemy_colors[k])
	set_character(_img(d.character), d.char_effect, d.char_outline)
	for k in d.weapon_art:
		var e: Dictionary = d.weapon_art[k]
		var parts: PackedStringArray = String(k).split("#")
		set_weapon_art(parts[0], int(parts[1]), _img(e.image), e.effect, _img(e.bullet), e.beffect, e.outline, e.boutline)
	for w in d.weapons:
		add_weapon(w.type, int(w.rar), int(w.price), w.anchor, int(w.rot), bool(w.flip))
	for k in d.amulet_art:
		var e: Dictionary = d.amulet_art[k]
		set_amulet_art(k, _img(e.image), e.effect, e.outline)
	for am in d.amulets:
		if not AmuletDB.get_def(am.id).is_empty():   # amulette retirée du jeu (Aimant, Buvard...)
			add_amulet(am.id, _img(am.image), am.pos)
	for m in d.marks:
		add_mark(_img(m.image), m.pos, m.outline)
	var fa: Dictionary = d.get("familiar_art", {})
	for k in fa:
		set_familiar_art(k, _img(fa[k].image), fa[k].effect, fa[k].outline)
	for fid in d.get("familiars", []):
		if not FamiliarDB.get_def(fid).is_empty() and familiar_art.has(fid):
			add_familiar(fid)
	for k in d.enemy_art:
		set_enemy_art(k, _img(d.enemy_art[k].image), d.enemy_art[k].effect, d.enemy_art[k].outline)
	for k in d.elite_art:
		set_elite_art(k, _img(d.elite_art[k].image), d.elite_art[k].effect, d.elite_art[k].outline)
	for k in d.eproj_art:
		set_eproj_art(k, _img(d.eproj_art[k].image), d.eproj_art[k].effect, d.eproj_art[k].outline)
	wave = int(d.wave)
	gold = int(d.gold)
	xp = int(d.xp)
	xp_rest = float(d.xp_rest)
	level = int(d.level)
	kills = int(d.kills)
	bosses = int(d.bosses)
	gorilla = int(d.get("gorilla", 0))
	spent = int(d.get("spent", 0))
	bonus = d.bonus
	pending_levels = int(d.pending_levels)
	shop_offers = (d.shop_offers as Array).filter(func(o): return o.type != "amulet" or not AmuletDB.get_def(o.id).is_empty())
	rerolls = int(d.rerolls)
	joconde = int(d.get("joconde", 0))
	revived = bool(d.get("revived", false))
	levelup_choices = d.get("levelup_choices", [])
	elite_kills = int(d.get("elite_kills", 0))
	regen_boost = float(d.get("regen_boost", 0.0))
	star_buff = float(d.get("star_buff", 0.0))
	patron = String(d.get("patron", ""))
	event_used = bool(d.get("event_used", false))
	journal = d.get("journal", [])
	char_ink_bonus = int(d.get("char_ink_bonus", 0))
	order = d.get("order", {})
	legend_buys = int(d.get("legend_buys", 0))
	boss_clean = bool(d.get("boss_clean", false))
	boss_crit = bool(d.get("boss_crit", false))
	wave_kills_best = int(d.get("wave_kills_best", 0))
	play_time = float(d.get("play_time", 0.0))
	endless = bool(d.get("endless", false))
	seed_v = int(d.get("seed", seed_v))
	run_damage = float(d.get("run_damage", 0.0))
	run_gold = int(d.get("run_gold", 0))
	oculist_ok = int(d.get("oculist_ok", -1))
	seeded = bool(d.get("seeded", false))
	endless_base = d.get("endless_base", {})
	# (les clés de boss_plan relues du JSON sont des textes : on les remet en nombres)
	var bp := {}
	for k in boss_plan:
		bp[int(k)] = boss_plan[k]
	boss_plan = bp
	wave_stats = d.get("wave_stats", {})
	boss_ids = d.get("boss_ids", {})
	recompute()
	hp = clampf(float(d.hp), 1.0, stats.max_hp)
	return true


static func _png(img: Image):
	return img.save_png_to_buffer() if img else null


static func _img(buf) -> Image:
	if buf == null:
		return null
	var img := Image.new()
	img.load_png_from_buffer(buf)
	img.convert(Image.FORMAT_RGBA8)
	return img


# ------------------------------------------------------------------ Progression

func xp_needed() -> int:
	return (level + 3) * (level + 3)


## Retourne le nombre de niveaux gagnés. Chaque niveau : +1 PV max et un peu d'encre.
func add_xp(n: int) -> int:
	xp_rest += n * XP_MULT * (1.0 + 0.25 * amulet_count("carnet") + 0.1 * amulet_count("gommette") + 0.02 * Meta.level("mecenat_xp"))
	var whole := floori(xp_rest)
	xp_rest -= whole
	xp += whole
	var gained := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gained += 1
		pending_levels += 1
	if gained > 0:
		recompute()
	return gained


## 3 bonus différents, de rareté tirée comme en boutique (fixés par la seed).
func roll_upgrades() -> Array:
	rseed("lvl", wave, level + pending_levels)
	var out := _roll_upgrades()
	unseed()
	return out


## Multiplicateur des bonus de niveau : Palimpseste ×2, Stéroïdes ×1,5 chacun.
func bonus_mult() -> float:
	return (2.0 if amulet_count("palimpseste") > 0 else 1.0) * pow(1.5, amulet_count("encrier"))


func _roll_upgrades() -> Array:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	var out := []
	var n := maxi(1, mini(pool.size() - 1, 3 + amulet_count("encrier") - amulet_count("palimpseste")))
	for i in n:
		var u: Array = pool[i]
		var rar := roll_rarity()
		var pact := randf() < PACT_CHANCE
		var v := maxf(0.5, snappedf(u[1] * UPGRADE_MULT[rar] * (2.0 if pact else 1.0) * LEVEL_BONUS, 0.5))
		# (le texte montre ce que tu gagnes vraiment : ×2 avec le Palimpseste, ×1,5 par Stéroïdes)
		var bm := bonus_mult()
		var up := {"stat": u[0], "v": v, "rar": rar, "text": String(u[2]).replace("{v}", _num(snappedf(v * bm, 0.1)))}
		if pact:
			# Pacte : un autre attribut baisse
			var m: Array = pool[(i + 1 + randi() % (pool.size() - 1)) % pool.size()]
			if m[0] == u[0]:
				m = pool[pool.size() - 1 - i]
			var mv := -snappedf(m[1] * 1.5, 0.5)
			up.malus = [m[0], mv]
			up.pact = true
			up.text += "\n" + String(m[2]).replace("+{v}", _num(snappedf(mv * bm, 0.1)))
		out.append(up)
	return out


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else str(v)


## Journal de la partie : une ligne (achat, bonus de niveau, événement...). Réécrit aussi le fichier
## texte de la sauvegarde (écrasé à chaque nouvelle partie).
func log_event(kind: String, text: String) -> void:
	journal.append({"w": wave, "k": kind, "t": text})
	write_journal()


## Stats au début de la vague (appelé au lancement de chaque vague).
func snapshot_wave_stats() -> void:
	wave_stats = {"wave": wave, "text": Stats.describe_player(stats)}
	write_journal()


func item_label(type: String, id: String, rar: int) -> String:
	var n: String = String(WeaponDB.get_def(id).name) if type == "weapon" else (String(FamiliarDB.get_def(id).name) if type == "familiar" else String(AmuletDB.get_def(id).name))
	return "%s %s" % [n, Pal.RARITY_NAMES_F[rar].to_lower()]


func write_journal() -> void:
	var L := [Loc.t("PAINT IT UNTIL YOU MAKE IT — Journal de la dernière partie"), "",
		Loc.t("Carte : %s · Difficulté : %s") % [MapDB.get_def(map).name, Meta.DIFFICULTIES[difficulty].name],
		Loc.t("Vague %d / %d · Niveau %d · Or %d · Ennemis tués %d") % [wave, WAVES, level, gold, kills], ""]
	if not wave_stats.is_empty():
		L.append(Loc.t("== Stats au début de la vague %d ==") % int(wave_stats.wave))
		L.append(String(wave_stats.text))
		L.append("")
	L.append(Loc.t("== Armes =="))
	for w in weapons:
		L.append("- " + item_label("weapon", w.type, int(w.rar)))
	L.append(Loc.t("== Amulettes =="))
	for am in amulets:
		L.append("- %s" % AmuletDB.get_def(am.id).name)
	L.append("")
	L.append(Loc.t("== Journal =="))
	for e in journal:
		L.append("[V%d] %s" % [int(e.w), e.t])
	Meta.write_text(Meta.slot_dir() + "journal_derniere_partie.txt", "\n".join(L))


func apply_upgrade(u: Dictionary) -> void:
	log_event("level", Loc.t("Niveau %d : %s") % [level - pending_levels, String(u.get("text", "")).replace("\n", " · ")])
	bonus[u.stat] = float(bonus.get(u.stat, 0.0)) + u.v
	if u.has("malus"):
		bonus[u.malus[0]] = float(bonus.get(u.malus[0], 0.0)) + u.malus[1]
	recompute()


func add_mark(img: Image, pos: Vector2i, outline := false) -> void:
	marks.append({"image": img, "pos": pos, "a": Analyzer.analyze(img), "outline": outline})
	recompute()


func end_wave() -> void:
	gorilla += amulet_count("biscuit_gorille")
	constel = []
	gold += roundi(stats.harvest)
	recompute()


func pigments_earned(win: bool) -> int:
	var p := 0.0
	var cleared := wave if win else wave - 1
	for w in range(1, cleared + 1):
		p += (2.0 + (1.0 + (w - 1) * 19.0 / (WAVES - 1)) * 0.5) * 20.0 / WAVES
	p += bosses * 10.0
	if win:
		p += 30.0
	return maxi(Meta.MIN_PIGMENTS, roundi(p * diff().reward))


## Mode infini : pigments des vagues finies APRÈS la victoire (même barème), et des boss en plus.
func pigments_endless() -> int:
	var p := 0.0
	for w in range(WAVES + 1, wave):
		p += (2.0 + (1.0 + (w - 1) * 19.0 / (WAVES - 1)) * 0.5) * 20.0 / WAVES
	p += (bosses - int(endless_base.get("bosses", bosses))) * 10.0
	return roundi(p * diff().reward)


# ------------------------------------------------------------------ Boutique

## Tout devient plus cher au fil de la partie (×1 en vague 1, ×4.7 en vague 20).
func price_mult() -> float:
	var w := eff_wave() - 1.0
	# Étiquette de prix : -8 % par exemplaire (5 au plus)
	return (1.0 + 0.12 * w + 0.004 * w * w) * pow(0.92, amulet_count("etiquette_prix"))


## Chances (en %) de [rare, épique, légendaire] pour une offre ou un bonus, selon la vague qui
## arrive. Épique : à partir de la vague 6. Légendaire : seulement sur les 5 dernières vagues
## (11 à 15). La chance avance ces paliers (2 vagues au plus) et augmente un peu les chances.
func rarity_odds() -> Array:
	var luck: float = stats.get("luck", 0.0)
	var w := float(mini(wave + 1, WAVES)) + clampf(luck / 20.0, 0.0, 2.0)
	var leg := 0.0 if w < 11.0 else 3.0 + (w - 11.0) * 2.0 + maxf(0.0, luck) * 0.05
	var epi := 0.0 if w < 6.0 else 6.0 + (w - 6.0) * 2.0 + maxf(0.0, luck) * 0.1
	var rar := maxf(2.0, 10.0 + (w - 1.0) * 2.2 + luck * 0.15)
	return [rar, epi, leg]


## Prix moyen d'un objet (arme ou amulette) dans la boutique de cette vague : raretés selon les
## chances actuelles, 40 % d'armes / 60 % d'amulettes, × le multiplicateur de prix. (Le Capital)
func avg_item_price() -> int:
	var o := rarity_odds()
	var p := [maxf(0.0, 100.0 - o[0] - o[1] - o[2]), o[0], o[1], o[2]]
	var base := 0.0
	for r in 4:
		base += p[r] / 100.0 * (0.4 * WeaponDB.PRICE[r] + 0.6 * AmuletDB.PRICE[r])
	return maxi(1, roundi(base * price_mult()))


## Le Capital : les armes et amulettes à vendre coûtent toutes le prix moyen de la vague
## (et le Capital lui-même coûte toujours ce prix-là).
func apply_capital() -> void:
	if amulet_count("case_opening") > 0:
		return   # Case opening : les caisses ont leur propre prix (le Capital n'a plus d'effet)
	var avg := avg_item_price()
	var owned := amulet_count("capital") > 0
	for o in shop_offers:
		if o.sold or o.get("gift", false) or not o.type in ["weapon", "amulet"]:
			continue
		if owned or (o.type == "amulet" and o.id == "capital"):
			o.price = avg


## Dé pipé : chaque prix est tiré au hasard, de gratuit à ×2 (à partir du prix moyen avec le Capital).
func roll_dice_prices() -> void:
	if amulet_count("de_pipe") == 0:
		return
	for o in shop_offers:
		if not o.sold and not o.get("gift", false) and o.type in ["weapon", "amulet", "familiar"]:
			o.price = roundi(float(o.price) * randf_range(0.0, 2.0))


func make_case(tier: int, kind: String) -> Dictionary:
	var base := 0.0
	for r in 4:
		base += CASE_ODDS[tier][r] / 100.0 * (WeaponDB.PRICE[r] if kind == "weapon" else AmuletDB.PRICE[r])
	return {"type": "case", "id": "case", "tier": tier, "kind": kind, "rar": tier,
		"price": maxi(1, roundi(base * price_mult() * CASE_DISCOUNT)), "sold": false}


## Objets possibles d'une rareté pour une caisse (débloqués, limites, légendaires uniques).
func case_pool(kind: String, rar: int) -> Array:
	if kind == "weapon":
		return WeaponDB.allowed_for(rar).filter(func(t): return Meta.item_open(ItemUnlockDB.key_weapon(t))).map(
			func(t): return {"type": "weapon", "wtype": t, "rar": rar})
	return amulet_candidates(rar).filter(func(d): return d.id != "case_opening").map(
		func(d): return {"type": "amulet", "id": d.id, "rar": rar})


## Tire un objet d'une caisse (si une rareté est vide, on descend d'un cran).
func roll_case_item(tier: int, kind: String) -> Dictionary:
	var odds: Array = CASE_ODDS[tier]
	var r := randf() * 100.0
	var rar := 0
	var acc := 0.0
	for k in 4:
		acc += odds[k]
		if r < acc:
			rar = k
			break
	while rar >= 0:
		var pool := case_pool(kind, rar)
		if not pool.is_empty():
			return pool.pick_random()
		rar -= 1
	return {}


func roll_rarity() -> int:
	var o := rarity_odds()
	var r := randf() * 100.0
	if r < o[2]:
		return 3
	if r < o[2] + o[1]:
		return 2
	if r < o[2] + o[1] + o[0]:
		return 1
	return 0


func new_shop() -> void:
	rerolls = 0
	event_used = false
	roll_shop()
	new_order()


## Carnet de commandes : une commande au hasard pour la vague suivante (récompense : de l'or).
func new_order() -> void:
	rseed("order", wave)
	_new_order()
	unseed()


func _new_order() -> void:
	order = {}
	if amulet_count("carnet_commandes") == 0 or (wave >= WAVES and not endless):
		return
	var reward := 20 + 5 * wave
	var w := wave + 1
	var kinds := [
		{"kind": "kills", "n": 20 + 3 * w, "text": Loc.t("Tue %d ennemis")},
		{"kind": "elem", "n": 6 + w, "text": Loc.t("Tue %d ennemis touchés par un élément (brûlés, gelés...)")},
		{"kind": "gold", "n": 10 + 3 * w, "text": Loc.t("Ramasse %d or pendant la vague")},
		{"kind": "nohit", "n": 20, "text": Loc.t("Tiens %d s d'affilée sans perdre de PV")},
		{"kind": "hp", "n": 60, "text": Loc.t("Termine la vague avec au moins %d%% de tes PV")},
	]
	var k: Dictionary = kinds.pick_random()
	order = {"kind": k.kind, "n": int(k.n), "progress": 0.0, "reward": reward, "done": false,
		"text": String(k.text) % int(k.n)}


## Or dépensé (compté pour le succès du Carnet de commandes).
func spend(n: int) -> void:
	gold -= n
	spent += n
	Meta.count("gold_spent", n)


## Achat annulé : l'or revient (et n'est plus compté comme dépensé).
func refund(n: int) -> void:
	gold += n
	spent -= n
	Meta.count("gold_spent", -n)


func _process(delta: float) -> void:
	if active:
		play_time += delta / maxf(0.01, Engine.time_scale)   # temps réel


func roll_shop() -> void:
	rseed("shop", wave, rerolls)
	_roll_shop()
	unseed()


func _roll_shop() -> void:
	# Un événement déjà joué dans cette boutique : plus d'autre événement, même en relançant
	for o in shop_offers:
		if o.type in EVENTS and o.sold:
			event_used = true
	shop_offers = []
	var n := 4 + Meta.level("shop_slot")
	if amulet_count("vernissage") > 0:
		n = 2   # Vernissage : 2 œuvres seulement... mais plus rares
	var offered := {}
	for i in n:
		var rar := roll_rarity()
		if amulet_count("vernissage") > 0:
			rar = mini(3, rar + 1)
		# Familiers : de temps en temps (uniques : jamais un déjà possédé ni deux fois le même)
		if randf() < 0.025:   # 2,5 % par emplacement
			var fpool := FamiliarDB.of_rarity(rar).filter(func(d): return not d.id in familiars and not offered.has("f:" + d.id) and Meta.item_open(ItemUnlockDB.key_familiar(d.id)))
			if not fpool.is_empty():
				var fd: Dictionary = fpool.pick_random()
				offered["f:" + fd.id] = true
				shop_offers.append({"type": "familiar", "id": fd.id, "rar": rar,
					"price": roundi(FamiliarDB.PRICE[rar] * price_mult()), "sold": false})
				continue
		if amulet_count("case_opening") > 0:
			# Case opening : une caisse à la place (la rareté tirée donne la caisse)
			shop_offers.append(make_case(rar, "weapon" if randf() < 0.4 else "amulet"))
			continue
		if randf() < 0.4:
			# Les armes spéciales n'apparaissent qu'à partir de leur rareté minimum.
			# Jamais deux fois la même arme à la même rareté dans un tirage
			var wpool := WeaponDB.allowed_for(rar).filter(func(t): return Meta.item_open(ItemUnlockDB.key_weapon(t)) and not offered.has("w:%s#%d" % [t, rar]))
			if wpool.is_empty():
				wpool = WeaponDB.allowed_for(rar).filter(func(t): return Meta.item_open(ItemUnlockDB.key_weapon(t)))
			var type: String = wpool.pick_random()
			offered["w:%s#%d" % [type, rar]] = true
			shop_offers.append({"type": "weapon", "wtype": type, "rar": rar,
				"price": roundi(WeaponDB.PRICE[rar] * price_mult()), "sold": false})
		else:
			# Jamais deux fois la même amulette dans un tirage ; légendaires = uniques (jamais une déjà possédée).
			# Limite d'achat : légendaires uniques, Étiquette de prix 5 max...
			var ok := func(d: Dictionary) -> bool:
				if not Meta.item_open(ItemUnlockDB.key_amulet(d.id)):
					return false   # verrouillée (succès du Codex)
				if offered.has(d.id):
					return false
				var lim := int(d.get("limit", 1 if int(d.rar) == 3 else 0))
				return (lim == 0 or amulet_count(d.id) < lim) and amulet_usable(d)
			var pool := AmuletDB.of_rarity(rar).filter(ok)
			if pool.is_empty():
				# Plus de légendaire disponible : une épique (mêmes règles : pas une unique déjà achetée)
				rar = 2
				pool = AmuletDB.of_rarity(2).filter(ok)
			if pool.is_empty():
				continue   # (presque impossible : tout est déjà en vitrine)
			var def: Dictionary = pool.pick_random()
			offered[def.id] = true
			shop_offers.append({"type": "amulet", "id": def.id, "rar": rar,
				"price": roundi(AmuletDB.PRICE[rar] * price_mult()), "sold": false})
	# Première rencontre : « ! » sur le tableau (retenu pour la suite, même après une relance)
	var fresh := []
	for o in shop_offers:
		var key: String = ItemUnlockDB.key_weapon(o.wtype) if o.type == "weapon" else (("f:" + o.id) if o.type == "familiar" else ItemUnlockDB.key_amulet(o.id))
		o["new"] = not Meta.item_seen(key)
		fresh.append(key)
	for key in fresh:
		Meta.mark_seen(key)
	apply_capital()
	roll_dice_prices()
	# Case « potion » : une fois sur deux
	if randf() < POTION_CHANCE:
		var roll := randf()
		var hid := "potion" if roll < 0.5 else ("grande_potion" if roll < 0.73 else ("seve" if roll < 0.9 else "encre"))
		if amulet_count("pacte_sang") > 0 and hid != "encre":
			hid = ""   # Pacte de sang : pas de potions (le pot d'encre reste possible)
		if hid != "":
			shop_offers.append({"type": "heal", "id": hid, "rar": 0,
				"price": roundi(HEALS[hid].price * price_mult()), "sold": false})
	# Case « événement », à part (dès la 2e boutique) : peut tomber EN PLUS d'une potion
	if wave >= 2 and not event_used and randf() < EVENT_CHANCE:
		var evs := EVENTS.filter(func(e): return e != "restorer" or not restorable().is_empty())
		shop_offers.append(make_event(evs.pick_random()))


## Aquarelle et plus : la couleur (élément) imposée au dessin de ce type d'ennemi, tirée une fois
## par partie parmi les couleurs débloquées. -1 = pas de contrainte.
const COLOR_DIFF := 2
func enemy_color(id: String) -> int:
	if difficulty < COLOR_DIFF:
		return -1
	if not enemy_colors.has(id):
		var pool := range(1, Pal.COUNT).filter(func(e): return Meta.has(Pal.UNLOCK[e]))
		enemy_colors[id] = pool.pick_random() if not pool.is_empty() else -1
	return int(enemy_colors[id])


## Fiche de la partie pour l'historique (menu Statistiques).
func history_entry(win: bool) -> Dictionary:
	var ws := {}
	for w in weapons:
		ws[w.type] = true
	var ams := {}
	for a in amulets:
		ams[a.id] = true
	return {"t": int(Time.get_unix_time_from_system()), "map": map, "diff": difficulty, "wave": wave,
		"win": win, "endless": endless, "kills": kills, "damage": roundi(run_damage), "gold": run_gold,
		"time": roundi(play_time), "level": level, "weapons": ws.keys(), "amulets": ams.keys(),
		"familiars": familiars.duplicate(), "killer": "" if win else killer,
		"colors": (char_a.get("frac", []) as Array).duplicate()}


# ------------------------------------------------------------------ Seed
## Chaque partie a une seed. Elle fixe les tirages des boss, des boutiques (et relances), des choix
## de niveau, des événements et de la 1re arme : on reseed le hasard global juste pour ces tirages,
## puis on le remet au hasard (les vagues elles-mêmes restent imprévisibles).
## Code partageable : « <carte><difficulté>-<seed en base 32> » (ex. 12-3KQ7M).
const SEED_MAX := 33554432   # 32^5 : 5 caractères
const SEED_DIGITS := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # (pas de I, L, O, U : pas de confusion)


func rseed(tag: String, a := 0, b := 0) -> void:
	seed(hash([seed_v, map, difficulty, tag, a, b]))


func unseed() -> void:
	randomize()


func seed_code() -> String:
	var s := ""
	var v := seed_v
	for i in 5:
		s = SEED_DIGITS[v % 32] + s
		v /= 32
	return "%d%d-%s" % [map, difficulty, s]


## Lit un code de seed. Retourne {map, diff, seed} ou {} s'il est mal écrit.
static func parse_seed(code: String) -> Dictionary:
	var c := code.strip_edges().to_upper().replace(" ", "")
	var parts := c.split("-")
	if parts.size() != 2 or parts[0].length() != 2 or parts[1].length() != 5 or not parts[0].is_valid_int():
		return {}
	var v := 0
	for ch in parts[1]:
		var k := SEED_DIGITS.find(ch)
		if k < 0:
			return {}
		v = v * 32 + k
	var m := int(parts[0][0])
	var d := int(parts[0][1])
	if not MapDB.MAPS.has(m) or d < 0 or d >= Meta.DIFFICULTIES.size():
		return {}
	return {"map": m, "diff": d, "seed": v}


## Mode infini : après la vague 15, chaque vague rend les ennemis 15 % plus solides et plus forts
## (cumulé), et un boss au hasard revient toutes les 5 vagues.
const ENDLESS_STEP := 1.15
func endless_mult() -> float:
	return pow(ENDLESS_STEP, maxi(0, wave - WAVES)) if endless else 1.0


## Mode infini : boss au hasard (parmi ceux de la carte) pour les vagues 20, 25, 30...
func plan_endless_boss(w: int) -> void:
	if not endless or w <= WAVES or w % 5 != 0 or boss_plan.has(w):
		return
	var all := []
	var b: Dictionary = MapDB.get_def(map).bosses
	for k in b:
		all.append_array(b[k])
	rseed("eboss", w)
	boss_plan[w] = all.pick_random()
	unseed()


## Vague « normale » d'un boss sur sa carte (5, 10 ou 15) : en infini, ses PV sont ramenés à la vague 15.
func boss_home_wave(id: String) -> int:
	var b: Dictionary = MapDB.get_def(map).bosses
	for k in b:
		if id in b[k]:
			return int(k)
	return WAVES


## Mécène : or reçu pour un contrat (grandit avec la vague).
func patron_gold(k: int) -> int:
	return roundi((20.0 + 8.0 * maxi(1, wave)) * float(PATRON_DEALS[k][1]))


## Offre « événement » de la boutique.
func make_event(ev: String) -> Dictionary:
	var o := {"type": ev, "id": ev, "rar": 0, "price": 0, "sold": false}
	match ev:
		"scratch":
			o.price = SCRATCH_PRICE
		"auction":
			# Épique (10 % légendaire) : arme ou amulette, jamais verrouillée ni légendaire en double
			var rar := 3 if randf() < 0.1 else 2
			var am := amulet_candidates(rar)
			var wp: Array = WeaponDB.allowed_for(rar).filter(func(t): return Meta.item_open(ItemUnlockDB.key_weapon(t)))
			if randf() < 0.5 and not wp.is_empty() or am.is_empty():
				o.item = {"type": "weapon", "wtype": wp.pick_random(), "rar": rar}
				o.value = roundi(WeaponDB.PRICE[rar] * price_mult())
			else:
				o.item = {"type": "amulet", "id": (am.pick_random() as Dictionary).id, "rar": rar}
				o.value = roundi(AmuletDB.PRICE[rar] * price_mult())
			o.rar = rar
			o.bid = maxi(1, roundi(o.value * 0.6))   # mise de départ (de l'acheteur)
			o.cap = roundi(o.value * randf_range(0.7, 1.4))   # plafond secret de l'acheteur
	return o


## Amulettes proposables à cette rareté (débloquées, limites d'achat, légendaires uniques).
func amulet_candidates(rar: int) -> Array:
	return AmuletDB.of_rarity(rar).filter(func(d):
		if not Meta.item_open(ItemUnlockDB.key_amulet(d.id)):
			return false
		if d.get("pet", false) and familiars.is_empty():
			return false
		var lim := int(d.get("limit", 1 if rar == 3 else 0))
		return (lim == 0 or amulet_count(d.id) < lim) and amulet_usable(d))


## Objets à effet immédiat : proposés seulement s'ils servent à quelque chose.
func amulet_usable(d: Dictionary) -> bool:
	match String(d.id):
		"pandore":
			return not amulets.is_empty()
		"diplome":
			return weapons.any(func(w): return int(w.rar) < 3)
	return true


## Boîte de Pandore : chaque amulette devient une amulette au hasard de la rareté au-dessus
## (une légendaire : une autre légendaire). Le dessin et la place restent. Retourne [[avant, après], ...].
func open_pandora() -> Array:
	var out := []
	for am in amulets:
		var old := AmuletDB.get_def(am.id)
		if old.is_empty():
			continue
		var rar := mini(int(old.rar) + 1, 3)
		var pool := AmuletDB.of_rarity(rar).filter(func(d):
			if d.get("consume", false) or d.get("on_buy", false) or d.id == old.id or not Meta.item_open(ItemUnlockDB.key_amulet(d.id)):
				return false
			if d.get("pet", false) and familiars.is_empty():
				return false
			var lim := int(d.get("limit", 1 if rar == 3 else 0))
			return lim == 0 or amulet_count(d.id) < lim)
		if pool.is_empty():
			continue
		var nd: Dictionary = pool.pick_random()
		if not amulet_art.has(nd.id):
			amulet_art[nd.id] = amulet_art[old.id].duplicate()   # (même dessin pour la nouvelle)
		am.id = nd.id
		am.mag = Stats.amulet_mag(am.a, nd)
		out.append([old.name, nd.name])
	recompute()
	return out


## Pitcoin : à chaque fin de vague, 1 chance sur 8 de gagner gros, sinon une petite perte.
## Retourne le gain (négatif = perte) de tous les Pitcoins.
func pitcoin_roll() -> int:
	var total := 0
	for k in amulet_count("pitcoin"):
		if randf() < 1.0 / 8.0:
			total += roundi(150 * price_mult())
		else:
			total -= roundi(15 * price_mult())
	total = maxi(total, -gold)
	gold += total
	return total


## Restaurateur : indices des amulettes possédées qu'il peut améliorer (pas les légendaires).
func restorable() -> Array:
	var out := []
	for i in amulets.size():
		var d := AmuletDB.get_def(amulets[i].id)
		if not d.is_empty() and int(d.rar) < 3 and not restore_pool(int(d.rar) + 1).is_empty():
			out.append(i)
	return out


## Amulettes que le Restaurateur peut rendre (rareté rar) : pas les objets à effet d'achat
## (Boîte de Pandore, Diplôme), qui n'ont de sens qu'achetés.
func restore_pool(rar: int) -> Array:
	return amulet_candidates(rar).filter(func(d): return not d.get("consume", false) and not d.get("on_buy", false))


## Le prix de base monte avec les vagues, et chaque relance coûte plus cher
## que la précédente (remis à zéro à chaque nouvelle boutique).
func reroll_price() -> int:
	if rerolls == 0 and Meta.has("free_reroll"):
		return 0
	var base := ceili(2.0 + eff_wave() * 0.6)
	var step := ceili(1.0 + eff_wave() * 0.3)
	var n := rerolls - (1 if Meta.has("free_reroll") else 0)
	# Coupon : 10 % moins cher par exemplaire (jamais gratuit)
	return maxi(1, roundi((base + maxi(0, n) * step) * pow(0.9, amulet_count("coupon"))))
