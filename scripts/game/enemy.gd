class_name Enemy
extends Node2D
## Ennemi dessiné par le joueur. Le comportement est fixe (défini par son type) et pensé
## autour du dessin : flaques, traits d'encre, règle, compas, gomme, taches piégées...

const BOSS_DMG := 0.975     # (1,3 puis -25 % : un coup de boss fait ~3 de moins en moyenne)
const BOSS_SPEED := 1.12
const BOSS_EASE := 0.85        # PV et dégâts des boss (réglage global)
const BOSS_EASE_FIRST := 0.75  # le premier boss de la carte (vague 5)

var arena: Arena
var id := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var dmg := 1.0
var speed := 50.0
var radius := 8.0
var element := 0
var color := 0              # couleur dans le cercle des faiblesses (Pal.color_of)
var dodge := 0.0            # stats tirées du dessin (Stats.enemy_art) : esquive en %,
var armor := 0.0            # armure = % de dégâts en moins sur les coups,
var res: Array = []         # résistance (%) à chaque élément
var weak_t := 0.0           # affichage « FAIBLE ! » / « RÉSISTE » (pas à chaque coup)
var ink_col := Color.BLACK
var loot := 1.0
var dead := false
var is_boss := false
var small := false
var elite := false
var power := ""             # Huile+ : pouvoir de l'élite (shield, fast, vampire, explosive, summoner)
var shield_up := false      # élite « bouclier » : ignore le premier coup
var summon_cd := 0.0        # élite « invocatrice »
var frenzy_on := false      # Chef-d'œuvre : boss en fureur sous 25 % de PV
var toile_phase := 1        # Toile Blanche / Encrier renversé : phase 1, 2 ou 3
var light_shots := false    # Encrier (phase 2+) : ses tirs sont des éclats de LUMIÈRE
var reflet: Enemy           # Encrier (phase 3) : son reflet de Rorschach
var reflet_of: Enemy        # ... et pour le reflet : l'Encrier qu'il copie
var blot_cd := 3.0          # Encrier : prochain buvard
var hit_at := Vector2.INF   # coup reçu par le reflet : le chiffre s'affiche sur lui
var boss_inv := 0.0         # boss intouchable (passage de phase)
var contact := true
var body: Node2D
var sprite: Sprite2D
var mat: ShaderMaterial
var base_scale := 1.0
var knock := Vector2.ZERO
var flash := 0.0
var squash := 0.0            # écrasement quand on le frappe (0 = forme normale)
var t := 0.0
var phase := 0.0
var hop_h := 0.0

# États de comportement
var state := "walk"
var st_t := 0.0
var cd := 0.0
var cd2 := 0.0
var cd3 := 0.0
var dash_dir := Vector2.ZERO
var tp_pos := Vector2.ZERO     # Raturé : où il va réapparaître (annoncé 1 s avant)
var tp_mark := {}
var spiral_a := 0.0
var last_atk := ""          # Raturé : dernière attaque (jamais deux fois de suite)
var atk_bag: Array = []     # Raturé : attaques restantes du cycle en cours
var hatch_a := 0.0          # Raturé : angle des hachures
var pattern := 0
var repeat := 0
var center := Vector2.ZERO
var orbit_r := 150.0
var orbit_a := 0.0
var mirror_mode := 0
var partner: Enemy           # Trombones : l'autre bout du fil
var crumple := 0             # Brouillon : nombre de fois froissé
var belly_v := 0             # Corbeille : or avalé
var belly_xp := 0            # Corbeille : expérience avalée
var charge := 0.0            # Barre de chargement : 0 à 1
var held_by: Enemy           # attrapé par Le Curseur : il le soulève avant de le lancer
var thrown_t := 0.0          # lancé par Le Curseur : il vole comme un projectile
var thrown_v := Vector2.ZERO
var thrown_dmg := 0.0
var grab_e: Enemy            # Le Curseur : l'ennemi qu'il tient
var grabbed := false         # Le Curseur : il tient le joueur
var struggle := 0            # ... nombre de secousses du joueur
var shake_dir := Vector2.ZERO
var cast_hp := 0.0           # Le Curseur : ses PV au début de l'Alt+F4
var fake_done := false       # Le Curseur : la fausse victoire a déjà eu lieu
var hit_ids := {}
# Effets des armes épiques / légendaires
var pin_t := 0.0             # Agrafeuse : épinglé au sol
var slip_t := 0.0            # La Banane : assommé après avoir glissé
var firefly := false         # aura de la Luciole : +15 % de dégâts subis
var slide := Vector2.ZERO    # La Banane : glissade (ralentit doucement)
var slide_hits := {}         # ennemis déjà percutés pendant cette glissade
var slip_chain := {}         # réaction en chaîne de la Banane (nombre d'ennemis à terre, STRIKE déjà fait)
var wet_t := 0.0             # Brumisateur : mouillé
var gust_t := 0.0            # Éventail : projeté (choc contre un bord)
var gust_dmg := 0.0
var staple: Enemy            # Agrafeuse : l'autre ennemi agrafé
var staple_t := 0.0
var staple_guard := false
var ink_t := 0.0             # Encre de Chine : marqué
var ink_dmg := 0.0
var ally := false            # Retouche : redessiné dans le camp du joueur
var charmed := false         # Le Paon : allié pour un temps, puis redevient ennemi
var charm_contact := true
var ally_t := 0.0
var ally_cd := 0.0
var blind_t := 0.0           # Encre de seiche : aveuglé
var el_seen := {}            # Cercle chromatique : éléments différents subis
var shroom_cd := 0.0         # Champignon : délai entre deux nuages

# Statuts
var slow_t := 0.0
var chill := 0
var freeze_t := 0.0
var dance_t := 0.0         # Chapeau de fête : il danse sur place
var burn_ticks := 0
var burn_dmg := 0.0
var burn_acc := 0.0
var poison := 0
var poison_t := 0.0
var poison_acc := 0.0
var mark_t := 0.0
var last_tint := Color.WHITE


func setup(a: Arena, type_id: String, is_small := false, is_elite := false) -> void:
	arena = a
	id = type_id
	def = EnemyDB.get_def(id)
	small = is_small
	is_boss = def.has("boss")
	elite = is_elite and Run.elite_art.has(id)
	var art: Dictionary = Run.elite_art[id] if elite else Run.enemy_art[id]
	var mods: Dictionary = art.mods
	var w := Run.eff_wave()
	var d := Run.diff()
	var wave_hp := 1.0 if is_boss else 1.0 + 0.3 * (w - 1)
	var wave_dmg := 1.0 if is_boss else 1.0 + 0.1 * (w - 1)
	max_hp = def.hp * wave_hp * d.hp * mods.hp * (0.45 if small else 1.0) * (3.0 if elite else 1.0)
	hp = max_hp
	dmg = def.dmg * wave_dmg * d.dmg * (1.3 if elite else 1.0)
	speed = def.spd * randf_range(0.9, 1.1) * (1.1 if Run.difficulty >= 2 else 1.0) * float(mods.get("speed", 1.0))
	dmg *= 1.0 + float(mods.get("dmg", 0.0)) / 100.0
	dodge = float(mods.get("dodge", 0.0))
	armor = float(mods.get("armor", 0.0))
	res = mods.get("res", [])
	# Huile et plus : chaque élite a un pouvoir
	if elite and Run.difficulty >= 3:
		power = TRAITS.keys().pick_random()
		match power:
			"shield":
				shield_up = true
			"fast":
				speed *= 1.3
			"summoner":
				summon_cd = 3.0
	if is_boss:
		# Les boss bougent plus vite que leurs stats de base (et frappent un peu moins fort)
		dmg *= BOSS_DMG
		speed *= BOSS_SPEED
		# ... mais restent abordables : -15 % de PV et de dégâts, -25 % pour le 1er boss (vague 5)
		var ease := BOSS_EASE_FIRST if Run.wave <= 5 else BOSS_EASE
		max_hp *= ease
		hp = max_hp
		dmg *= 1.0 if Run.wave <= 5 else ease   # le 1er boss garde des PV réduits, mais frappe à pleine force (+33 %)
		speed *= pow(0.8, Run.amulet_count("colle_forte"))   # Colle forte : boss 20 % plus lents
		if Run.endless and Run.wave > Run.WAVES:
			# Infini : un boss de la vague 5 ou 10 revient avec des PV de boss final
			max_hp *= float(Run.WAVES) / float(Run.boss_home_wave(id))
	# Fin de partie (vagues 9 à 15) : PV ×1,12 et dégâts ×1,06 par vague, boss compris
	max_hp *= Run.late_hp()
	dmg *= Run.late_dmg()
	# Infini : +15 % de PV et de dégâts par vague après la 15e (cumulé)
	var em := Run.endless_mult()
	max_hp *= em
	hp = max_hp
	dmg *= em
	radius = mods.radius * (0.6 if small else 1.0)
	element = mods.element
	color = Pal.color_of(art.a.frac) if art.has("a") else element
	ink_col = Pal.main_color(element) if element > 0 else Pal.SHADES[0][1]
	loot = def.loot * mods.loot * (0.5 if small else 1.0) * (3.0 if elite else 1.0)
	body = Node2D.new()
	add_child(body)
	mat = Gfx.material(art.effect, art.get("outline", false))
	sprite = Gfx.sprite(arena.enemy_tex(id, elite), mat)
	body.add_child(sprite)
	base_scale = 0.6 if small else 1.0
	# Salle thématique : ennemis géants (lents, costauds) ou minuscules (fragiles)
	if not is_boss and arena.theme == "geants":
		base_scale *= 1.5
		radius *= 1.5
		max_hp *= 1.4
		speed *= 0.7
	elif not is_boss and arena.theme == "minus":
		base_scale *= 0.6
		radius *= 0.6
		max_hp *= 0.6
		speed *= 1.1
	if arena.theme == "rapide":
		speed *= 1.3
	hp = max_hp
	body.scale = Vector2(base_scale, base_scale)
	phase = randf() * TAU
	cd = randf_range(0.6, 2.0)
	cd2 = randf_range(3.0, 6.0)
	st_t = 2.0
	mirror_mode = randi_range(1, 2) if small else 0


## La Banane : glisse sur une peau (assommé 2 s, part en patinant dans la direction où il allait).
## chain : la réaction en chaîne (partagée entre tous les ennemis qui glissent à cause de la même peau).
func slip(dir: Vector2, chain = null) -> void:
	if is_boss or dead:
		return
	if chain == null:
		chain = {"n": 0, "struck": false}   # nouvelle peau : nouvelle chaîne
	chain.n = int(chain.n) + 1
	slip_chain = chain
	if chain.n >= 3 and not chain.struck:
		chain.struck = true   # 3 ennemis à terre à cause d'une seule peau : STRIKE !
		arena.banana_strike(position)
	slip_t = 2.0
	slide = dir.normalized() * 260.0
	slide_hits = {}
	arena.float_text(position + Vector2(0, -14), Loc.t("OUPS !"), Color("f2d23a"))
	Sfx.play("swing")


## En glissant, il percute les autres ennemis : dégâts aux deux (une fois par ennemi).
func _slide_hits() -> void:
	if slide.length() < 60.0:
		return
	for o in arena.near(position, radius + 6.0):
		if o == self or o.dead or slide_hits.has(o.get_instance_id()):
			continue
		slide_hits[o.get_instance_id()] = true
		var d: float = (6.0 + Run.wave * 2.0) * (1.0 + Run.stats.dmg / 100.0)
		o.hurt(d, false, slide.normalized() * 120.0)
		hurt(d * 0.5, false, Vector2.ZERO)
		arena.burst(o.position, Color("f2d23a"), 6, 80.0)
		# Effet domino : il glisse à son tour (réaction en chaîne)
		if not o.dead and not o.is_boss and o.slip_t <= 0.0:
			o.slip(slide.normalized().rotated(randf_range(-0.5, 0.5)), slip_chain)


## Pouvoirs des élites (Huile et plus) : [nom affiché, couleur de l'aura]
static var TRAITS := {
	"shield": ["BOUCLIER", Color("5aa8ff")],
	"fast": ["RAPIDE", Color("ffe066")],
	"vampire": ["VAMPIRE", Color("e03a3a")],
	"explosive": ["EXPLOSIVE", Color("ff8a2a")],
	"summoner": ["INVOCATRICE", Color("b06aff")],
}


func power_color() -> Color:
	return TRAITS[power][1] if power != "" else Pal.ACCENT


## Chef-d'œuvre : sous 25 % de PV, le boss entre en fureur (2e colère).
func _frenzy() -> bool:
	return is_boss and Run.difficulty >= 4 and hp < max_hp * 0.25


## Aquarelle et plus : les tireurs visent là où tu VAS (t = temps de vol du tir).
func _lead(t_fly: float) -> Vector2:
	var p := arena.target_pos()
	if Run.difficulty >= 2 and not is_boss:
		p += arena.player_vel() * t_fly
	return p


func _lead_dir(bullet_speed: float) -> Vector2:
	var d0 := arena.target_pos().distance_to(position)
	var d := (_lead(d0 / maxf(1.0, bullet_speed)) - position)
	return d.normalized() if d.length() > 0.01 else Vector2.RIGHT


func _draw() -> void:
	draw_set_transform(Vector2(0, radius * 0.9), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius + 2, Color(0, 0, 0, 0.15))
	if elite:
		# Aura des élites
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_arc(Vector2.ZERO, radius + 5.0 + pulse * 2.0, 0.0, TAU, 28, Color(power_color(), 0.35 + pulse * 0.4), 2.0)
		if shield_up:
			draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 24, Color(0.6, 0.8, 1.0, 0.8), 2.0)
		draw_arc(Vector2.ZERO, radius + 9.0 + pulse * 3.0, 0.0, TAU, 28, Color(ink_col, 0.25), 1.0)
	if ink_t > 0.0:
		# Encre de Chine : taches noires sur l'ennemi marqué
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2(-radius * 0.4, -radius * 0.3), 2.5, Pal.INK)
		draw_circle(Vector2(radius * 0.35, radius * 0.1), 2.0, Pal.INK)
		draw_circle(Vector2(0, radius * 0.5), 1.5, Pal.INK)
	if ally:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, radius + 4.0, 0.0, TAU, 24, Color(Pal.GOOD, 0.8), 2.0)
	if def.get("beh", "") == "hourglass":
		# Zone où tout ralentit
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, SAND_R, Color(0.95, 0.85, 0.5, 0.07))
		draw_arc(Vector2.ZERO, SAND_R, 0.0, TAU, 32, Color(0.9, 0.75, 0.3, 0.35), 1.0)
	if def.get("beh", "") == "loadbar":
		# Sa barre : elle se remplit quand il s'arrête, se vide quand on le frappe
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var bw := radius * 2.2
		draw_rect(Rect2(-bw / 2.0 - 1.0, -radius - 9.0, bw + 2.0, 6.0), Pal.INK)
		draw_rect(Rect2(-bw / 2.0, -radius - 8.0, bw, 4.0), Color("3a3f55"))
		draw_rect(Rect2(-bw / 2.0, -radius - 8.0, bw * charge, 4.0), Pal.BAD if charge > 0.75 else Color("6ad36a"))
	if def.get("beh", "") == "gum":
		# Zone où tes projectiles sont effacés
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, GUM_R, 0.0, TAU, 32, Color(1, 1, 1, 0.25 + 0.1 * sin(t * 4.0)), 1.0)


# ------------------------------------------------------------------ Boucle

func tick(delta: float) -> void:
	if dead:
		return
	if reflet_of != null:
		_reflet_tick(delta)
		return
	if held_by != null or thrown_t > 0.0:
		_thrown_tick(delta)   # dans la main du Curseur, ou lancé : plus de comportement à lui
		return
	weak_t -= delta
	if ally:
		_ally_tick(delta)
		return
	t += delta
	pin_t -= delta
	wet_t -= delta
	gust_t -= delta
	staple_t -= delta
	if ink_t > 0.0:
		ink_t -= delta
		queue_redraw()
	_status(delta)
	if dead:
		return
	var p := arena.player
	var to_p := arena.target_pos(position) - position   # le joueur, le leurre de la Lanterne ou Woinic
	var dist := maxf(0.01, to_p.length())
	var dirp := to_p / dist
	blind_t -= delta
	shroom_cd -= delta
	if not is_boss and (blind_t > 0.0 or p.invis_t > 0.0):
		# Aveuglé (Seiche) ou joueur invisible (Encre invisible) : il erre
		dirp = Vector2.from_angle(phase + t * 0.8)
		dist = 999.0
	var v := Vector2.ZERO
	var mult := 0.55 if slow_t > 0.0 else 1.0
	if arena.rush_t > 0.0 and not is_boss:
		mult *= 1.7   # Sonnerie : tout le monde se précipite
	if wet_t > 0.0:
		mult *= 0.7
	if pin_t > 0.0 and not is_boss:
		mult = 0.0
	if freeze_t > 0.0 or dance_t > 0.0:
		mult = 0.0
	if slip_t > 0.0:
		slip_t -= delta
		mult = 0.0   # assommé par la peau de banane
	hop_h = 0.0

	# Chef-d'œuvre : boss en fureur = attaques plus rapprochées
	var bd := delta
	if _frenzy():
		bd = delta * 1.35
		if not frenzy_on:
			frenzy_on = true
			arena.float_text(position + Vector2(0, -44), Loc.t("FUREUR !"), Pal.BAD)
			arena.shake(8.0)
			Sfx.play("boss")
		flash = maxf(flash, 0.25 if int(t * 10.0) % 2 == 0 else 0.0)
	# Élite invocatrice : appelle des petits
	if power == "summoner":
		summon_cd -= delta
		if summon_cd <= 0.0:
			summon_cd = 5.0
			for k in 2:
				arena.spawn_enemy_now(id, position + Vector2.from_angle(randf() * TAU) * (radius + 12.0), true)
	match def.beh:
		"hop":
			v = _hop(delta * mult, dirp)
		"scribble":
			v = _scribble(delta * mult, dirp)
		"mortar":
			v = _mortar(delta * mult, dist)
		"ruler":
			v = _ruler(delta * mult, dirp, dist)
		"mirror":
			v = _mirror(delta * mult, p, dirp)
		"compass":
			v = _compass(delta * mult, p, dirp)
		"dvd":
			v = _colossus(delta * mult, dirp, dist)
		"mine":
			v = _mine(delta, dirp, dist)
			if dead:
				return
		"b_hatch":
			v = _boss_hatch(bd, dirp, dist)
		"b_critique":
			v = _boss_critique(bd, dirp)
		"b_orbit":
			v = _boss_orbit(bd, dirp, dist)
		"b_toile":
			v = _boss_toile(bd, dirp, dist)
		"pin":
			v = _pin(delta * mult, dirp, dist)
		"chalk":
			v = _chalk(delta * mult, dirp, dist)
		"clip":
			v = _clip(delta * mult, p, dirp)
		"stamp":
			v = _stamp(delta * mult, dirp, dist)
		"crumple":
			v = _crumple(dirp)
		"gum":
			v = _gum(dirp)
		"equation":
			v = _equation(delta * mult, dirp)
		"b_prof":
			v = _boss_prof(bd, dirp, dist)
		"b_copy":
			v = _boss_copy(bd, dirp, dist)
		"b_ink":
			v = _boss_ink(bd, dirp, dist)
		"b_geo":
			v = _boss_geo(bd, dirp, dist)
		"b_virus":
			v = _boss_virus(bd, dirp, dist)
		"b_bug":
			v = _boss_bug(bd, dirp, dist)
		"b_sheet":
			v = _boss_sheet(bd, dirp, dist)
		"b_cursor":
			v = _boss_cursor(bd, dirp, dist)
		"cursor":
			v = _cursor(delta * mult, dirp, dist)
		"corrupt":
			v = _corrupt(delta)
			if dead:
				return
		"trash":
			v = _trash(dirp, dist)
		"bucket":
			v = _bucket(delta * mult, dirp, dist)
		"paste":
			v = _paste(delta * mult, dirp)
		"hourglass":
			v = _hourglass(dirp)
		"lasso":
			v = _lasso(delta * mult, dirp, dist)
		"loadbar":
			v = _loadbar(delta * mult, dirp)

	# Séparation entre ennemis
	if not is_boss and def.beh != "dvd":
		for o in arena.near(position, radius + 4.0):
			if o == self:
				continue
			var push: Vector2 = position - o.position
			var dd := push.length()
			if dd > 0.01 and dd < radius + o.radius:
				v += push / dd * 45.0

	position += (v * mult + knock + slide) * delta
	if slide.length() > 5.0:
		slide = slide.move_toward(Vector2.ZERO, 170.0 * delta)
		_slide_hits()
	knock = knock.move_toward(Vector2.ZERO, 700.0 * delta)
	var hit_wall := Vector2.ZERO
	if position.x <= radius or position.x >= Arena.W - radius:
		hit_wall.x = 1.0
	if position.y <= radius or position.y >= Arena.H - radius:
		hit_wall.y = 1.0
	position.x = clampf(position.x, radius, Arena.W - radius)
	position.y = clampf(position.y, radius, Arena.H - radius)
	if hit_wall != Vector2.ZERO:
		_on_wall(hit_wall)
		if gust_t > 0.0:
			# Éventail : écrasé contre le bord de la page
			gust_t = 0.0
			arena.burst(position, Color.WHITE, 10, 100.0)
			arena.shake(2.5)
			hurt(gust_dmg, true, Vector2.ZERO)

	if absf(v.x) > 1.0 and state != "arm":
		body.scale.x = base_scale * (-1.0 if v.x < 0.0 else 1.0)
	if def.beh == "hop":
		body.rotation = 0.0
		body.position.y = -hop_h
	else:
		body.rotation = sin(t * 9.0 + phase) * 0.08 * mult
		body.position.y = -absf(sin(t * 9.0 + phase)) * 1.5 * mult
	if slip_t > 0.0:
		body.rotation = t * (14.0 if slide.length() > 20.0 else 4.0)   # il tourne en glissant, puis titube
	if dance_t > 0.0:
		body.rotation = sin(t * 12.0 + phase) * 0.45   # C'EST LA FÊTE
		body.position.y = -absf(sin(t * 12.0 + phase)) * 4.0

	if squash > 0.0:
		squash = maxf(0.0, squash - delta * 7.0)
		var sx := -1.0 if body.scale.x < 0.0 else 1.0
		body.scale = Vector2(sx * base_scale * (1.0 + 0.3 * squash), base_scale * (1.0 - 0.22 * squash))
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 7.0)
	mat.set_shader_parameter("flash", flash)
	_update_tint()
	if elite:
		queue_redraw()


func _on_wall(hit: Vector2) -> void:
	match def.beh:
		"dvd":
			# Colosse : s'écrase contre le bord, laisse une grosse trace de gomme et reprend son souffle
			if state == "dash":
				state = "rest"
				st_t = 1.2
				arena.add_hazard(position, radius + 6.0, 3.0, 0.5, 0.0, Pal.PAPER_DARK)
				arena.shake(3.0)
		"ruler":
			if state == "dash":
				state = "rest"
				st_t = 1.0
				arena.shake(3.0)


func _status(delta: float) -> void:
	slow_t -= delta
	freeze_t -= delta
	dance_t -= delta
	mark_t -= delta
	if burn_ticks > 0:
		burn_acc += delta
		if burn_acc >= 0.5:
			burn_acc = 0.0
			burn_ticks -= 1
			hurt(burn_dmg, false, Vector2.ZERO, Pal.FEU)
			# Synergie Feu : la brûlure se propage
			if not dead and arena.syn.has(Pal.FEU) and randf() < 0.4:
				for o in arena.near(position, 34.0):
					if o != self and o.burn_ticks == 0:
						o.burn(burn_dmg)
						break
	if poison > 0:
		poison_t -= delta
		poison_acc += delta
		if poison_acc >= 1.0:
			poison_acc = 0.0
			hurt(poison * (1.0 + Run.wave * 0.25), false, Vector2.ZERO, Pal.POISON)
		if poison_t <= 0.0:
			poison = 0


func _update_tint() -> void:
	var c := Color.WHITE
	if dance_t > 0.0:
		c = Color.from_hsv(fmod(floorf(t * 4.0) * 0.17 + phase, 1.0), 0.45, 1.25)   # couleurs de fête, en rythme
	elif freeze_t > 0.0:
		c = Color(0.6, 0.85, 1.4)
	elif poison > 0:
		c = Color(0.8, 1.25, 0.8)
	elif burn_ticks > 0:
		c = Color(1.35, 0.85, 0.7)
	elif mark_t > 0.0:
		c = Color(1.15, 0.8, 1.35)
	if c != last_tint:
		last_tint = c
		mat.set_shader_parameter("tint", c)


# ------------------------------------------------------------------ Dégâts & statuts

func hurt(amount: float, crit := false, kb := Vector2.ZERO, el := 0) -> void:
	if dead or boss_inv > 0.0:
		return
	if reflet_of != null:
		# Reflet de Rorschach : les coups vont à l'Encrier (PV partagés)
		if is_instance_valid(reflet_of) and not reflet_of.dead:
			flash = 1.0
			reflet_of.hit_at = position
			reflet_of.hurt(amount, crit, Vector2.ZERO, el)
		return
	if shield_up:
		shield_up = false   # élite « bouclier » : le premier coup est bloqué
		flash = 1.0
		arena.float_text(position + Vector2(0, -16), Loc.t("BLOQUÉ"), Color("5aa8ff"))
		queue_redraw()
		return
	if mark_t > 0.0:
		amount *= (1.5 if arena.syn.has(Pal.ARCANE) else 1.25) + 0.15 * Run.amulet_count("grimoire")
	if firefly:
		arena.fam_credit("luciole", minf(hp, amount * 0.15))
		amount *= 1.15   # Luciole
	if def.get("beh", "") == "loadbar" and state != "boom":
		charge = maxf(0.0, charge - amount / max_hp * 1.5)   # Barre de chargement : la frapper la vide
		queue_redraw()
	if state == "jam" or state == "plant":
		amount *= 1.5   # Photocopieuse en bourrage papier, Géomètre planté : vulnérables
	if el > 0:
		amount *= 1.0 - res_to(el) / 100.0   # résistance de son dessin à cet élément
	if wet_t > 0.0 and (el == Pal.FOUDRE or el == Pal.GLACE):
		amount *= 1.25   # Brumisateur : mouillé
	# Agrafeuse : l'ennemi agrafé à celui-ci prend 50 % des dégâts
	if staple_t > 0.0 and is_instance_valid(staple) and not staple.dead and not staple_guard:
		staple.staple_guard = true
		staple.hurt(amount * 0.5, false, Vector2.ZERO, el)
		staple.staple_guard = false
	Meta.count("damage", minf(amount, maxf(0.0, hp)))
	Run.run_damage += minf(amount, maxf(0.0, hp))
	hp -= amount
	flash = 1.0
	squash = 1.0 if not is_boss else 0.4
	if def.beh != "dvd" and not is_boss:
		knock += kb * (0.25 if def.get("heavy", false) else 1.0)
	arena.damage_number(position if hit_at == Vector2.INF else hit_at, amount, crit, el)
	hit_at = Vector2.INF
	arena.hit_fx(self, crit, kb)
	if hp <= 0.0:
		if is_boss and crit:
			Run.boss_crit = true   # succès : boss achevé d'un critique
		arena.kill_enemy(self)


func res_to(el: int) -> float:
	return float(res[el]) if el > 0 and el < res.size() else 0.0


func burn(tick_dmg: float) -> void:
	burn_ticks = 4 * (1 + Run.amulet_count("allumette"))   # Allumette : dure plus longtemps
	burn_dmg = maxf(burn_dmg, tick_dmg)


func chill_hit() -> void:
	slow_t = 1.5
	chill += 1
	if chill >= (2 if Run.amulet_count("givre") > 0 else 3):   # Givre : gèle en 2 coups
		chill = 0
		freeze_t = 0.35 if is_boss else 1.0


func add_poison() -> void:
	poison += 1 + Run.amulet_count("fiole")   # Fiole : 2 cumuls
	poison_t = 4.0
	# Champignon : à 6 cumuls, éclate en nuage toxique qui contamine les voisins
	if poison >= 6 and shroom_cd <= 0.0 and Run.amulet_count("champignon") > 0 and not dead:
		shroom_cd = 2.0
		poison = 2
		arena.toxic_burst(self)


func mark() -> void:
	mark_t = 3.0 * (1 + Run.amulet_count("grimoire"))   # Grimoire : dure plus longtemps


# ------------------------------------------------------------------ Comportements

## Tache : avance par bonds et laisse une flaque qui ralentit à chaque atterrissage.
func _hop(delta: float, dirp: Vector2) -> Vector2:
	if state == "jump":
		st_t -= delta
		var k := clampf(1.0 - st_t / 0.4, 0.0, 1.0)
		hop_h = sin(k * PI) * 9.0
		if st_t <= 0.0:
			state = "rest"
			cd = randf_range(0.5, 1.0)
			arena.add_hazard(position, radius * 0.8 + 5.0, 3.0, 0.55, 0.0, ink_col)
			return Vector2.ZERO
		return dash_dir * speed * 3.4
	cd -= delta
	if cd <= 0.0:
		state = "jump"
		st_t = 0.4
		dash_dir = dirp.rotated(randf_range(-0.35, 0.35))
	return Vector2.ZERO


## Gribouille : traits en zigzag qui laissent de l'encre qui fait mal.
func _scribble(delta: float, dirp: Vector2) -> Vector2:
	st_t -= delta
	if st_t <= 0.0:
		st_t = randf_range(0.35, 0.7)
		dash_dir = dirp.rotated(randf_range(-1.2, 1.2))
	cd -= delta
	if cd <= 0.0:
		cd = 0.12
		arena.add_hazard(position, 4.0, 1.8, 1.0, dmg * 0.5, ink_col)
	return dash_dir * speed


## Crachoir : immobile, tire en cloche là où tu es, puis s'enfonce et ressort ailleurs.
func _mortar(delta: float, dist: float) -> Vector2:
	if state == "burrow":
		st_t -= delta
		mat.set_shader_parameter("alpha", clampf(st_t / 0.5, 0.1, 1.0) if st_t > 0.0 else 1.0)
		if st_t <= 0.0:
			var p := arena.player.position
			position = p + Vector2.from_angle(randf() * TAU) * randf_range(110.0, 200.0)
			position = position.clamp(Vector2(20, 20), Vector2(Arena.W - 20, Arena.H - 20))
			contact = true
			state = "idle"
			cd = 0.8
		return Vector2.ZERO
	cd -= delta
	if cd <= 0.0 and dist < 320.0:
		cd = 2.6
		arena.lob(self, _lead(1.1), 1.1)
	cd2 -= delta
	if cd2 <= 0.0:
		cd2 = randf_range(6.0, 8.0)
		state = "burrow"
		st_t = 0.5
		contact = false
	return Vector2.ZERO


## Bélier : trace une ligne à la règle, puis fonce dessus jusqu'au bord de la page.
func _ruler(delta: float, dirp: Vector2, dist: float) -> Vector2:
	match state:
		"aim":
			st_t -= delta
			flash = 0.5 if int(t * 14.0) % 2 == 0 else 0.0
			if st_t <= 0.0:
				state = "dash"
			return Vector2.ZERO
		"dash":
			return dash_dir * speed * 8.0
		"rest":
			st_t -= delta
			if st_t <= 0.0:
				state = "walk"
				cd = randf_range(1.0, 2.0)
			return Vector2.ZERO
		_:
			cd -= delta
			if cd <= 0.0 and dist < 280.0:
				state = "aim"
				st_t = 0.9
				dash_dir = dirp
				arena.add_ruler(position, _wall_point(position, dirp), 1.0)
			return dirp * speed * 0.6


func _wall_point(from: Vector2, dir: Vector2) -> Vector2:
	var tmax := 99999.0
	if dir.x > 0.001:
		tmax = minf(tmax, (Arena.W - radius - from.x) / dir.x)
	elif dir.x < -0.001:
		tmax = minf(tmax, (radius - from.x) / dir.x)
	if dir.y > 0.001:
		tmax = minf(tmax, (Arena.H - radius - from.y) / dir.y)
	elif dir.y < -0.001:
		tmax = minf(tmax, (radius - from.y) / dir.y)
	return from + dir * tmax


## Scinde : se place en miroir de toi par rapport au centre de la page et tire des reflets.
func _mirror(delta: float, p: Player, dirp: Vector2) -> Vector2:
	var target: Vector2
	match mirror_mode:
		1:
			target = Vector2(Arena.W - p.position.x, p.position.y)   # miroir gauche/droite
		2:
			target = Vector2(p.position.x, Arena.H - p.position.y)   # miroir haut/bas
		_:
			target = Vector2(Arena.W - p.position.x, Arena.H - p.position.y)
	cd -= delta
	if cd <= 0.0:
		cd = randf_range(2.5, 3.5)
		_shoot(_lead_dir(140.0 * 0.8), 0.8)
		Sfx.play("enemy_shot")
	var to := target - position
	if to.length() < 4.0:
		return Vector2.ZERO
	return to.normalized() * speed * 1.4


## Éclaboussure : cercles au compas de plus en plus serrés autour de toi.
func _compass(delta: float, p: Player, dirp: Vector2) -> Vector2:
	cd2 -= delta
	if state != "orbit" or cd2 <= 0.0 or orbit_r <= 42.0:
		state = "orbit"
		center = p.position
		orbit_r = 150.0
		orbit_a = (position - center).angle()
		cd2 = 6.0
	orbit_r = maxf(40.0, orbit_r - 20.0 * delta)
	orbit_a += (speed / orbit_r) * delta * (1.0 if sin(phase) > 0.0 else -1.0)
	var target := center + Vector2.from_angle(orbit_a) * orbit_r
	cd -= delta
	if cd <= 0.0:
		cd = 2.5
		var aim := _lead_dir(140.0)
		for k in [-1, 0, 1]:
			_shoot(aim.rotated(k * 0.3), 1.0)
		Sfx.play("enemy_shot")
	return ((target - position) * 4.0).limit_length(speed * 1.6)


## Colosse : avance lourdement vers toi, s'arrête pour viser (il clignote)... puis FONCE en ligne
## droite là où tu étais. S'arrête au bord de la page ou au bout de sa course.
func _colossus(delta: float, dirp: Vector2, dist: float) -> Vector2:
	st_t -= delta
	match state:
		"aim":
			flash = 0.6 if int(t * 14.0) % 2 == 0 else 0.0
			dash_dir = dirp   # suit le joueur des yeux jusqu'au dernier moment
			if st_t <= 0.0:
				state = "dash"
				st_t = 1.3
				Sfx.play("swing")
			return Vector2.ZERO
		"dash":
			if st_t <= 0.0:
				state = "rest"
				st_t = 1.2
			return dash_dir * speed * 7.0
		"rest":
			if st_t <= 0.0:
				state = "walk"
				st_t = randf_range(0.8, 1.6)
			return dirp * speed * 0.3
	# marche vers toi, puis se prépare à charger
	if st_t <= 0.0 and dist < 320.0:
		state = "aim"
		st_t = 0.7
	return dirp * speed


## Pâté : tache piégée qui fonce sur toi, gonfle quand elle arrive au contact et explose.
func _mine(delta: float, dirp: Vector2, dist: float) -> Vector2:
	if state == "arm":
		st_t -= delta
		flash = 0.7 if int(t * 18.0) % 2 == 0 else 0.0
		var s := base_scale * (1.0 + (0.9 - st_t) * 0.6)
		body.scale = Vector2(s, s)
		if st_t <= 0.0:
			_explode()
		return Vector2.ZERO
	contact = false
	if dist < 52.0:
		state = "arm"
		st_t = 0.9
		Sfx.play("zap")
		return Vector2.ZERO
	if t < 0.5:
		return Vector2.ZERO   # petite pause à l'apparition
	return dirp * speed * minf(1.4, 0.8 + t * 0.15)   # fonce, de plus en plus vite


# ------------------------------------------------------------------ Allié (Retouche)

## Redessiné dans le camp du joueur : fonce sur l'ennemi le plus proche et le frappe au contact.
func _ally_tick(delta: float) -> void:
	t += delta
	ally_t -= delta
	ally_cd -= delta
	if ally_t <= 0.0:
		arena.remove_ally(self)
		return
	var tg: Enemy = arena.nearest(position, 400.0)
	var v := Vector2.ZERO
	if tg:
		var to := tg.position - position
		v = to.normalized() * speed * 1.3
		if to.length() < radius + tg.radius + 2.0 and ally_cd <= 0.0:
			ally_cd = 0.5
			tg.hurt(maxf(4.0, dmg * 2.5), false, to.normalized() * 60.0)
	position += v * delta
	position.x = clampf(position.x, radius, Arena.W - radius)
	position.y = clampf(position.y, radius, Arena.H - radius)
	if absf(v.x) > 1.0:
		body.scale.x = base_scale * (-1.0 if v.x < 0.0 else 1.0)
	body.position.y = -absf(sin(t * 9.0)) * 1.5
	mat.set_shader_parameter("flash", 0.25 + 0.15 * sin(t * 8.0))
	queue_redraw()


# ------------------------------------------------------------------ Le Tableau noir

const GUM_R := 44.0


## Punaise : vise, fonce sur toi, puis reste plantée (piquante) un instant.
func _pin(delta: float, dirp: Vector2, dist: float) -> Vector2:
	match state:
		"aim":
			st_t -= delta
			flash = 0.4 if int(t * 16.0) % 2 == 0 else 0.0
			if st_t <= 0.0:
				state = "dash"
				st_t = 0.45
			return Vector2.ZERO
		"dash":
			st_t -= delta
			if st_t <= 0.0:
				state = "planted"
				st_t = 1.3
			return dash_dir * speed * 3.2
		"planted":
			st_t -= delta
			body.rotation = 0.0
			if st_t <= 0.0:
				state = "walk"
				cd = randf_range(0.6, 1.2)
			return Vector2.ZERO
	cd -= delta
	if cd <= 0.0 and dist < 210.0:
		state = "aim"
		st_t = 0.35
		dash_dir = dirp
	return dirp * speed * 0.45


## Craie : écrit une ligne de projectiles qui restent suspendus, puis partent tous vers toi.
func _chalk(delta: float, dirp: Vector2, dist: float) -> Vector2:
	cd -= delta
	if cd <= 0.0 and dist < 300.0:
		cd = 3.4
		var side := dirp.orthogonal()
		for k in 5:
			arena.spawn_enemy_bullet(self, position + dirp * 14.0 + side * (k - 2) * 10.0, Vector2.ZERO, 0.6 + k * 0.15)
		Sfx.play("enemy_shot")
	var want := 1.0 if dist > 170.0 else -0.8
	return (dirp * want + dirp.orthogonal() * 0.5).normalized() * speed


## Trombones : deux par deux, reliés par un fil qui coupe ; ils tournent autour d'un point
## (ta position d'il y a un instant) pour te trancher avec le fil.
func _clip(delta: float, p: Player, dirp: Vector2) -> Vector2:
	if partner == null:
		for o in arena.near(position, 90.0):
			if o != self and o.def.beh == "clip" and o.partner == null and not o.dead:
				partner = o
				o.partner = self
				o.orbit_a = orbit_a + PI
				break
	if partner != null and (not is_instance_valid(partner) or partner.dead):
		partner = null
	cd2 -= delta
	if state != "orbit" or cd2 <= 0.0:
		state = "orbit"
		center = p.position
		orbit_r = 110.0
		cd2 = 4.0
		if partner != null and get_instance_id() < partner.get_instance_id():
			orbit_a = (position - center).angle()
			partner.center = center
			partner.orbit_r = orbit_r
			partner.orbit_a = orbit_a + PI
			partner.cd2 = cd2
			partner.state = "orbit"
	orbit_r = maxf(50.0, orbit_r - 12.0 * delta)
	orbit_a += (speed / orbit_r) * delta
	# Le fil blesse le joueur (vérifié par un seul des deux)
	if partner != null and get_instance_id() < partner.get_instance_id():
		var q := Geometry2D.get_closest_point_to_segment(p.position, position, partner.position)
		if q.distance_to(p.position) < p.radius + 2.0:
			p.take_hit(dmg, element, null)
	var target := center + Vector2.from_angle(orbit_a) * orbit_r
	if partner == null:
		return dirp * speed
	return ((target - position) * 3.0).limit_length(speed * 1.8)


## Tampon encreur : saute très haut vers toi et s'écrase sur un carré annoncé au sol.
func _stamp(delta: float, dirp: Vector2, dist: float) -> Vector2:
	match state:
		"air":
			st_t -= delta
			var k := clampf(1.0 - st_t / 0.8, 0.0, 1.0)
			hop_h = sin(k * PI) * 28.0
			contact = false
			if st_t <= 0.0:
				state = "land"
				st_t = 0.6
				contact = true
				return Vector2.ZERO
			return (center - position) / maxf(st_t, 0.05)
		"land":
			st_t -= delta
			if st_t <= 0.0:
				state = "walk"
				cd = randf_range(1.2, 2.2)
			return Vector2.ZERO
	cd -= delta
	if cd <= 0.0 and dist < 230.0:
		state = "air"
		st_t = 0.8
		center = arena.player.position
		arena.add_square(center, 24.0, 0.8, dmg, ink_col)
	return dirp * speed * 0.5


## Brouillon (tank) : se froisse à 66 % et 33 % de ses PV : plus petit, plus rapide, et crache.
func _crumple(dirp: Vector2) -> Vector2:
	var stage := 0 if hp > max_hp * 0.66 else (1 if hp > max_hp * 0.33 else 2)
	if stage > crumple:
		crumple = stage
		base_scale *= 0.8
		body.scale = Vector2(base_scale, base_scale)
		radius *= 0.85
		_ring(8, randf() * TAU, 0.8)
		arena.float_text(position + Vector2(0, -16), Loc.t("FROISSÉ !"), Pal.TEXT)
		arena.burst(position, Color.WHITE, 10, 90.0)
	return dirp * speed * (1.0 + 0.5 * crumple)


## Gomme mie de pain (tank) : efface les projectiles du joueur autour d'elle.
func _gum(dirp: Vector2) -> Vector2:
	for b in arena.bullets:
		if b.hostile or b.lob_r > 0.0 or b.burst_r > 0.0 or b.life <= 0.0:
			continue
		if b.position.distance_squared_to(position) < GUM_R * GUM_R:
			b.life = -1.0
			arena.burst(b.position, Color(1, 1, 1, 0.8), 2, 30.0)
	return dirp * speed


## Équation (tank) : avance lentement et « calcule » : chaque résultat est une punaise.
func _equation(delta: float, dirp: Vector2) -> Vector2:
	cd -= delta
	if cd <= 0.0:
		cd = 5.0
		if Run.enemy_art.has("punaise") and arena.enemies.size() < Arena.MAX_ENEMIES - 10:
			_summon("punaise", 2)
			arena.float_text(position + Vector2(0, -22), "= ?", Pal.TEXT)
	return dirp * speed


# ------------------------------------------------------------------ L'Écran (carte 3)

## Pointeur (id « curseur ») : fonce en ligne droite, s'arrête net, repart. À l'arrêt, il « clique » parfois sur toi.
func _cursor(delta: float, dirp: Vector2, dist: float) -> Vector2:
	st_t -= delta
	if state == "dash":
		if st_t <= 0.0:
			state = "walk"   # arrêt net
			st_t = randf_range(0.5, 0.8)
			cd2 -= 1.0
			if cd2 <= 0.0 and dist < 170.0:
				cd2 = 3.0
				arena.add_square(arena.player.position, 9.0, 0.55, dmg, ink_col)   # clic !
				arena.float_text(position + Vector2(0, -14), Loc.t("CLIC"), Pal.DIM)
		return dash_dir * speed * 2.2
	if st_t <= 0.0:
		state = "dash"
		st_t = 0.4
		dash_dir = dirp
	return Vector2.ZERO


## Fichier corrompu : immobile et inoffensif, mais au bout de CORRUPT_T secondes il s'ouvre et
## libère 3 à 5 ennemis de la vague (il clignote de plus en plus vite avant).
const CORRUPT_T := 6.0


func _corrupt(delta: float) -> Vector2:
	contact = false
	charge += delta / CORRUPT_T
	flash = 0.5 * charge if int(t * (4.0 + 14.0 * charge)) % 2 == 0 else 0.0
	if charge >= 1.0:
		var pool := EnemyDB.pool(Run.wave).filter(func(i): return i != id and Run.enemy_art.has(i) and not EnemyDB.TYPES[i].get("heavy", false))
		if not pool.is_empty() and arena.enemies.size() < Arena.MAX_ENEMIES - 8:
			for k in randi_range(3, 5):
				arena.spawn_enemy_now(pool.pick_random(), position + Vector2.from_angle(randf() * TAU) * (radius + 10.0), false)
		arena.float_text(position + Vector2(0, -16), Loc.t("FICHIER OUVERT !"), Pal.BAD)
		arena.burst(position, ink_col, 14, 110.0)
		loot = 0.0   # (ouvert : il ne rapporte rien)
		arena.kill_enemy(self)
	return Vector2.ZERO


## Corbeille : l'or ne reste jamais au sol (chaque goutte file vers le joueur), alors elle rôde tout
## près de lui et AVALE les gouttes qui passent à sa portée. À sa mort, elle recrache tout
## (Arena.kill_enemy).
const TRASH_R := 40.0


func _trash(dirp: Vector2, dist: float) -> Vector2:
	for pk in arena.pickups.duplicate():
		if pk.heal > 0.0 or pk.vac >= 0.0:
			continue   # (ni les bulles de soin, ni l'aspiration de fin de vague)
		if pk.position.distance_to(position) < TRASH_R:
			belly_v += pk.value
			belly_xp += pk.xp
			arena.pickups.erase(pk)
			pk.queue_free()
			squash = 1.0
			arena.burst(position, Pal.ACCENT, 3, 40.0)
	# elle se tient sur le chemin des gouttes : collée au joueur, en tournant autour
	var want := 1.0 if dist > 46.0 else -0.4
	return (dirp * want + dirp.orthogonal() * 0.7).normalized() * speed


## Pot de peinture : garde ses distances et renverse sa peinture sur toi (zone annoncée, puis
## une flaque qui brûle et ralentit 3 s).
func _bucket(delta: float, dirp: Vector2, dist: float) -> Vector2:
	cd -= delta
	if cd <= 0.0 and dist < 260.0:
		cd = 3.6
		arena.lob(self, arena.player.position, 0.9, 30.0)
		arena.lobs[-1]["burn"] = dmg * 0.35
		Sfx.play("enemy_shot")
	var want := 1.0 if dist > 150.0 else -0.7
	return (dirp * want + dirp.orthogonal() * 0.4).normalized() * speed


## Copier-coller : court vers l'ennemi le plus proche et en fait une copie en le touchant.
func _paste(delta: float, dirp: Vector2) -> Vector2:
	cd -= delta
	if cd > 0.0:
		return dirp * speed * 0.6
	var best: Enemy = null
	var bd := 400.0
	for o in arena.enemies:
		if o == self or o.dead or o.is_boss or o.ally or o.def.get("heavy", false) or o.def.beh in ["paste", "corrupt"]:
			continue
		var d := o.position.distance_to(position)
		if d < bd:
			bd = d
			best = o
	if best == null:
		return dirp * speed * 0.7
	if bd < radius + best.radius + 4.0 and arena.enemies.size() < Arena.MAX_ENEMIES - 6:
		cd = 4.5
		arena.spawn_enemy_now(best.id, best.position + Vector2(12, 0).rotated(randf() * TAU), best.small, false)
		arena.float_text(position + Vector2(0, -16), Loc.t("COLLÉ !"), Pal.TEXT)
		flash = 0.8
	return (best.position - position).normalized() * speed


## Lag (tank, id « sablier_e ») : tout ralentit autour de lui, le joueur comme les autres ennemis.
const SAND_R := 72.0


func _hourglass(dirp: Vector2) -> Vector2:
	if arena.player.position.distance_to(position) < SAND_R:
		arena.player.sand_t = 0.15
	for o in arena.near(position, SAND_R):
		if o != self and not o.is_boss:
			o.slow_t = maxf(o.slow_t, 0.15)
	return dirp * speed


## Lasso : trace un contour autour de toi ; s'il se referme sur toi, tu es coincé 2 s.
func _lasso(delta: float, dirp: Vector2, dist: float) -> Vector2:
	cd -= delta
	if cd <= 0.0 and dist < 190.0 and arena.player.lasso_safe_t <= 0.0:   # (pas tant que tu es pris ou à l'abri)
		cd = 5.5
		arena.add_lasso(arena.player.position, 34.0, 1.2, 2.0)
		Sfx.play("swing")
	var want := 1.0 if dist > 130.0 else -0.6
	return (dirp * want + dirp.orthogonal() * 0.6).normalized() * speed


## Barre de chargement (tank) : avance par à-coups, se charge quand elle s'arrête. À 100 % : grosse
## explosion annoncée autour d'elle. La frapper vide sa barre (voir hurt).
func _loadbar(delta: float, dirp: Vector2) -> Vector2:
	if state == "boom":
		st_t -= delta
		flash = 0.5 if int(t * 14.0) % 2 == 0 else 0.0
		if st_t <= 0.0:
			state = "walk"
			charge = 0.0
			st_t = 0.5
			queue_redraw()
		return Vector2.ZERO
	st_t -= delta
	if st_t <= 0.0:
		pattern = 1 - pattern   # 1 : un à-coup vers toi ; 0 : à l'arrêt, elle charge
		st_t = 0.35 if pattern == 1 else 0.7
	if pattern == 1:
		return dirp * speed * 2.0
	charge = minf(1.0, charge + delta / 4.5)
	queue_redraw()
	if charge >= 1.0:
		state = "boom"
		st_t = 0.9
		arena.lob(self, position, 0.9, 84.0, position)
		arena.float_text(position + Vector2(0, -26), "100 %", Pal.BAD)
	return Vector2.ZERO


## Le Virus (L'Écran, vague 5) : il ouvre des fenêtres de pub par-dessus le jeu (voir VirusPopups).
## Une toutes les 3,5 s (2,6 s sous 50 % de PV), 12 au plus à l'écran, dont 2 énigmes au plus. Ses tirs :
## - Courrier indésirable : une RAFALE de 4 tirs à la suite, droit sur toi (5 sous 50 % de PV) ;
## - Les fenêtres tirent : chaque fenêtre ouverte t'envoie un tir toutes les 2,4 s. Moins tu en
##   fermes, plus ça pleut : c'est la raison de les fermer vite.
func _boss_virus(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var rage := _enraged()
	cd -= delta
	cd2 -= delta
	var pops := arena.hud.ensure_popups()
	if cd <= 0.0:
		cd = 2.6 if rage else 3.5
		pops.spawn()   # (une seule à la fois : on a le temps de la fermer avant la suivante)
		flash = 0.6
	# Courrier indésirable : une rafale, un tir toutes les 0,12 s
	if cd2 <= 0.0:
		cd2 = 1.9 if rage else 2.4
		repeat = 5 if rage else 4
		cd3 = 0.0
	if repeat > 0:
		cd3 -= delta
		if cd3 <= 0.0:
			cd3 = 0.12
			repeat -= 1
			_shoot(dirp.rotated(randf_range(-0.07, 0.07)), 1.2)
			Sfx.play("enemy_shot")
	# Les fenêtres tirent (depuis l'endroit de l'arène qu'elles recouvrent)
	spiral_a -= delta
	if spiral_a <= 0.0:
		spiral_a = 2.0 if rage else 2.4
		var to_world := arena.get_viewport().get_canvas_transform().affine_inverse()
		for w in pops.wins:
			var from: Vector2 = to_world * ((w as Control).position + (w as Control).size / 2.0)
			var d := arena.player.position - from
			if d.length() > 24.0:
				arena.spawn_enemy_bullet(self, from, d.normalized() * 120.0)
	return dirp * speed * (1.0 if dist > 150.0 else -0.6)


## Le Bug (L'Écran, vague 10) : il se TÉLÉPORTE (une image fantôme reste derrière, l'endroit où il
## réapparaît est marqué) et lance les GROS bugs du jeu (ScreenBugs) : commandes inversées, écran à
## l'envers, retour en arrière, barre de vie folle, annoncés 1 s avant. Ses tirs :
## - Double tir : à chaque téléportation, son fantôme tire une croix « + » et lui une croix « × » ;
## - Artefacts : 3 tirs (4 sous 50 % de PV) apparaissent figés autour de toi, puis te foncent dessus.
func _boss_bug(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var rage := _enraged()
	cd -= delta
	cd2 -= delta
	if state == "tp":
		st_t -= delta
		flash = 0.6 if int(t * 18.0) % 2 == 0 else 0.0
		if st_t <= 0.0:
			# image fantôme à l'ancienne place
			var g := Sprite2D.new()
			g.texture = arena.enemy_tex(id, elite)
			g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			g.position = position
			g.modulate = Color(0.6, 1.0, 0.8, 0.6)
			arena.world.add_child(g)
			var tw := g.create_tween()
			tw.tween_property(g, "modulate:a", 0.0, 0.8)
			tw.tween_callback(g.queue_free)
			# Double tir : l'image fantôme tire une croix « + » de là où il était, lui une croix « × »
			# de là où il arrive (3 tirs à la suite par branche, 4 sous 50 % de PV)
			_cross(position, 0.0, 4 if rage else 3)
			position = tp_pos
			arena.burst(position, ink_col, 14, 120.0)
			state = "walk"
			_cross(position, PI / 4.0, 4 if rage else 3)
			Sfx.play("zap")
		return Vector2.ZERO
	if cd <= 0.0:
		cd = 2.8 if rage else 4.0
		state = "tp"
		st_t = 0.55
		var p := arena.player.position
		tp_pos = (p + Vector2.from_angle(randf() * TAU) * randf_range(110.0, 170.0)).clamp(Vector2(30, 30), Vector2(Arena.W - 30, Arena.H - 30))
		arena.telegraphs_fx.append({"pos": tp_pos, "t": 0.55})
	# Artefacts : des tirs apparaissent figés tout autour de toi, puis te foncent dessus
	cd3 -= delta
	if cd3 <= 0.0:
		cd3 = 2.4 if rage else 3.2
		var n_art := 4 if rage else 3
		var a0 := randf() * TAU
		for k in n_art:
			var at := (arena.player.position + Vector2.from_angle(a0 + TAU * k / n_art) * 84.0).clamp(Vector2(10, 10), Vector2(Arena.W - 10, Arena.H - 10))
			arena.spawn_enemy_bullet(self, at, Vector2.ZERO, 0.7 + 0.12 * k)
			arena.burst(at, ink_col, 4, 50.0)
		Sfx.play("zap")
	if cd2 <= 0.0:
		cd2 = 5.0 if rage else 7.0
		var ch := arena.ensure_bugs().heavy_choices()
		if not ch.is_empty():
			arena.bugs.launch(ch.pick_random(), ScreenBugs.WARN_HEAVY)
	return dirp.orthogonal() * speed * 0.9 + dirp * speed * (0.5 if dist > 150.0 else -0.5)


## Le Bug : une croix de tirs à 4 branches depuis `from` (n tirs par branche, de plus en plus rapides).
func _cross(from: Vector2, angle: float, n: int) -> void:
	for b in 4:
		var d := Vector2.from_angle(angle + b * PI / 2.0)
		for k in n:
			arena.spawn_enemy_bullet(self, from, d * 140.0 * (0.65 + 0.22 * k))


## Le Tableur (L'Écran, vague 10, parfois à la place du Bug) : l'arène est une grille de cases de 80 px.
## Il enchaîne 3 attaques dans un ordre mélangé :
## - Lignes et colonnes : celle où tu es (plus 1, ou 2 sous 50 % de PV) s'allume 1,1 s puis explose.
## - Formule : une formule s'applique à tes stats 5 s (affichée dans la barre de formule du HUD).
## - Somme : il fusionne les ennemis d'une colonne en un seul gros (ou en appelle s'il n'y en a pas).
const SHEET_CELL := 80.0
static var SHEET_FORMULAS := [["=DÉGÂTS/2", 0.5, 1.0], ["=VITESSE/2", 1.0, 0.6], ["=VITESSE*1,5", 1.0, 1.5], ["=DÉGÂTS*1,5", 1.5, 1.0], ["=DÉGÂTS/2", 0.5, 1.0]]


func _boss_sheet(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var rage := _enraged()
	st_t -= delta
	if st_t <= 0.0:
		st_t = 2.4 if rage else 3.2
		if atk_bag.is_empty():
			atk_bag = ["bands", "formula", "sum", "bands"]
			atk_bag.shuffle()
		flash = 0.8
		match String(atk_bag.pop_front()):
			"bands":
				var p := arena.player.position
				var lines := []   # [vertical ?, indice]
				lines.append([randf() < 0.5, 0])
				lines[0][1] = int(p.x / SHEET_CELL) if lines[0][0] else int(p.y / SHEET_CELL)
				for k in (2 if rage else 1):
					var vert := randf() < 0.5
					lines.append([vert, randi() % int((Arena.W if vert else Arena.H) / SHEET_CELL)])
				for ln in lines:
					var i := int(ln[1])
					var rect := Rect2(i * SHEET_CELL, 0, SHEET_CELL, Arena.H) if ln[0] else Rect2(0, i * SHEET_CELL, Arena.W, SHEET_CELL)
					arena.add_band(rect, 1.1, dmg * 1.1, ink_col)
				Sfx.play("zap")
			"formula":
				var f: Array = SHEET_FORMULAS.pick_random()
				arena.formula = {"text": f[0], "t": 5.0, "dmg": f[1], "speed": f[2]}
				arena.float_text(position + Vector2(0, -34), String(f[0]), Pal.ACCENT)
			"sum":
				_sheet_sum()
	return dirp * speed * (1.0 if dist > 140.0 else -0.4)


func _sheet_sum() -> void:
	var cols := {}
	for o in arena.enemies:
		if o == self or o.dead or o.is_boss or o.ally:
			continue
		var c := int(o.position.x / SHEET_CELL)
		if not cols.has(c):
			cols[c] = []
		(cols[c] as Array).append(o)
	var best := []
	for c in cols:
		if (cols[c] as Array).size() > best.size():
			best = cols[c]
	if best.size() < 2:
		# rien à additionner : il remplit une colonne
		var pool := EnemyDB.pool(Run.wave).filter(func(i): return Run.enemy_art.has(i) and not EnemyDB.TYPES[i].get("heavy", false) and EnemyDB.TYPES[i].beh != "corrupt")
		if not pool.is_empty():
			_summon(pool.pick_random(), 3)
		arena.float_text(position + Vector2(0, -34), Loc.t("=ALEA()"), Pal.ACCENT)
		return
	var sum_hp := 0.0
	var sum_loot := 0.0
	var at := Vector2.ZERO
	var group: Array = best.slice(0, 6)
	var first_id: String = (group[0] as Enemy).id
	for o in group:
		sum_hp += o.hp
		sum_loot += o.loot
		at += o.position
		o.dead = true
		arena.enemies.erase(o)
		o.queue_free()
	at /= group.size()
	var big := arena.spawn_enemy_now(first_id, at, false)
	if big:
		big.max_hp = sum_hp
		big.hp = sum_hp
		big.loot = sum_loot
		big.base_scale *= 1.6
		big.radius *= 1.5
		big.body.scale = Vector2(big.base_scale, big.base_scale)
		arena.burst(at, ink_col, 16, 120.0)
	arena.float_text(position + Vector2(0, -34), Loc.t("=SOMME(%d)") % group.size(), Pal.ACCENT)


## Un ennemi que Le Curseur a attrapé : il est soulevé dans sa main, puis LANCÉ sur le joueur
## comme un projectile. Il explose à l'impact (ou au bout de sa course) et ne rapporte rien.
func _thrown_tick(delta: float) -> void:
	t += delta
	contact = false
	body.rotation += 16.0 * delta
	if held_by != null:
		if not is_instance_valid(held_by) or held_by.dead:
			held_by = null
			contact = true
			return
		position = position.lerp(held_by.position + Vector2(0, -held_by.radius - radius), minf(1.0, 10.0 * delta))
		return
	thrown_t -= delta
	position += thrown_v * delta
	var p := arena.player
	var hit := position.distance_to(p.position) < radius + p.radius + 2.0
	if hit:
		p.take_hit(thrown_dmg, element, null)
	if hit or thrown_t <= 0.0 or position.x < 4.0 or position.y < 4.0 or position.x > Arena.W - 4.0 or position.y > Arena.H - 4.0:
		arena.explosion(position, 30.0, Color(ink_col, 0.8))
		arena.burst(position, ink_col, 12, 110.0)
		loot = 0.0
		thrown_t = 0.0
		arena.kill_enemy(self)


## Le Curseur, boss final de L'Écran : une main géante. Il ne tire pas, il MANIPULE.
## 3 PHASES (60 % et 25 % de PV) ; à chaque changement le jeu PLANTE (faux écran d'erreur).
## 1. Il attrape : il soulève un ennemi et te le LANCE dessus ; il te pourchasse (son ombre te suit,
##    se fige, s'abat) et, s'il t'attrape, te traîne vers la CORBEILLE : secoue les touches de
##    déplacement pour te libérer avant d'y être jeté.
## 2. Il sélectionne : un rectangle de sélection se trace, puis SUPPR : tout ce qui est dedans est
##    supprimé (ses ennemis aussi) ; il te REDIMENSIONNE (énorme et lent, ou minuscule et faible).
## 3. Il s'en prend à la fenêtre : il la RÉDUIT (faux bureau, à rouvrir d'un clic), il la TRAÎNE
##    (toute l'image glisse), il tente un ALT+F4 (frappe-le assez fort pour l'arrêter). Et quand
##    il semble vaincu : fausse victoire... il revient.
const ALTF4_SEC := 3.0
const HAND_REACH := 30.0     # rayon dans lequel sa main attrape le joueur
const STRUGGLE_NEED := 6     # secousses pour se libérer


func _boss_cursor(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var p := arena.player
	if boss_inv > 0.0:
		boss_inv -= delta   # intouchable seulement le temps d'un plantage
	var want := 1 if hp > max_hp * 0.6 else (2 if hp > max_hp * 0.25 else 3)
	if want > toile_phase:
		toile_phase = want
		_cursor_release()
		var long := want == 3
		arena.hud.crash(2.4 if long else 1.3, long)
		arena.hitstop(2.4 if long else 1.3)
		boss_inv = 1.0
		state = "walk"
		st_t = 1.5
		atk_bag.clear()
		Sfx.play("boss")
		return Vector2.ZERO
	# Fausse victoire : presque mort, le jeu annonce la victoire... puis il revient
	if not fake_done and hp < max_hp * 0.05:
		fake_done = true
		_cursor_release()
		hp = max_hp * 0.14
		boss_inv = 1.0
		arena.hud.screen("win", 3.0)
		arena.hitstop(3.0)
		Sfx.play("win")
		state = "walk"
		st_t = 1.0
		return Vector2.ZERO
	st_t -= delta
	match state:
		"jam":
			# sonné (Alt+F4 raté, ou le joueur s'est libéré) : immobile, il prend +50 %
			flash = 0.3 if int(t * 10.0) % 2 == 0 else 0.0
			if st_t <= 0.0:
				state = "walk"
				st_t = 1.0
			return Vector2.ZERO
		"lift":
			# il tient un ennemi au-dessus de lui, puis le lance là où tu es
			if st_t <= 0.0:
				if grab_e and is_instance_valid(grab_e) and not grab_e.dead:
					grab_e.held_by = null
					grab_e.thrown_t = 1.6
					grab_e.thrown_v = (p.position - grab_e.position).normalized() * 330.0
					grab_e.thrown_dmg = dmg * 0.9
					Sfx.play("swing")
				grab_e = null
				state = "walk"
				st_t = 0.5 if toile_phase == 3 else 0.9
			return Vector2.ZERO
		"hunt":
			# sa main te suit (un peu moins vite que toi), puis se fige
			contact = false
			if st_t <= 0.0:
				state = "lock"
				st_t = 0.45
				return Vector2.ZERO
			return (p.position - position).limit_length(1.0) * minf(position.distance_to(p.position) * 5.0, 190.0)
		"lock":
			flash = 0.6 if int(t * 16.0) % 2 == 0 else 0.0
			if st_t <= 0.0:
				arena.shake(5.0)
				arena.burst(position, ink_col, 12, 120.0)
				contact = true
				if position.distance_to(p.position) < HAND_REACH:
					state = "carry"
					grabbed = true
					struggle = 0
					shake_dir = Vector2.ZERO
					arena.float_text(p.position + Vector2(0, -30), Loc.t("ATTRAPÉ ! SECOUE LES TOUCHES !"), Pal.BAD)
				else:
					state = "walk"
					st_t = 1.2
			return Vector2.ZERO
		"carry":
			# il te traîne vers la Corbeille ; chaque changement de direction de tes touches est une secousse
			var d := p.input_dir()
			if d.length() > 0.3:
				if shake_dir != Vector2.ZERO and d.dot(shake_dir) < 0.0:
					struggle += 1
					arena.burst(p.position, Color.WHITE, 3, 60.0)
				shake_dir = d
			p.root_t = 0.1
			p.position = position + Vector2(0, radius * 0.5)
			if struggle >= STRUGGLE_NEED:
				_cursor_release()
				state = "jam"
				st_t = 1.6
				arena.float_text(p.position + Vector2(0, -30), Loc.t("LIBÉRÉ !"), Pal.GOOD)
				return Vector2.ZERO
			if position.distance_to(Arena.TRASH_POS) < 14.0:
				_cursor_release()
				p.inv = 0.0   # (la Corbeille fait toujours mal, même juste après un autre coup)
				p.take_hit(dmg * 2.0, 0, null)
				arena.explosion(Arena.TRASH_POS, 36.0, Color(0.6, 0.65, 0.75, 0.9))
				arena.float_text(Arena.TRASH_POS + Vector2(0, -30), Loc.t("À LA CORBEILLE !"), Pal.BAD)
				state = "walk"
				st_t = 1.6
				return Vector2.ZERO
			return (Arena.TRASH_POS - position).normalized() * 105.0
		"altf4":
			flash = 0.4 if int(t * 12.0) % 2 == 0 else 0.0
			if cast_hp - hp >= max_hp * 0.035:
				state = "jam"
				st_t = 1.8
				arena.float_text(position + Vector2(0, -40), Loc.t("ALT+F4 ANNULÉ !"), Pal.GOOD)
			elif st_t <= 0.0:
				arena.hud.screen("closed", 0.9)
				arena.hitstop(0.9)
				p.inv = 0.0   # (pareil : un Alt+F4 réussi ne se rate pas)
				p.take_hit(dmg * 2.2, 0, null)
				state = "walk"
				st_t = 1.6
			return Vector2.ZERO
	if st_t <= 0.0:
		st_t = [2.3, 2.0, 1.7][toile_phase - 1]
		if atk_bag.is_empty():
			atk_bag = [["throw", "throw", "hunt"], ["select", "resize", "throw", "select", "hunt"],
				["minimize", "altf4", "dragwin", "select", "throw", "hunt", "resize"]][toile_phase - 1].duplicate()
			atk_bag.shuffle()
		flash = 0.8
		match String(atk_bag.pop_front()):
			"throw":
				# l'ennemi le plus proche de lui ; s'il n'y en a pas, il en fait venir un
				var best: Enemy = null
				for o in arena.enemies:
					if o == self or o.dead or o.is_boss or o.ally or o.held_by != null or o.thrown_t > 0.0:
						continue
					if best == null or o.position.distance_to(position) < best.position.distance_to(position):
						best = o
				if best == null:
					var pool := EnemyDB.pool(Run.wave).filter(func(i): return Run.enemy_art.has(i) and not EnemyDB.TYPES[i].get("heavy", false))
					if not pool.is_empty():
						best = arena.spawn_enemy_now(pool.pick_random(), position + Vector2(0, -20), false)
				if best:
					best.held_by = self
					grab_e = best
					state = "lift"
					st_t = 0.6
					arena.add_ruler(position, p.position, 0.6)
			"hunt":
				state = "hunt"
				st_t = 1.5 if toile_phase == 3 else 1.9
			"select":
				var sz := Vector2(210, 150)
				var c := p.position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
				arena.add_band(Rect2(c - sz / 2.0, sz), 1.1, dmg * 1.3, Color("3a86ff"))
				arena.bands[-1]["sel"] = true
			"resize":
				var big := randf() < 0.5
				p.resize(1.8 if big else 0.55, 6.0)
				arena.float_text(p.position + Vector2(0, -34), Loc.t("REDIMENSIONNÉ : %s !") % (Loc.t("ÉNORME") if big else Loc.t("MINUSCULE")), Pal.BAD)
				arena.burst(p.position, Color("3a86ff"), 10, 80.0)
			"minimize":
				arena.hud.minimize(6.0)
				Sfx.play("zap")
			"dragwin":
				arena.win_drag_t = Arena.WIN_DRAG_SEC
				arena.hud.announce(Loc.t("IL TRAÎNE LA FENÊTRE !"), Pal.BAD)
			"altf4":
				state = "altf4"
				st_t = ALTF4_SEC
				cast_hp = hp
	return dirp * speed * (1.0 if dist > 150.0 else -0.4) + dirp.orthogonal() * speed * 0.6


## Le Curseur lâche ce qu'il tient (le joueur, un ennemi).
func _cursor_release() -> void:
	grabbed = false
	contact = true
	if grab_e and is_instance_valid(grab_e):
		grab_e.held_by = null
		grab_e.contact = true
	grab_e = null


## Le Professeur : interros surprises (colonnes, une seule bonne réponse), salves de craie, punaises.
func _boss_prof(delta: float, dirp: Vector2, dist: float) -> Vector2:
	cd -= delta
	cd2 -= delta
	cd3 -= delta
	if cd2 <= 0.0:
		cd2 = 7.0 if _enraged() else 9.5
		arena.quiz(4 if _enraged() else 3, dmg * 1.3)
	if cd <= 0.0:
		cd = 1.6 if _enraged() else 2.3
		for k in range(-2, 3):   # éventail de 5 craies (le 1er boss reste abordable)
			_shoot(dirp.rotated(k * 0.18), 1.0)
		Sfx.play("enemy_shot")
	if cd3 <= 0.0:
		cd3 = 11.0
		if Run.enemy_art.has("punaise"):
			_summon("punaise", 3)
	return dirp * speed * (1.0 if dist > 150.0 else -0.6)


## La Photocopieuse : chaque salve a sa COPIE qui arrive du côté opposé ; scanner qui balaie
## l'écran ; en rage, bourrage papier (immobile et vulnérable) puis anneau de feuilles.
func _boss_copy(delta: float, dirp: Vector2, dist: float) -> Vector2:
	if state == "jam":
		st_t -= delta
		flash = 0.35 if int(t * 10.0) % 2 == 0 else 0.0
		if st_t <= 0.0:
			state = "walk"
			_ring(24, randf() * TAU, 0.8)
		return Vector2.ZERO
	cd -= delta
	cd2 -= delta
	cd3 -= delta
	if cd <= 0.0:
		cd = 2.2 if _enraged() else 3.0
		for k in range(-4, 5):
			_shoot(dirp.rotated(k * 0.14), 0.9)
		var mp := Vector2(Arena.W - position.x, Arena.H - position.y)
		arena.ghost_volley(self, mp, 9, 0.14, 0.8)
		Sfx.play("enemy_shot")
	if cd2 <= 0.0:
		cd2 = 8.0 if _enraged() else 11.0
		arena.scan(dmg, 1 if _enraged() else 2)
	if cd3 <= 0.0 and _enraged():
		cd3 = 12.0
		state = "jam"
		st_t = 2.2
		arena.float_text(position + Vector2(0, -34), Loc.t("BOURRAGE PAPIER !"), Pal.ACCENT)
	return dirp.orthogonal() * speed * 0.8 + dirp * speed * (0.4 if dist > 160.0 else -0.4)


## Le Géomètre (vague 10 du Tableau noir, parfois à la place de la Photocopieuse) : un compas géant.
## - Il s'approche, puis PLANTE sa pointe : il ne bouge plus et prend +50 % de dégâts.
## - Planté, il trace des cercles autour de lui (2, puis 3 en dessous de 50 % de PV). Chaque cercle
##   est annoncé 1 s (on voit la branche tourner), puis son trait brûle 3 s : il faut se placer
##   entre les cercles, et ceux du plantage d'avant brûlent encore.
## - Sous 50 % de PV : il se replante plus vite, et en se relevant il LANCE sa pointe (un trait
##   droit annoncé, vers toi).
const GEO_WARN := 1.0      # un cercle est annoncé 1 s...
const GEO_BURN := 3.0      # ... puis brûle 3 s
const GEO_GAP := 46.0      # écart entre deux cercles du même plantage (la place pour se glisser)


func _boss_geo(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var rage := _enraged()
	st_t -= delta
	match state:
		"plant":
			flash = maxf(flash, 0.12)   # (il luit tant qu'il est planté : c'est le moment de frapper)
			cd -= delta
			if cd2 > 0.0 and cd <= 0.0:
				# un cercle de plus : le premier passe sur toi, les suivants s'écartent d'un cran
				var k := int(cd3) - int(cd2)
				var r0 := clampf(position.distance_to(arena.player.position), 50.0, 190.0)
				var r: float = r0 + GEO_GAP * float([0.0, -1.0, 1.0][clampi(k, 0, 2)])   # sur toi, puis un cran dedans, un cran dehors
				arena.add_ring(position, clampf(r, 34.0, 230.0), GEO_WARN, GEO_BURN, dmg * 0.45, ink_col)
				Sfx.play("swing")
				cd2 -= 1.0
				cd = 0.55 if rage else 0.75
			if st_t <= 0.0:
				state = "walk"
				st_t = 1.6 if rage else 2.6
				if rage:
					# il se relève en lançant sa pointe : un trait droit annoncé, vers toi (et deux en éventail)
					for a in [-0.35, 0.0, 0.35]:
						var d := dirp.rotated(a)
						arena.add_stroke(position, _wall_point(position, d), 0.8, dmg * 0.5, ink_col)
			return Vector2.ZERO
		_:
			if st_t <= 0.0:
				state = "plant"
				cd3 = 3.0 if rage else 2.0   # nombre de cercles de ce plantage
				cd2 = cd3
				cd = 0.25
				st_t = cd3 * (0.55 if rage else 0.75) + GEO_WARN + 0.6
				arena.float_text(position + Vector2(0, -34), Loc.t("PLANTÉ !"), Pal.ACCENT)
				arena.shake(2.0)
				return Vector2.ZERO
	# il vient se placer à mi-distance : assez près pour que ses cercles t'entourent
	return dirp * speed * (1.5 if dist > 120.0 else (0.5 if dist > 70.0 else -0.6)) + dirp.orthogonal() * speed * 0.5


## L'Encrier renversé, boss final du Tableau noir, en 3 PHASES (66 % et 33 % de PV) :
## 1. L'encre se renverse : inondation (grosses gouttes), spirale, charge qui laisse une traînée d'encre.
##    Ses gouttes et ses coups TACHENT ton perso (ta couleur tire vers l'Ombre) ; des BUVARDS
##    apparaissent pour te nettoyer.
## 2. Éclats de lumière : ses tirs deviennent de la LUMIÈRE (×1,5 sur un perso Ombre), projecteur
##    (double anneau) et NUIT D'ENCRE, où seuls ses éclats de lumière brillent.
## 3. Taches de Rorschach : il se dédouble en MIROIR ; le reflet copie chaque attaque (PV partagés).
func _boss_ink(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var want := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if want > toile_phase:
		toile_phase = want
		_ink_transition()
	if boss_inv > 0.0:
		boss_inv -= delta
		flash = 0.6 if int(t * 12.0) % 2 == 0 else 0.1
		return Vector2.ZERO
	light_shots = toile_phase >= 2
	var fast: float = [1.0, 1.0, 1.15, 1.3][toile_phase]
	var twin := is_instance_valid(reflet) and not reflet.dead
	# Buvards : de quoi se nettoyer quand on est taché
	blot_cd -= delta
	if blot_cd <= 0.0:
		blot_cd = 7.0
		if arena.player.stains > 0 and arena.blotters.size() < (2 if toile_phase >= 3 else 1):
			arena.spawn_blotter(position)
	if state == "dash":
		st_t -= delta
		cd3 -= delta
		if cd3 <= 0.0:
			cd3 = 0.05
			arena.add_hazard(position, 8.0, 3.0, 0.8, dmg * 0.35, ink_col)
			if twin:
				arena.add_hazard(reflet.position, 8.0, 3.0, 0.8, dmg * 0.35, ink_col)
		if st_t <= 0.0:
			state = "walk"
			_ring(18, randf() * TAU, 0.9)
		return dash_dir * speed * 4.5
	if state == "spiral":
		st_t -= delta
		cd3 -= delta
		if cd3 <= 0.0:
			cd3 = 0.08
			spiral_a += 0.31
			for k in 3:
				_shoot(Vector2.from_angle(spiral_a + TAU * k / 3.0), 0.85)
			Sfx.play("enemy_shot")
		if st_t <= 0.0:
			state = "walk"
		return dirp * speed * 0.3
	if state == "aim":
		st_t -= delta
		flash = 0.5 if int(t * 14.0) % 2 == 0 else 0.0
		if st_t <= 0.0:
			state = "dash"
			st_t = 0.55
		return Vector2.ZERO
	cd -= delta * fast
	cd2 -= delta
	if cd <= 0.0:
		cd = 3.0
		pattern = (pattern + 1) % (3 if toile_phase == 1 else 4)
		match pattern:
			0:
				# Inondation : grosses gouttes en cloche qui TACHENT et laissent de larges flaques
				for k in 5:
					arena.lob(self, arena.player.position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 90.0), 1.2, 34.0)
				if twin:
					for k in 3:
						arena.lob(self, arena.player.position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, 90.0), 1.3, 34.0, reflet.position)
			1:
				state = "spiral"
				st_t = 2.4
			2:
				state = "aim"
				st_t = 0.6
				dash_dir = dirp
				arena.add_ruler(position, _wall_point(position, dirp), 0.6)
				if twin:
					var md := Vector2(-dirp.x, dirp.y)
					arena.add_ruler(reflet.position, _wall_point(reflet.position, md), 0.6)
			3:
				# Projecteur : deux anneaux de lumière, le 2e décalé (on se glisse entre les éclats)
				var a0 := randf() * TAU
				_ring(16, a0, 0.75)
				var me := self
				arena._after(0.45, func():
					if is_instance_valid(me) and not me.dead and not arena.ended:
						me._ring(16, a0 + PI / 16.0, 0.95))
				arena.float_text(position + Vector2(0, -40), Loc.t("PROJECTEUR !"), Pal.ACCENT)
	if toile_phase >= 2 and cd2 <= 0.0:
		cd2 = 14.0
		arena.darkness(6.0)
		arena.float_text(position + Vector2(0, -40), Loc.t("NUIT D'ENCRE !"), Pal.BAD)
	return dirp * speed * (1.0 if dist > 120.0 else 0.3)


## Passage de phase de l'Encrier : intouchable 1,5 s, onde qui repousse ; en phase 3, il se dédouble.
func _ink_transition() -> void:
	boss_inv = 1.5
	state = "walk"
	cd = 1.8
	cd2 = 4.0
	arena.hud.announce(Loc.t("ÉCLATS DE LUMIÈRE !") if toile_phase == 2 else Loc.t("TACHES DE RORSCHACH !"), Pal.BAD)
	arena.shake(12.0)
	arena.hitstop(0.2)
	Sfx.play("boss")
	arena.explosion(position, 140.0, Color(ink_col, 0.9))
	var p := arena.player
	var away := (p.position - position).normalized()
	p.position = (p.position + away * 70.0).clamp(Vector2(12, 12), Vector2(Arena.W - 12, Arena.H - 12))
	if toile_phase == 3:
		_split()


## Taches de Rorschach : un reflet de l'Encrier apparaît en miroir (axe vertical au centre de la page).
## Il copie chaque mouvement et chaque tir ; les coups qu'il prend vont à l'Encrier (PV partagés).
func _split() -> void:
	if absf(position.x - Arena.W / 2.0) < 90.0:
		position.x = Arena.W * (0.28 if position.x < Arena.W / 2.0 else 0.72)
	var tw := arena._spawn_enemy_raw(id, Vector2(Arena.W - position.x, position.y), false)
	arena.boss = self
	if tw == null:
		return
	tw.reflet_of = self
	tw.is_boss = false
	tw.max_hp = 1e9
	tw.hp = 1e9
	tw.loot = 0.0
	tw.dmg = dmg
	tw.boss_inv = boss_inv
	reflet = tw
	arena.burst(tw.position, ink_col, 30, 140.0)
	arena.burst(position, ink_col, 30, 140.0)


## Le reflet de Rorschach : il suit l'Encrier en miroir, ne pense pas tout seul.
func _reflet_tick(delta: float) -> void:
	var m := reflet_of
	if not is_instance_valid(m) or m.dead:
		dead = true
		arena.burst(position, ink_col, 24, 120.0)
		arena.enemies.erase(self)
		queue_free()
		return
	t += delta
	position = Vector2(Arena.W - m.position.x, m.position.y)
	contact = m.contact
	boss_inv = m.boss_inv
	flash = maxf(m.flash, maxf(0.0, flash - delta * 7.0))
	body.scale = Vector2(-m.body.scale.x, m.body.scale.y)
	body.rotation = -m.body.rotation
	body.position = m.body.position
	mat.set_shader_parameter("flash", flash)


# ------------------------------------------------------------------ Attaques

func _shoot(dir: Vector2, speed_mult: float) -> void:
	arena.spawn_enemy_bullet(self, position, dir * 140.0 * speed_mult, 0.0, light_shots)
	if is_instance_valid(reflet) and not reflet.dead:
		# Rorschach : le reflet tire la même chose, en miroir
		arena.spawn_enemy_bullet(self, reflet.position, Vector2(-dir.x, dir.y) * 140.0 * speed_mult, 0.0, light_shots)


func _ring(n: int, offset := 0.0, speed_mult := 1.0) -> void:
	if _frenzy():
		n += ceili(n / 3.0)   # fureur : un tiers de projectiles en plus
	for i in n:
		_shoot(Vector2.from_angle(offset + TAU * i / n), speed_mult)
	Sfx.play("enemy_shot")


func _explode() -> void:
	arena.explosion(position, 48.0, Color(ink_col, 0.8))
	if position.distance_to(arena.player.position) < 48.0 + arena.player.radius:
		arena.player.take_hit(dmg, element, self)
	arena.add_hazard(position, 22.0, 3.0, 0.55, 0.0, ink_col)
	contact = false
	arena.kill_enemy(self)


func _summon(type_id: String, n: int) -> void:
	for i in n:
		arena.spawn_enemy_now(type_id, position + Vector2.from_angle(randf() * TAU) * (radius + 16.0), false)


func _enraged() -> bool:
	return hp < max_hp * 0.5


## Hachures (La Muse, vague 10) : elle RATURE la page. Enchaîne ses 4 attaques dans un ordre mélangé (toutes avant de recommencer) :
## - Zigzag : 3 petites charges (5 enragé), chacune annoncée à la règle, qui laissent un trait d'encre.
## - Hachures : des lignes parallèles barrent la page (on se glisse ENTRE elles) ; enragé : en croisillon.
## - Croix : il barre ta position d'un X (3 de suite), le centre explose.
## - Gribouillage : il griffonne sur place, crachant de l'encre au hasard, et libère des Gribouillis.
func _boss_hatch(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var rage := _enraged()
	st_t -= delta
	match state:
		"walk":
			if st_t <= 0.0:
				# Sac mélangé : les 4 attaques passent avant qu'une revienne (jamais 2 fois de suite)
				if atk_bag.is_empty():
					atk_bag = ["zigzag", "hatch", "cross", "scribble"]
					atk_bag.shuffle()
					if atk_bag[0] == last_atk:
						atk_bag.reverse()
				last_atk = atk_bag.pop_front()
				flash = 0.8
				match last_atk:
					"zigzag":
						state = "zz_aim"
						cd2 = 5 if rage else 3
						_zz_aim(dirp)
					"hatch":
						state = "hatch"
						st_t = 2.2
						_hatch(randf() * PI, 0.0)
						if rage:
							cd3 = 0.9   # 2e passe perpendiculaire
					"cross":
						state = "cross"
						cd2 = 3
						cd3 = 0.0
						st_t = 2.0
					"scribble":
						state = "scribble"
						st_t = 2.2
						cd3 = 0.0
						arena.float_text(position + Vector2(0, -40), Loc.t("GRIBOUILLAGE !"), Pal.BAD)
				return Vector2.ZERO
			return dirp * speed * (1.0 if dist > 90.0 else 0.4)
		"zz_aim":
			flash = 0.5 if int(t * 16.0) % 2 == 0 else 0.0
			if st_t <= 0.0:
				state = "zz_dash"
				st_t = 0.32
				Sfx.play("swing")
			return Vector2.ZERO
		"zz_dash":
			cd -= delta
			if cd <= 0.0:
				cd = 0.04
				arena.add_hazard(position, 7.0, 2.2, 1.0, dmg * 0.4, ink_col)
			if st_t <= 0.0:
				cd2 -= 1
				if cd2 > 0:
					state = "zz_aim"
					_zz_aim(dirp)
				else:
					_rest(rage)
			return dash_dir * speed * 5.0
		"hatch":
			if cd3 > 0.0:
				cd3 -= delta
				if cd3 <= 0.0:
					_hatch(hatch_a + PI / 2.0, 24.0)   # croisillon, décalé d'une demi-maille
			if st_t <= 0.0:
				_rest(rage)
			return dirp * speed * 0.2
		"cross":
			cd3 -= delta
			if cd3 <= 0.0 and cd2 > 0:
				cd2 -= 1
				cd3 = 0.45 if rage else 0.6
				var c := arena.player.position + arena.player_vel() * 0.25
				var r := 46.0
				var a0 := randf() * PI
				for k in 2:
					var d := Vector2.from_angle(a0 + k * PI / 2.0)
					arena.add_stroke(c + d * r, c - d * r, 0.85, dmg * 0.4, ink_col)
				arena.add_stroke(c, c, 0.85, dmg * 0.4, ink_col, 26.0)
				Sfx.play("zap")
			if st_t <= 0.0:
				_rest(rage)
			return Vector2.ZERO
		"scribble":
			cd3 -= delta
			if cd3 <= 0.0:
				cd3 = 0.06 if rage else 0.09
				body.rotation = randf_range(-0.4, 0.4)
				_shoot(Vector2.from_angle(randf() * TAU), randf_range(0.7, 1.3))
			if st_t <= 0.0:
				_summon("gribouille", 3 if rage else 2)
				_rest(rage)
			# tremble sur place en griffonnant
			return Vector2.from_angle(t * 40.0) * 30.0
	_rest(rage)
	return Vector2.ZERO


func _rest(rage: bool) -> void:
	state = "walk"
	st_t = 1.0 if rage else 1.7
	flash = 0.0


## Zigzag : vise le joueur (en anticipant un peu) et l'annonce à la règle.
func _zz_aim(dirp: Vector2) -> void:
	var aim := (arena.player.position + arena.player_vel() * 0.3 - position).normalized()
	dash_dir = aim if aim != Vector2.ZERO else dirp
	st_t = 0.4
	var reach := speed * 5.0 * 0.32
	arena.add_ruler(position, position + dash_dir * reach, 0.4)


## Hachures : lignes parallèles sur toute la page, espacées de 48 px (on passe entre).
func _hatch(angle: float, shift: float) -> void:
	hatch_a = angle
	var dir := Vector2.from_angle(angle)
	var nrm := dir.orthogonal()
	var c := arena.player.position
	for k in range(-6, 7):
		var o := c + nrm * (k * 48.0 + shift)
		if o.x < 0.0 or o.y < 0.0 or o.x > Arena.W or o.y > Arena.H:
			continue
		arena.add_stroke(_wall_point(o, dir), _wall_point(o, -dir), 1.0, dmg * 0.4, ink_col)
	Sfx.play("zap")


func _boss_critique(delta: float, dirp: Vector2) -> Vector2:
	cd -= delta
	if state == "spiral":
		st_t -= delta
		cd3 -= delta
		if cd3 <= 0.0:
			cd3 = 0.09
			spiral_a += 0.38
			var arms := 3 if _enraged() else 2
			for k in arms:
				_shoot(Vector2.from_angle(spiral_a + TAU * k / arms), 0.9)
			Sfx.play("enemy_shot")
		if st_t <= 0.0:
			state = "walk"
			cd = 1.6 if _enraged() else 2.4
	elif cd <= 0.0:
		state = "spiral"
		st_t = 2.6
	cd2 -= delta
	if cd2 <= 0.0:
		cd2 = 7.0 if _enraged() else 9.0
		_summon("tache", 4)
		# Le Critique « note » ta position : pâtés d'encre en cloche
		for k in 3:
			arena.lob(self, arena.player.position + Vector2.from_angle(TAU * k / 3.0) * 30.0, 1.2)
	return dirp * speed * (0.4 if state == "spiral" else 1.0)


func _boss_orbit(delta: float, dirp: Vector2, dist: float) -> Vector2:
	if state == "fade":
		st_t -= delta
		mat.set_shader_parameter("alpha", clampf(st_t / 0.5, 0.15, 1.0))
		if st_t <= 0.0:
			position = tp_pos
			tp_mark.t = 0.0   # la cible s'efface quand il arrive
			mat.set_shader_parameter("alpha", 1.0)
			contact = true
			state = "walk"
			_ring(16 if _enraged() else 12, randf() * TAU, 0.9)
		return Vector2.ZERO
	cd -= delta
	cd2 -= delta
	if cd2 <= 0.0:
		cd2 = 1.6 if _enraged() else 2.3   # (le 1er boss tire moins souvent)
		for k in range(-1, 2):   # éventail de 3 tirs (le 1er boss reste abordable)
			_shoot(dirp.rotated(k * 0.25), 1.1)
		Sfx.play("enemy_shot")
	if cd <= 0.0:
		cd = 4.5 if _enraged() else 5.5
		state = "fade"
		st_t = 1.0   # le point d'arrivée est annoncé 1 s avant
		contact = false
		var p := arena.player.position
		tp_pos = p + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 120.0)
		tp_pos.x = clampf(tp_pos.x, 30.0, Arena.W - 30.0)
		tp_pos.y = clampf(tp_pos.y, 30.0, Arena.H - 30.0)
		tp_mark = {"pos": tp_pos, "t": 2.0, "boss": true}
		arena.telegraphs_fx.append(tp_mark)
	var tang := dirp.orthogonal()
	return (tang + dirp * clampf((dist - 95.0) / 50.0, -1.0, 1.0)).normalized() * speed


## La Toile Blanche : spirales, anneaux, charges, renforts... et elle GOMME des bouts de ton perso.
## La Toile Blanche, boss final de La Feuille, en 3 PHASES (66 % et 33 % de PV) :
## 1. spirale, anneaux, charge, renforts, coups de gomme ;
## 2. tout va 30 % plus vite, pluie de gommes, et la page commence à s'effacer par les bords ;
## 3. presque sans pause (70 % plus vite), gommes pendant la spirale, la page rétrécit encore.
## À chaque palier : elle est intouchable 1,5 s, une onde te repousse, « LA TOILE S'EFFACE... ».
func _boss_toile(delta: float, dirp: Vector2, dist: float) -> Vector2:
	var want := 1 if hp > max_hp * 0.66 else (2 if hp > max_hp * 0.33 else 3)
	if want > toile_phase:
		toile_phase = want
		_toile_transition()
	if boss_inv > 0.0:
		boss_inv -= delta
		flash = 0.6 if int(t * 12.0) % 2 == 0 else 0.1
		return Vector2.ZERO
	var fast: float = [1.0, 1.0, 1.3, 1.7][toile_phase]
	cd -= delta * fast
	if state == "dash":
		st_t -= delta
		if st_t <= 0.0:
			state = "walk"
		return dash_dir * speed * 5.0
	if state == "aim":
		st_t -= delta
		flash = 0.5 if int(t * 14.0) % 2 == 0 else 0.0
		if st_t <= 0.0:
			state = "dash"
			st_t = 0.5
			dash_dir = dirp
		return Vector2.ZERO
	if state == "rings":
		cd3 -= delta * fast
		if cd3 <= 0.0:
			cd3 = 0.5
			_ring(18 + 4 * (toile_phase - 1), repeat * 0.17, 0.9)
			repeat -= 1
			if repeat <= 0:
				state = "walk"
		return dirp * speed * 0.5
	if state == "spiral":
		st_t -= delta
		cd3 -= delta
		cd2 -= delta
		if cd3 <= 0.0:
			cd3 = 0.08 / fast
			spiral_a += 0.33
			for k in 4:
				_shoot(Vector2.from_angle(spiral_a * (1 if k % 2 == 0 else -1) + TAU * k / 4), 0.85)
			Sfx.play("enemy_shot")
		if toile_phase >= 3 and cd2 <= 0.0:
			cd2 = 1.0   # phase 3 : des gommes tombent pendant la spirale
			arena.add_eraser(arena.player.position, 30.0, 1.2, dmg)
		if st_t <= 0.0:
			state = "walk"
		return dirp * speed * 0.3
	if cd <= 0.0:
		cd = 1.4 if toile_phase >= 3 else 3.2
		pattern = (pattern + 1) % (5 if toile_phase == 1 else 6)
		match pattern:
			0:
				state = "spiral"
				st_t = 3.0
				cd2 = 0.5
			1:
				state = "rings"
				repeat = 3 + (toile_phase - 1)
				cd3 = 0.0
			2:
				state = "aim"
				st_t = 0.6 / fast
			3:
				var pool := EnemyDB.pool(Run.wave)
				_summon(pool.pick_random(), 2 + (toile_phase - 1))
				_summon("tache", 2)
			4:
				# Coups de gomme : là où ils tombent, ton dessin s'efface
				var p := arena.player.position
				arena.add_eraser(p, 34.0, 1.1, dmg)
				if toile_phase >= 2:
					for k in 2:
						arena.add_eraser(p + Vector2.from_angle(randf() * TAU) * 60.0, 30.0, 1.4, dmg)
			5:
				# Phase 2+ : pluie de gommes autour de toi
				var c := arena.player.position
				arena.add_eraser(c, 28.0, 1.3, dmg)
				for k in 4 + 2 * (toile_phase - 2):
					arena.add_eraser(c + Vector2.from_angle(TAU * k / (4.0 + 2 * (toile_phase - 2)) + randf() * 0.4) * randf_range(45.0, 80.0), 26.0, 1.5 + k * 0.12, dmg)
				arena.float_text(position + Vector2(0, -50), Loc.t("PLUIE DE GOMMES"), Pal.BAD)
	return dirp * speed * (0.6 if dist < 80.0 else 1.0)


## Passage de phase : intouchable 1,5 s, onde qui repousse, la page s'efface par les bords.
func _toile_transition() -> void:
	boss_inv = 1.5
	state = "walk"
	cd = 1.8
	arena.hud.announce(Loc.t("LA TOILE S'EFFACE...") if toile_phase == 2 else Loc.t("TOUT DOIT DISPARAÎTRE !"), Pal.BAD)
	arena.shake(12.0)
	arena.hitstop(0.2)
	Sfx.play("boss")
	arena.explosion(position, 140.0, Color(1, 1, 1, 0.9))
	var p := arena.player
	var away := (p.position - position).normalized()
	p.position = (p.position + away * 70.0).clamp(Vector2(12, 12), Vector2(Arena.W - 12, Arena.H - 12))
	arena.void_target = 0.06 if toile_phase == 2 else 0.113   # zone de jeu : 77 % puis 60 %
	arena.void_dmg = dmg * 0.35


