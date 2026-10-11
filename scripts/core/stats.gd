class_name Stats
extends RefCounted
## Transforme les dessins en statistiques. C'est ici qu'on équilibre (ou qu'on casse) le jeu.

const EFFECTS := ["", "pulse", "shimmer", "rainbow"]
const EFFECT_NAMES := {"": "Aucun", "pulse": "Pulse", "shimmer": "Scintille", "rainbow": "Arc-en-ciel"}
const EFFECT_UNLOCK := {"pulse": "fx_pulse", "shimmer": "fx_shimmer", "rainbow": "fx_rainbow"}
const EFFECT_COST := 0.15
## Rareté des armes : une rare vaut presque 2 communes, une légendaire environ 6.
## Fusionner 2 exemplaires garde donc les dégâts... et libère un emplacement.
const RAR_DMG := [1.0, 1.6, 2.5, 4.0]
const RAR_ATK := [0.0, 10.0, 20.0, 35.0]      # % de vitesse d'attaque
const RAR_CRIT := [0.0, 5.0, 10.0, 15.0]      # % de critique
const RAR_REACH := [1.0, 1.1, 1.2, 1.35]      # allonge / zone (mêlée)
const RAR_PIERCE := [0, 0, 1, 2]              # perforation (distance)
const RAR_PROC := [0.0, 0.1, 0.2, 0.3]        # chances d'effets élémentaires en plus
## L'encre ne paie que les contours : un dessin rempli contient environ
## FILL_REF fois plus de pixels que d'encre dépensée.
const FILL_REF := 1.6

const STAT_LABELS := [
	["max_hp", "PV max", ""], ["regen", "Régénération", ""], ["armor", "Armure", ""],
	["dodge", "Esquive", "%"], ["speed", "Vitesse", "%"], ["dmg", "Dégâts", "%"],
	["atk_speed", "Vit. d'attaque", "%"], ["crit", "Critique", "%"], ["range", "Portée", "%"],
	["lifesteal", "Vol de vie", "%"], ["luck", "Chance", ""], ["harvest", "Pourboire", ""],
	["thorns", "Épines", ""], ["el_power", "Puissance élém.", "%"],
]


static func empty_player() -> Dictionary:
	return {
		"max_hp": 0.0, "regen": 0.0, "armor": 0.0, "dodge": 0.0, "speed": 0.0, "speed_base": 0.0,
		"move": 0.0, "dmg": 0.0, "atk_speed": 0.0, "crit": 0.0, "crit_mult": 2.0, "range": 0.0,
		"lifesteal": 0.0, "luck": 0.0, "harvest": 0.0, "pickup": 0.0, "thorns": 0.0, "el_power": 0.0,
		"radius": 6.0, "res": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	}


# ------------------------------------------------------------------ Personnage

## Stats données par le dessin du perso seul.
static func character_part(a: Dictionary, effect: String) -> Dictionary:
	var s := empty_player()
	var p := float(a.pixels)
	# Peu d'encre = fragile mais rapide ; beaucoup d'encre = robuste mais lent.
	s.max_hp = 6.0 + p * 0.05
	s.speed_base = 150.0 * clampf(1.4 - p / 650.0, 0.5, 1.35)
	s.radius = clampf(sqrt(p) * 0.45, 3.0, 14.0)
	if p <= 0.0:
		return s
	s.dodge = a.sym * 12.0                          # symétrique = esquive
	s.armor = roundf(a.solidity * 4.0)              # dessin plein = armure
	s.crit = (1.0 - a.solidity) * 8.0               # traits fins = critique
	s.luck = minf(25.0, (a.components - 1) * 5.0)   # morceaux séparés = chance
	if a.bh > a.bw:
		s.range = minf(30.0, (float(a.bh) / a.bw - 1.0) * 20.0)   # grand = portée
	elif a.bw > a.bh:
		s.armor += roundf(minf(4.0, (float(a.bw) / a.bh - 1.0) * 3.0))  # large = armure
	var f: Array = a.frac
	s.dmg += f[Pal.FEU] * 30.0
	s.armor += roundf(f[Pal.GLACE] * 8.0)
	s.atk_speed += f[Pal.FOUDRE] * 30.0
	s.regen += f[Pal.POISON] * 6.0
	s.lifesteal += f[Pal.ARCANE] * 10.0
	s.dodge += f[Pal.LUMIERE] * 15.0
	for e in range(1, Pal.COUNT):
		s.res[e] = f[e] * 60.0
	match effect:
		"pulse":
			s.atk_speed += 10.0
		"shimmer":
			s.crit += 5.0
			s.dodge += 5.0
		"rainbow":
			s.el_power += 30.0
			for e in range(1, Pal.COUNT):
				s.res[e] += 5.0
	return s


static func player(run: Node) -> Dictionary:
	var a: Dictionary = run.char_a
	var s := character_part(a, run.char_effect)
	var chef: int = run.amulet_count("chef_oeuvre")
	if chef > 0:
		var m := pow(1.5, chef)
		for k in ["max_hp", "regen", "armor", "dodge", "dmg", "atk_speed", "crit", "range", "lifesteal", "luck"]:
			s[k] *= m
		for e in Pal.COUNT:
			s.res[e] *= m
	s.max_hp += run.level
	for am in run.amulets:
		var def := AmuletDB.get_def(am.id)
		if def.has("stat"):
			s[def.stat] += def.v * am.mag
		if def.has("malus"):
			s[def.malus[0]] += def.malus[1]
		for pv in def.get("plus", []):    # bonus en plus (comme la stat principale)
			s[pv[0]] += float(pv[1]) * am.mag
		for mv in def.get("minus", []):   # défauts en plus
			s[mv[0]] += float(mv[1])
		# La couleur d'une amulette donne un peu de résistance à son élément.
		var af: Array = am.a.frac
		for e in range(1, Pal.COUNT):
			s.res[e] += af[e] * 20.0
	# Bonus choisis en montant de niveau
	# Palimpseste : les bonus de niveau comptent double ; Stéroïdes : +50 %
	var bm: float = run.bonus_mult()
	for k in run.bonus:
		s[k] += run.bonus[k] * bm
	# Marques d'encre : leur couleur donne un peu de résistance (elles ne comptent pas dans la taille)
	for m in run.marks:
		var mf: Array = m.a.frac
		for e in range(1, Pal.COUNT):
			s.res[e] += mf[e] * 10.0
	var n := 0
	n = run.amulet_count("palette")
	if n > 0:
		s.dmg += 8.0 * n * a.elements
	n = run.amulet_count("esquisse")
	if n > 0 and a.pixels < 120:
		s.dmg += 40.0 * n
		s.speed += 20.0 * n
	n = run.amulet_count("poids")
	if n > 0:
		s.armor += floorf(a.pixels / 60.0) * n
	s.dmg += 3.0 * run.signature
	n = run.amulet_count("pinceau_fou")
	s.atk_speed += 40.0 * n
	n = run.amulet_count("encrier")
	s.max_hp *= pow(0.85, n)
	# Lunettes de l'oculiste : test de vision réussi = +8 % partout, raté (ou pas encore fait) = la moitié
	if run.amulet_count("oculiste") > 0:
		var ov := 8.0 if run.oculist_ok == 1 else 4.0
		for k in ["dmg", "atk_speed", "crit", "range", "dodge", "speed", "lifesteal"]:
			s[k] += ov
	n = run.amulet_count("perspective")
	s.range += 30.0 * n
	n = run.amulet_count("tache")
	s.speed -= 20.0 * n
	s.armor += 2.0 * n
	s.max_hp += 5.0 * n
	s.radius += 2.0 * n
	s.dmg += 15.0 * run.joconde
	s.dmg += run.wave_dmg   # Grattage (étoile) : vague en cours
	n = run.amulet_count("cadre_dore")
	if n > 0:
		s.dmg += minf(40.0, floorf(run.gold / 5.0)) * n
	n = run.amulet_count("collage")
	if n > 0:
		var kinds := {}
		for w in run.weapons:
			kinds[w.type] = true
		s.dmg += 8.0 * kinds.size() * n
	n = run.amulet_count("echelle")
	s.dmg += 2.0 * run.level * n
	n = run.amulet_count("fresque")
	s.dmg += minf(60.0, 0.5 * (Meta.data.get("gallery", []) as Array).size()) * n
	n = run.amulet_count("accordeon")
	s.atk_speed += 0.5 * maxf(0.0, s.speed) * n
	n = run.amulet_count("taille_douce")
	s.crit += floorf(maxf(0.0, s.armor) / 3.0) * n
	s.max_hp += 10.0 * run.bosses * run.amulet_count("toile_tendue")   # Toile tendue : +10 PV max par boss vaincu
	s.max_hp *= pow(0.8, run.amulet_count("midas")) * pow(0.9, run.amulet_count("derniere_touche"))
	# Épines : Carapace (+25 % de l'armure), Cactus (+1 par 10 PV max)
	s.thorns += 0.25 * maxf(0.0, s.armor) * run.amulet_count("carapace")
	s.thorns += floorf(s.max_hp / 10.0) * run.amulet_count("cactus")
	# Pacte de sang : vol de vie doublé, plus de régénération
	if run.amulet_count("pacte_sang") > 0:
		s.lifesteal *= 2.0
		s.regen = 0.0
	# Finalisation
	s.max_hp = maxf(1.0, roundf(s.max_hp))
	s.move = s.speed_base * maxf(0.25, 1.0 + s.speed / 100.0)
	s.dodge = minf(s.dodge, 60.0)
	for e in Pal.COUNT:
		s.res[e] = minf(s.res[e], 80.0)
	s.pickup += 50.0   # rayon de ramassage fixe (plus une stat : les gouttes sont aspirées en fin de vague)
	return s


# ------------------------------------------------------------------ Armes

## w = {type, rar, a, effect, [ba, bullet, beffect]}. Le type donne le comportement et
## des multiplicateurs ; le remplissage (pixels / encre du type) donne la force.
static func weapon(w: Dictionary) -> Dictionary:
	var def := WeaponDB.get_def(w.type)
	var st := melee(w, def) if def.kind == "melee" else ranged(w, def)
	st.scale = def.get("scale", "")
	return st


## Armes à RATIO : dégâts d'un coup selon la stat liée (appliqué à chaque coup, donc
## toujours à jour : or dans la bourse, armes possédées, stats du moment...).
## Armes à ratio : la partie ratio grandit de 15 % par rang de rareté (fusion) :
## commune ×1, rare ×1,15, épique ×1,3, légendaire ×1,45.
const RATIO_PER_RAR := 0.15


static func ratio_k(rar: int) -> float:
	return 1.0 + RATIO_PER_RAR * rar


static func scaled_damage(base: float, scale: String, rar := 0) -> float:
	var s: Dictionary = Run.stats
	var k := ratio_k(rar)
	match scale:
		"free_slots":
			return base * (1.0 + k * 0.6 * maxi(0, Run.max_weapons() - Run.weapons.size()))
		"max_hp":
			return base + k * 0.15 * float(s.get("max_hp", 0.0))
		"armor":
			return base + k * 1.5 * maxf(0.0, s.get("armor", 0.0))
		"speed":
			return base * (1.0 + k * maxf(0.0, s.get("speed", 0.0)) / 100.0)
		"luck":
			return base + k * 0.25 * maxf(0.0, s.get("luck", 0.0))
		"gold":
			return base + floorf(k * Run.gold / 12.0)
		"range":
			return base * (1.0 + k * 1.5 * maxf(0.0, s.get("range", 0.0)) / 100.0)
		"colors":
			return base * (1.0 + k * 0.35 * int(Run.char_a.get("elements", 0)))
		"pixels":
			var pm := pixel_mult()
			return base * (1.0 + k * (pm - 1.0) if pm > 1.0 else pm)   # (un malus ne grandit pas)
	return base


## Cutter : multiplicateur de ses critiques (×2 + critique ÷ 35, la partie ratio grandit avec la rareté).
static func crit_ratio(crit: float, rar := 0) -> float:
	return 2.0 + ratio_k(rar) * crit / 35.0


## Vol de vie (en %) d'un coup de cette arme. Pipette : ×3 + 5 %. Au-delà de 100 %,
## un coup soigne plusieurs PV.
static func lifesteal_of(scale: String, rar := 0) -> float:
	var ls: float = maxf(0.0, Run.stats.get("lifesteal", 0.0))
	return ls * 3.0 * ratio_k(rar) + 5.0 if scale == "lifesteal" else ls


## Valeur actuelle d'une amulette dont l'effet dépend de la partie ("" sinon).
static func amulet_live(id: String) -> String:
	var s: Dictionary = Run.stats
	var a: Dictionary = Run.char_a
	match id:
		"capital":
			return "prix moyen de la vague : ● %d" % Run.avg_item_price()
		"palette":
			return "%d couleur(s) = +%d%% dégâts" % [int(a.get("elements", 0)), 8 * int(a.get("elements", 0))]
		"esquisse":
			return "%d px, %s" % [int(a.get("pixels", 0)), "actif" if int(a.get("pixels", 0)) < 120 else "inactif (120 px ou plus)"]
		"poids":
			return "+%d armure" % floori(float(a.get("pixels", 0)) / 60.0)
		"signature":
			return "+%d%% dégâts" % (3 * Run.signature)
		"cadre_dore":
			return "+%d%% dégâts" % mini(40, floori(Run.gold / 5.0))
		"collage":
			var kinds := {}
			for w in Run.weapons:
				kinds[w.type] = true
			return "%d type(s) = +%d%% dégâts" % [kinds.size(), 8 * kinds.size()]
		"joconde":
			return "+%d%% dégâts" % (15 * Run.joconde)
		"fresque":
			var g := (Meta.data.get("gallery", []) as Array).size()
			return "%d dessins = +%d%% dégâts" % [g, roundi(minf(60.0, 0.5 * g))]
		"taille_douce":
			return "+%d%% critique" % floori(maxf(0.0, s.get("armor", 0.0)) / 3.0)
		"echelle":
			return "+%d%% dégâts" % (2 * Run.level)
		"accordeon":
			return "+%d%% vit. d'attaque" % roundi(0.5 * maxf(0.0, s.get("speed", 0.0)))
		"carapace":
			return "+%d épines" % roundi(0.25 * maxf(0.0, s.get("armor", 0.0)))
		"cactus":
			return "+%d épines" % floori(float(s.get("max_hp", 0.0)) / 10.0)
		"etiquette_prix":
			var c := Run.amulet_count("etiquette_prix")
			return "-%d%% sur les prix (%d/5)" % [roundi((1.0 - pow(0.92, c)) * 100.0), c]
	return ""


## Silhouette : ×0,5 pour un tout petit perso, ×1,1 vers 250 px, ×2,1 vers 600 px (max ×3,5).
static func pixel_mult() -> float:
	return clampf(0.4 + float(Run.char_a.get("pixels", 0)) / 350.0, 0.5, 3.5)


## Texte « valeur actuelle du ratio » (boutique, collection).
static func scale_text(scale: String, rar := 0) -> String:
	var s: Dictionary = Run.stats
	var b := 10.0   # (dégâts d'exemple pour lire les multiplicateurs)
	match scale:
		"free_slots":
			var free := maxi(0, Run.max_weapons() - Run.weapons.size())
			return "Ratio : %d emplacement(s) libre(s) = ×%.1f" % [free, scaled_damage(b, scale, rar) / b]
		"max_hp":
			return "Ratio : %d PV max = +%d dégâts" % [int(s.get("max_hp", 0)), roundi(scaled_damage(0.0, scale, rar))]
		"armor":
			return "Ratio : %d armure = +%d dégâts" % [int(s.get("armor", 0)), roundi(scaled_damage(0.0, scale, rar))]
		"speed":
			return "Ratio : %+d%% vitesse = ×%.2f" % [int(s.get("speed", 0)), scaled_damage(b, scale, rar) / b]
		"crit":
			return "Ratio : %d%% critique = critiques ×%.1f" % [int(s.get("crit", 0)), maxf(float(s.get("crit_mult", 2.0)), crit_ratio(float(s.get("crit", 0.0)), rar))]
		"luck":
			return "Ratio : %d chance = +%d dégâts" % [int(s.get("luck", 0)), roundi(scaled_damage(0.0, scale, rar))]
		"gold":
			return "Ratio : %d or = +%d dégâts" % [Run.gold, roundi(scaled_damage(0.0, scale, rar))]
		"range":
			return "Ratio : %+d%% portée = ×%.2f" % [int(s.get("range", 0)), scaled_damage(b, scale, rar) / b]
		"colors":
			return "Ratio : %d couleur(s) sur ton perso = ×%.2f" % [int(Run.char_a.get("elements", 0)), scaled_damage(b, scale, rar) / b]
		"pixels":
			return "Ratio : %d pixels = ×%.2f" % [int(Run.char_a.get("pixels", 0)), scaled_damage(b, scale, rar) / b]
		"lifesteal":
			return "Ratio : %d%% vol de vie = %d%% sur ses coups" % [int(s.get("lifesteal", 0)), roundi(lifesteal_of("lifesteal", rar))]
	return ""


## La TAILLE change le style, pas la puissance : les dégâts par seconde restent proches.
## Petit = coups rapides, +critique, plus d'effets par seconde (brûlure, gel, vol de vie...).
## Gros = gros coups, allonge, zone et recul.
static func melee(w: Dictionary, def: Dictionary) -> Dictionary:
	var a: Dictionary = w.a
	var p := float(a.pixels)
	var fill := clampf(p / (def.ink * FILL_REF), 0.05, 1.5)
	var st := {"kind": "melee", "type": w.type, "atk_dur": float(def.get("atk_dur", 1.0))}
	st.damage = 8.0 * def.dmg * (0.35 + 0.9 * fill) * RAR_DMG[w.rar]   # gros = coups forts
	st.cooldown = 0.85 * def.cd * (0.35 + 0.8 * fill)                  # ... mais lents
	st.reach = (36.0 + a.diag * 1.2) * def.reach                        # long = allonge
	st.knock = 30.0 + p * 0.2
	st.crit = a.sym * 10.0 + 3.0 + def.get("crit", 0.0) + _small_crit(fill, 25.0)
	st.style = def.style
	st.hit_r = clampf(a.long * 0.35, 8.0, 18.0)
	st.aoe = 18.0 + a.long * 0.6
	st.fill = fill
	st.frac = (a.frac as Array).duplicate()
	_apply_rarity(st, w.rar)
	st.reach *= RAR_REACH[w.rar]
	st.aoe *= RAR_REACH[w.rar]
	st.hit_r *= RAR_REACH[w.rar]
	_apply_effect(st, w.effect)
	return st


static func ranged(w: Dictionary, def: Dictionary) -> Dictionary:
	var nobullet: bool = def.get("nobullet", false)
	if nobullet:
		# Pas de balles dessinées : un orbe standard, l'arme fait tout.
		w = w.duplicate()
		w.bullet = WeaponDB.orb()
		w.ba = Analyzer.analyze(w.bullet)
	var a: Dictionary = w.a
	var b: Dictionary = w.ba
	var p := float(a.pixels)
	var fill := clampf(p / (def.ink * FILL_REF), 0.05, 1.5)
	var parts := Analyzer.split_components(w.bullet, b)
	# Taille totale des balles (par rapport à l'encre prévue pour elles)
	var bpx := 0.0
	for part in parts:
		bpx += part.count
	var bfill := clampf(bpx / (def.bink * FILL_REF), 0.05, 1.5)
	var st := {"kind": "ranged", "type": w.type, "style": def.style, "pierce_dmg": float(def.get("pierce_dmg", 1.0))}
	# Arme ET balles : gros = tirs forts mais lents, petit = rafales rapides
	st.cooldown = 0.6 * def.cd * (0.4 + 0.75 * fill) * (0.45 + 0.8 * bfill)
	st.dmg_mult = def.dmg * (0.4 + 0.85 * fill) * RAR_DMG[w.rar]
	st.range = (150.0 + a.diag * 3.0) * (0.6 if def.style == "spread" else 1.0)
	st.spread = (1.0 - a.sym) * 12.0                                     # symétrique = précis
	st.crit = a.sym * 5.0 + 3.0 + _small_crit(fill, 15.0) + _small_crit(bfill, 10.0)
	st.pellets = int(def.get("pellets", 1))
	st.fill = fill
	st.bullets = []
	# Dégâts d'un tir répartis entre les morceaux (chaque morceau = un projectile)
	var shot: float = 12.0 * st.dmg_mult * (0.45 + 0.9 * bfill)
	# Coup de référence (balles qui remplissent leur encre) : les effets par coup (éléments,
	# vol de vie) sont proportionnels à la taille du coup, voir Arena.hit_enemy.
	st.ref_hit = 12.0 * st.dmg_mult * 1.35
	var penalty := 1.0 / (1.0 + 0.08 * (parts.size() - 1))
	var scale := 45.0 / float(def.bink)
	for part in parts:
		var pc := float(part.count) * scale
		st.bullets.append({
			"image": part.image, "center": part.center,
			"damage": shot * penalty * float(part.count) / maxf(1.0, bpx),   # part du tir selon la taille du morceau
			"speed": clampf(380.0 - pc * 3.2, 90.0, 420.0) * def.speed,         # grosse balle = lente
			"radius": clampf(maxf(part.size.x, part.size.y) / 2.0, 2.0, 12.0),
			"pierce": _size_pierce(float(part.count) / (def.bink * FILL_REF)) + int(def.get("pierce", 0)),  # grosse = perforante
		})
	st.frac = a.frac.duplicate() if nobullet else mix_frac(a, b)
	_apply_rarity(st, w.rar)
	for bl in st.bullets:
		if bl.pierce > 0:   # la rareté renforce les balles qui perforent déjà (les petites, jamais)
			bl.pierce += RAR_PIERCE[w.rar]
	_apply_effect(st, w.effect)
	_apply_effect(st, w.get("beffect", ""))
	return st


## Couleurs d'une arme à distance : arme + balles comptées ensemble, au nombre de pixels
## (une balle minuscule ne change presque pas la couleur, une grosse balle pèse beaucoup).
static func mix_frac(a: Dictionary, b: Dictionary) -> Array:
	var pa := float(a.pixels)
	var pb := float(b.pixels)
	var frac := []
	for e in Pal.COUNT:
		frac.append((float(a.frac[e]) * pa + float(b.frac[e]) * pb) / maxf(1.0, pa + pb))
	return frac


## Bonus communs à toutes les armes selon la rareté.
static func _apply_rarity(st: Dictionary, rar: int) -> void:
	st.cooldown /= 1.0 + RAR_ATK[rar] / 100.0
	st.crit += RAR_CRIT[rar]
	for e in range(1, Pal.COUNT):
		if st.frac[e] > 0.0:
			st.frac[e] *= 1.0 + RAR_PROC[rar]
	st.rar = rar


## Bonus de critique des petits dessins : maximal à ~0 de remplissage, nul à 100%.
static func _small_crit(fill: float, amount: float) -> float:
	return (1.0 - minf(fill, 1.0)) * amount


## Ce que fait une encre à effet (Pulse, Scintille, Arc-en-ciel) selon ce qu'on dessine.
## kind = cfg.kind de la toile. Les mêmes chiffres que character_part, _apply_effect et enemy_art :
## à tenir à jour ensemble.
const EFFECT_WHAT := {
	"character": {"pulse": "+10% vit. d'attaque", "shimmer": "+5% critique, +5% esquive", "rainbow": "+30% puissance élém., +5% résistances"},
	"weapon": {"pulse": "recharge 10% plus vite", "shimmer": "+8% critique sur l'arme", "rainbow": "+10% à chaque effet élémentaire"},
	"enemy": {"pulse": "aucun bonus pour lui", "shimmer": "ATTENTION : +2,5% d'esquive pour lui", "rainbow": "ATTENTION : +2,5% de résistances pour lui"},
}


## Version courte, pour la ligne d'aide sous la toile (une seule ligne).
static func effect_short(effect: String, kind: String) -> String:
	if effect == "":
		return ""
	var group := "character" if kind == "character" else ("weapon" if kind in ["melee", "ranged", "bullet"] else ("enemy" if kind in ["enemy", "boss"] else ""))
	var what: String = EFFECT_WHAT[group][effect] if group != "" else "seulement l'animation, aucun bonus"
	return "%s : %s" % [EFFECT_NAMES[effect], what]


## Version complète, pour l'infobulle du bouton.
static func effect_text(effect: String, kind: String) -> String:
	if effect == "":
		return "Aucun effet : toute ton encre sert au dessin."
	return effect_short(effect, kind) + ". Coûte 15% de l'encre du dessin."


static func _apply_effect(st: Dictionary, effect: String) -> void:
	match effect:
		"pulse":
			st.cooldown *= 0.9
		"shimmer":
			st.crit += 8.0
		"rainbow":
			for e in range(1, Pal.COUNT):
				st.frac[e] += 0.1


# ------------------------------------------------------------------ Ennemis

## Stats d'un ennemi d'après son dessin : les MÊMES règles que pour ton perso (voir character_part),
## mais seulement PV, vitesse, esquive, armure (en %), dégâts et résistances, et deux fois moins fortes.
## La taille est comptée par rapport à l'encre de l'ennemi (un dessin plein = un perso plein).
## Plus il a de stats, plus il lâche de butin : bien dessiner reste intéressant.
static func enemy_art(a: Dictionary, ink: int, effect := "") -> Dictionary:
	var fill := clampf(float(a.pixels) / (ink * FILL_REF), 0.0, 1.0)
	var m := {
		"hp": 0.6 + 0.8 * fill, "element": a.dominant,
		"radius": clampf(sqrt(float(a.pixels)) * 0.5, 3.0, 40.0),
		"speed": 1.0, "dodge": 0.0, "armor": 0.0, "dmg": 0.0, "res": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	}
	var loot := 0.5 + 1.5 * fill
	if a.pixels <= 0:
		m.loot = loot
		return m
	var pe := fill * 400.0   # « pixels de perso » équivalents
	m.speed = 1.0 + (clampf(1.4 - pe / 650.0, 0.5, 1.35) - 1.0) * 0.5   # gros = lent
	var f: Array = a.frac
	var armor := roundf(a.solidity * 4.0) + roundf(f[Pal.GLACE] * 8.0)   # plein / bleu = armure
	if a.bw > a.bh:
		armor += roundf(minf(4.0, (float(a.bw) / a.bh - 1.0) * 3.0))      # large = armure
	m.armor = minf(35.0, armor * 0.5 * 4.0)                               # en % (1 point = 4 %)
	m.dodge = (a.sym * 12.0 + f[Pal.LUMIERE] * 15.0) * 0.5                 # symétrique / blanc = esquive
	m.dmg = f[Pal.FEU] * 30.0 * 0.5                                       # rouge = dégâts
	var best_res := 0.0
	for e in range(1, Pal.COUNT):
		m.res[e] = f[e] * 60.0 * 0.5                                      # chaque couleur résiste à son élément
	match effect:
		"shimmer":
			m.dodge += 2.5
		"rainbow":
			for e in range(1, Pal.COUNT):
				m.res[e] += 2.5
	for e in range(1, Pal.COUNT):
		best_res = maxf(best_res, m.res[e])
	m.loot = loot * (1.0 + (m.dodge + m.armor + m.dmg + best_res * 0.5) / 100.0)
	return m


static func eproj_art(a: Dictionary) -> Dictionary:
	return {
		"speed": clampf(1.3 - a.pixels / 40.0, 0.5, 1.3),
		"radius": clampf(a.long / 2.0, 2.0, 8.0), "element": a.dominant,
	}


## Puissance de l'effet d'une amulette : TOUJOURS ×1, quelle que soit la taille du dessin.
## (Seules ses couleurs comptent : résistances élémentaires, voir player().)
static func amulet_mag(_a: Dictionary, _def: Dictionary) -> float:
	return 1.0


# ------------------------------------------------------------------ Aperçus (écran de dessin)

static func preview(cfg: Dictionary, img: Image, effect: String) -> String:
	var a := Analyzer.analyze(img)
	var L := []
	match cfg.kind:
		"character":
			var s := character_part(a, effect)
			L.append("PV : %d" % roundi(s.max_hp))
			L.append("Vitesse : %d" % roundi(s.speed_base))
			L.append("Taille : %d" % roundi(s.radius))
			_line(L, "Esquive", s.dodge, "%")
			_line(L, "Armure", s.armor, "")
			_line(L, "Critique", s.crit, "%")
			_line(L, "Chance", s.luck, "")
			_line(L, "Portée", s.range, "%")
			_line(L, "Dégâts", s.dmg, "%")
			_line(L, "Vit. attaque", s.atk_speed, "%")
			_line(L, "Régén.", s.regen, "")
			_line(L, "Vol de vie", s.lifesteal, "%")
			_res_lines(L, s.res)
		"familiar":
			if a.pixels > 0:
				var sm := FamiliarDB.size_mult(cfg.def, a.pixels)
				L.append("Taille : %d%% de l'encre" % roundi(sm.fill * 100.0))
				L.append("Dégâts : ×%.2f" % sm.dmg)
				L.append("Vitesse : ×%.2f" % sm.spd)
				L.append("")
				L.append("Gros dessin = frappe fort mais lent.")
				L.append("Petit dessin = rapide, agit plus souvent.")
		"melee":
			if a.pixels > 0:
				var def := WeaponDB.get_def(cfg.wtype)
				var st := melee({"type": cfg.wtype, "a": a, "rar": 0, "effect": effect}, def)
				# (dégâts et critique en icônes sur la 1re ligne ; la recharge à part, sinon elle déborde)
				L.append("Dégâts : %.1f" % st.damage)
				L.append("Critique : %d%%" % roundi(st.crit))
				L.append("Recharge : %.2fs" % st.cooldown)
				L.append("Dégâts/s : %.1f" % (st.damage / st.cooldown))
				L.append("Allonge : %d" % roundi(st.reach))
				_el_lines(L, st.frac, a.frac)
		"ranged":
			if a.pixels > 0:
				var def := WeaponDB.get_def(cfg.wtype)
				var fill := clampf(a.pixels / (def.ink * FILL_REF), 0.05, 1.5)
				L.append("Cadence : %s" % ("très rapide" if fill < 0.35 else ("rapide" if fill < 0.7 else ("normale" if fill < 1.05 else "lente"))))
				L.append("Puissance : x%.2f" % (def.dmg * (0.4 + 0.85 * fill)))
				L.append("Critique bonus : +%d%%" % roundi(_small_crit(fill, 15.0)))
				L.append("Portée : %d" % roundi(150.0 + a.diag * 3.0))
				L.append("Précision : %d%%" % roundi(a.sym * 100.0))
				_el_lines(L, a.frac)
				L.append("")
				L.append("Ensuite : ses balles !")
		"bullet":
			if a.pixels > 0:
				var w := {"type": cfg.wtype, "a": cfg.weapon_a, "ba": a, "bullet": img, "rar": 0, "effect": cfg.get("weapon_effect", ""), "beffect": effect}
				var st := ranged(w, WeaponDB.get_def(cfg.wtype))
				var bl: Array = st.bullets
				L.append("Projectiles : %d" % (bl.size() * st.pellets))
				var tot := 0.0
				for b in bl:
					tot += b.damage
				L.append("Dégâts/tir : %.1f" % (tot * st.pellets))
				L.append("Dégâts/s : %.1f" % (tot * st.pellets / st.cooldown))
				L.append("Vitesse : %d" % roundi(bl[0].speed))
				L.append("Perforation : %d" % bl[0].pierce)
				L.append("Recharge : %.2fs" % st.cooldown)
				var drawn: Array = (a.frac as Array).duplicate()
				for e in drawn.size():
					drawn[e] = maxf(drawn[e], cfg.weapon_a.frac[e])
				_el_lines(L, st.frac, drawn)
		"enemy", "boss":
			var e := enemy_art(a, cfg.ink, effect)
			L.append("PV : x%.2f" % e.hp)
			L.append("Vitesse : x%.2f" % e.speed)
			if e.dodge >= 0.5:
				L.append("Esquive : %d%%" % roundi(e.dodge))
			if e.armor >= 0.5:
				L.append("Armure : -%d%% dégâts" % roundi(e.armor))
			if e.dmg >= 0.5:
				L.append("Dégâts : +%d%%" % roundi(e.dmg))
			var rl := []
			for el in range(1, Pal.COUNT):
				if e.res[el] >= 0.5:
					rl.append("%s %d%%" % [Pal.NAMES[el], roundi(e.res[el])])
			if not rl.is_empty():
				L.append("Rés. " + " · ".join(rl))
			L.append("Butin : x%.2f" % e.loot)
			L.append("Élément : %s" % Pal.NAMES[e.element])
		"eproj":
			var e := eproj_art(a)
			L.append("Vitesse : x%.2f" % e.speed)
			L.append("Taille : %d" % roundi(e.radius))
			L.append("Élément : %s" % Pal.NAMES[e.element])
		"mark":
			L.append("Bonus : " + String(cfg.upgrade.text))
			L.append("Ne compte pas dans ta taille.")
			for e in range(1, Pal.COUNT):
				if a.frac[e] > 0.0:
					L.append("Résist. %s +%d%%" % [Pal.NAMES[e], roundi(a.frac[e] * 10.0)])
		"amulet":
			var def: Dictionary = cfg.def
			L.append(AmuletDB.describe(def))
			L.append("(La taille du dessin ne change pas l'effet.)")
			for e in range(1, Pal.COUNT):
				if a.frac[e] > 0.0:
					L.append("Résist. %s +%d%%" % [Pal.NAMES[e], roundi(a.frac[e] * 20.0)])
	return "\n".join(L)


static func _line(L: Array, label: String, v: float, unit: String) -> void:
	if absf(v) >= 0.5:
		L.append("%s : %+d%s" % [label, roundi(v), unit])


static func _res_lines(L: Array, res: Array) -> void:
	var parts := []
	for e in range(1, Pal.COUNT):
		if res[e] >= 0.5:
			parts.append("%s %d%%" % [Pal.NAMES[e], roundi(res[e])])
	# Deux résistances par ligne pour rester compact
	for i in range(0, parts.size(), 2):
		L.append("Rés. " + " · ".join(parts.slice(i, i + 2)))


## Les effets élémentaires d'une arme. drawn = les parts de couleur réellement DESSINÉES : les
## éléments qui ne viennent que de l'encre Arc-en-ciel tiennent en une seule ligne (sinon 6 lignes).
static func _el_lines(L: Array, frac: Array, drawn: Array = []) -> void:
	var others := 0.0
	for e in range(1, Pal.COUNT):
		if frac[e] < 0.01:
			continue
		if not drawn.is_empty() and drawn[e] < 0.01:
			others = maxf(others, frac[e])
			continue
		L.append("%s : %d%%" % [Pal.WEAPON_EFFECT[e], roundi(minf(frac[e], 1.0) * 100.0)])
	if others > 0.0:
		L.append("Les autres : %d%%" % roundi(minf(others, 1.0) * 100.0))


static func describe_player(s: Dictionary) -> String:
	var L := []
	for row in STAT_LABELS:
		var v: float = s[row[0]]
		if row[0] == "max_hp":
			L.append("%s : %d" % [row[1], roundi(v)])
		else:
			L.append("%s : %s%d%s" % [row[1], "+" if v > 0 else "", roundi(v), row[2]])
	_res_lines(L, s.res)
	return "\n".join(L)



## Perforation d'une balle selon sa TAILLE (part de l'encre prévue pour les balles) :
## petite = s'arrête au premier ennemi, grosse = traverse jusqu'à 3 ennemis.
static func _size_pierce(size: float) -> int:
	if size < 0.35:
		return 0
	if size < 0.7:
		return 1
	if size < 1.05:
		return 2
	return 3
