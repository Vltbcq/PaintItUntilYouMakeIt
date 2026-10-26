class_name Familiar
extends Node2D
## Un familier (dessiné par le joueur) qui vit sur la page avec son propre comportement.
## L'arène appelle tick(delta) à chaque image. Voir FamiliarDB pour la liste.

var arena: Arena
var id := ""
var form := ""          # comportement joué (= id ; la Chimère en change toutes les 5 s)
var chim_t := 0.0       # Chimère : prochain changement
var def: Dictionary
var sprite: Sprite2D
var t := 0.0
var cd := 1.5           # prochaine action (s)
var cd2 := 0.0
var cd3 := 0.0
var state := "walk"
var st_t := 0.0
var goal := Vector2.ZERO
var vel := Vector2.ZERO
var ang := 0.0
var target: Enemy
var rush_t := 0.0       # Sifflet : il fonce sur la cible du rappel
var hit_cd := {}        # ennemi -> temps avant de pouvoir le retoucher
var hp := 0.0           # Woinic
var max_hp := 0.0
var ko_t := 0.0
var line_to := Vector2.ZERO   # langue de la grenouille / fléchette de Teemeo
var line_t := 0.0
var line_col := Color.WHITE
var shroom_n := 0       # Teemeo : champignons posés
const LUCIOLE_R := 48.0
const GRENOUILLE_R := 58.0
const PAON_R := 70.0
const CHIMERA_EVERY := 5.0
var fetch: Array = []   # Pie : pièces brillantes à aller chercher {pos, v}
var carry := false      # Pie : elle rapporte une pièce
var sm := {"fill": 0.5, "dmg": 1.0, "spd": 1.0}   # effet de la taille du dessin
var frac: Array = []    # part de chaque couleur du dessin : chances d'effet élémentaire
var darts: Array = []   # Teemeo : fléchettes en vol {pos, vel, life}
var lit: Array = []     # Luciole : ennemis dans son aura
var life := -1.0        # oiseau de la Cage : durée de vie (s), -1 = permanent
var perch := Vector2.ZERO   # oiseau de la Cage : de quel côté de l'ennemi il se pose
var peck_t := 0.0       # ... et son coup de bec en cours
var copy := {}          # Perroquet : le coup d'arme de mêlée qu'il est en train de copier
var copy_spr: Sprite2D  # ... et l'arme qu'il tient pendant ce temps
var bird_dmg := 0.0


func setup(a: Arena, fid: String) -> void:
	arena = a
	id = fid
	def = FamiliarDB.get_def(id)
	var art: Dictionary = Run.familiar_art[id]
	sprite = Gfx.sprite(Gfx.texture(Analyzer.trim(art.image)), Gfx.material(art.effect, art.get("outline", false)))
	add_child(sprite)
	var an := Analyzer.analyze(art.image)
	frac = an.get("frac", [])
	sm = FamiliarDB.size_mult(def, int(an.get("pixels", 0)))
	position = arena.player.position + Vector2.from_angle(randf() * TAU) * 30.0
	goal = position
	ang = randf() * TAU
	cd = randf_range(0.8, 2.0)
	form = id
	if id == "chimere":
		form = FamiliarDB.CHIMERA_FORMS.pick_random()
		chim_t = CHIMERA_EVERY
	_init_form()


## Ce que le comportement en cours a besoin au départ (PV de Woinic, élan du Hérisson).
func _init_form() -> void:
	if form == "pavel":
		max_hp = 60.0 + 18.0 * Run.wave
		hp = max_hp
	if form == "herisson_f":
		vel = Vector2.from_angle(randf() * TAU) * 110.0


## Chimère : abandonne son pouvoir actuel (proprement) et en prend un autre au hasard.
func _chimera_swap() -> void:
	_exit_tree_luciole()
	_end_copy()
	for f in fetch:
		Run.gold += int(f.v)
	fetch.clear()
	carry = false
	darts.clear()
	state = "walk"
	st_t = 0.0
	ko_t = 0.0
	visible = true
	sprite.modulate = Color.WHITE
	sprite.rotation = 0.0
	var forms: Array = FamiliarDB.CHIMERA_FORMS.filter(func(f): return f != form)
	form = forms.pick_random()
	cd = minf(cd, 0.6)   # le nouveau pouvoir sert presque tout de suite
	_init_form()
	arena.burst(position, Color("c071f0"), 10, 80.0)
	arena.float_text(position + Vector2(0, -18), String(FamiliarDB.get_def(form).name).to_upper(), Color("c071f0"))


## Oiseau de la Cage : vit 6 s ; fonce sur l'ennemi visé par la cage et le picore jusqu'à ce qu'il meure.
func setup_bird(a: Arena, tex: Texture2D, effect: String, outline: bool, dmg: float, fr: Array = [], prey: Enemy = null) -> void:
	frac = fr
	arena = a
	id = "oiseau"
	form = "oiseau"   # (sans ça, il ne faisait rien : il restait sur place)
	target = prey
	perch = Vector2.from_angle(randf() * TAU)
	def = {}
	life = 6.0
	bird_dmg = dmg
	sprite = Gfx.sprite(tex, Gfx.material(effect, outline))
	add_child(sprite)
	position = arena.player.position + Vector2(0, -10)
	cd = 0.2


# ------------------------------------------------------------------ Outils communs

## Dégâts d'un familier : base + vague, × tes dégâts, × bonus des amulettes de familiers.
func fdmg(base: float, per_wave: float) -> float:
	var m: float = sm.dmg * (1.0 + 0.3 * Run.amulet_count("niche")) * (1.0 + 0.2 * Run.amulet_count("dresseur") * Run.familiars.size())
	if arena.whip_t > 0.0:
		m *= 1.0 + 0.1 * arena.whip_stacks   # Fouet de dresseur
	return (base + per_wave * Run.wave) * (1.0 + Run.stats.dmg / 100.0) * m


## Délai entre deux actions (Croquettes : -15 % chacune).
func fcd(sec: float) -> float:
	return sec * pow(0.85, Run.amulet_count("croquettes")) / sm.spd


func _speed() -> float:
	return sm.spd * (1.0 + 0.25 * Run.amulet_count("laisse"))


func _leash() -> float:
	return 75.0


## Le familier touche un ennemi (Collier à grelot : soin ; Meute : un kill recharge la meute).
func hit(e: Enemy, dmg: float, kb := Vector2.ZERO) -> void:
	if e == null or e.dead:
		return
	var h0: float = e.hp
	e.hurt(dmg, false, kb)
	arena.fam_credit(id, h0 - maxf(0.0, e.hp))
	_elements(e, dmg)
	if e.dead:
		on_kill()


## Couleurs du dessin = éléments, comme les armes : chaque couleur a sa chance d'effet
## (selon sa part du dessin, × puissance élémentaire).
func _elements(e: Enemy, dmg: float) -> void:
	if frac.is_empty() or e.dead or Run.amulet_count("teinture") == 0:
		return
	var power: float = 1.0 + Run.stats.el_power / 100.0
	for el in range(1, mini(frac.size(), Pal.COUNT)):
		var chance: float = float(frac[el]) * power
		if el == e.element:
			chance *= 0.3   # un ennemi résiste à son propre élément
		if chance > 0.0 and randf() < chance:
			arena._apply_el(e, el, dmg)


## Meute : quand un familier tue, tous les familiers ont leur délai de capacité réduit de 50 %.
func on_kill() -> void:
	if Run.amulet_count("meute") == 0:
		return
	for fm in arena.familiars:
		fm.cd *= 0.5
		fm.cd2 *= 0.5
		fm.cd3 *= 0.5


## Une ACTION = une utilisation de capacité (piqûre, plongeon, langue, livraison, copie...).
## Collier à grelot : toutes les 5 actions (tous familiers confondus), +1 PV par collier.
func _action() -> void:
	var g := Run.amulet_count("collier_grelot")
	if g == 0:
		return
	arena.grelot_n += 1
	if arena.grelot_n >= 5:
		arena.grelot_n = 0
		arena.player.heal(1.0 * g)


## Se promène autour du joueur (Laisse : plus vite).
func _wander(delta: float, speed := 90.0) -> void:
	var p := arena.player.position
	if position.distance_to(goal) < 6.0 or goal.distance_to(p) > _leash() * 1.4:
		goal = p + Vector2.from_angle(randf() * TAU) * randf_range(16.0, _leash())
	position = position.move_toward(goal, speed * _speed() * delta)


func _sitflip(dir_x: float) -> void:
	if absf(dir_x) > 0.1:
		sprite.flip_h = dir_x < 0.0


## Sifflet : l'ennemi désigné, s'il est encore là.
func _called() -> Enemy:
	var w: Enemy = arena.whistle
	if w and is_instance_valid(w) and not w.dead:
		return w
	return null


func _strongest(r: float) -> Enemy:
	var best: Enemy = null
	var score := -1.0
	for e in arena.near(arena.player.position, r):
		if e.dead:
			continue
		var s: float = e.max_hp + (100000.0 if e.is_boss else (10000.0 if e.elite else 0.0))
		if s > score:
			score = s
			best = e
	return best


# ------------------------------------------------------------------ Boucle

func tick(delta: float) -> void:
	t += delta
	cd -= delta
	line_t -= delta
	for k in hit_cd.keys():
		hit_cd[k] -= delta
		if hit_cd[k] <= 0.0:
			hit_cd.erase(k)
	sprite.position.y = -absf(sin(t * 7.0)) * 1.5
	# Rappel au pied (Sifflet) : il fonce vers l'ennemi désigné, puis reprend son comportement
	if rush_t > 0.0:
		rush_t -= delta
		var w := _called()
		if w:
			position = position.move_toward(w.position, 320.0 * _speed() * delta)
			goal = w.position
			if id == "herisson_f":
				vel = (w.position - position).normalized() * vel.length()
	if id == "chimere":
		chim_t -= delta
		if chim_t <= 0.0:
			chim_t = CHIMERA_EVERY
			_chimera_swap()
	if life >= 0.0:
		life -= delta
		sprite.modulate.a = clampf(life / 0.5, 0.0, 1.0)
		if life <= 0.0:
			arena.familiars.erase(self)
			queue_free()
			return
	match form:
		"oiseau":
			_oiseau(delta)
		"moustique":
			_moustique(delta)
		"taupe":
			_taupe(delta)
		"pie":
			_pie(delta)
		"pigeon":
			_pigeon(delta)
		"herisson_f":
			_herisson(delta)
		"luciole":
			_luciole(delta)
		"perroquet":
			_perroquet(delta)
		"corbeau":
			_corbeau(delta)
		"grenouille":
			_grenouille(delta)
		"fantome":
			_fantome(delta)
		"yuki":
			_yuki(delta)
		"pavel":
			_pavel(delta)
		"teemeo":
			_teemeo(delta)
		"paon":
			_paon(delta)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if line_t > 0.0:
		draw_line(Vector2.ZERO, line_to - position, line_col, 2.0)
	for dt in darts:
		var dp: Vector2 = dt.pos - position
		draw_line(dp, dp - dt.vel.normalized() * 6.0, Color("3a5a1a"), 2.0)
		draw_circle(dp, 1.5, Color("c8e070"))
	if form == "luciole":
		var glow := 0.5 + 0.5 * sin(t * 4.0)
		draw_circle(Vector2.ZERO, LUCIOLE_R, Color(1.0, 0.95, 0.4, 0.07 + 0.04 * glow))
		draw_arc(Vector2.ZERO, LUCIOLE_R, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.25 + 0.15 * glow), 1.0)
	if form == "grenouille" and state == "tongue":
		var a := (1.0 - st_t / 0.35) * TAU + ang
		draw_line(Vector2.ZERO, Vector2.from_angle(a) * GRENOUILLE_R, Color("e85a8a"), 3.0)
		draw_arc(Vector2.ZERO, GRENOUILLE_R, ang, a, 24, Color(0.9, 0.35, 0.55, 0.35), 2.0)
	if form == "pie":
		# pièces qui brillent au sol, et celle qu'elle tient dans le bec
		for k in fetch.size():
			if k == 0 and carry:
				continue
			_coin(fetch[k].pos - position, k)
		if carry:
			_coin(Vector2(5, -3), 0)
	if form == "paon" and state == "roue":
		# la roue : un éventail de plumes colorées qui s'ouvre
		var k := clampf(1.0 - st_t / 0.8, 0.0, 1.0)
		var open := minf(1.0, k * 3.0)
		var cols := [Color("3a86ff"), Color("4caf50"), Color("f0c43a"), Color("3a86ff"), Color("4caf50")]
		for i in 9:
			var a := -PI / 2.0 + (float(i) - 4.0) / 4.0 * 1.3 * open
			var tip := Vector2.from_angle(a) * 22.0 * open
			draw_line(Vector2.ZERO, tip, Color("2a6a5a"), 2.0)
			draw_circle(tip, 3.5, cols[i % cols.size()])
			draw_circle(tip, 1.5, Color("1a1423"))
		draw_arc(Vector2.ZERO, PAON_R * k, 0.0, TAU, 40, Color(0.95, 0.5, 0.8, 0.5 * (1.0 - k)), 2.0)
	if form == "pavel" and hp < max_hp:
		draw_rect(Rect2(-10, 12, 20, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-10, 12, 20 * hp / max_hp, 3), Pal.GOOD)


# ------------------------------------------------------------------ Comportements

func _moustique(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		target = arena.nearest(arena.player.position, 220.0)
	if target == null:
		_wander(delta, 110.0)
		return
	# vole autour de sa cible en zigzag, et pique dès que c'est prêt
	var spot := target.position + Vector2(sin(t * 9.0) * 8.0, -10.0 + cos(t * 7.0) * 4.0)
	position = position.move_toward(spot if cd > 0.0 else target.position, 200.0 * _speed() * delta)
	_sitflip(target.position.x - position.x)
	if cd <= 0.0 and position.distance_to(target.position) < 8.0:
		cd = fcd(1.5)
		var victim := target
		hit(victim, fdmg(4.0, 1.2))
		_action()
		arena.player.heal(1.0)
		arena.burst(position, Pal.BAD, 4, 40.0)


## Pigeon : vole au-dessus de toi, et toutes les 3 s lâche une fiente sur un ennemi proche
## (dégâts + ralenti 1,5 s). Une fois sur 10, c'est sur toi : tu es ralenti 1,5 s.
const PIGEON_CD := 3.0


func _pigeon(delta: float) -> void:
	var a := t * 1.3
	var to := arena.player.position + Vector2(cos(a) * 20.0, -24.0 + sin(a * 2.0) * 4.0)
	_sitflip(to.x - position.x)
	position = position.lerp(to, 1.0 - exp(-6.0 * delta))
	sprite.position.y -= 10.0   # (il vole : son ombre reste au sol)
	if cd > 0.0:
		return
	cd = fcd(PIGEON_CD)
	var tgt: Node2D = null
	if randf() < 0.1:
		tgt = arena.player   # oups
	else:
		tgt = arena.nearest(arena.player.position, 140.0)
	if tgt == null:
		return
	_action()
	var d := Polygon2D.new()
	d.polygon = PackedVector2Array([Vector2(0, -2), Vector2(1.5, 0), Vector2(0, 2), Vector2(-1.5, 0)])
	d.color = Color(0.95, 0.95, 0.9)
	d.position = position + sprite.position
	d.z_index = 4
	arena.world.add_child(d)
	var dmg := fdmg(4.0, 0.8)
	var tw := d.create_tween()
	tw.tween_property(d, "position", tgt.position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var at := d.position
		d.queue_free()
		arena._splat(at, 3.0, Color(0.92, 0.92, 0.86))
		if not is_instance_valid(tgt):
			return
		if tgt == arena.player:
			arena.player.poop_t = 1.5
			arena.float_text(arena.player.position + Vector2(0, -22), Loc.t("BEURK !"), Pal.DIM)
		elif not (tgt as Enemy).dead:
			hit(tgt as Enemy, dmg)
			(tgt as Enemy).slow_t = maxf((tgt as Enemy).slow_t, 1.5))


func _taupe(delta: float) -> void:
	match state:
		"dig":
			st_t -= delta
			sprite.modulate.a = clampf(st_t / 0.5, 0.0, 1.0)
			if st_t <= 0.0:
				if target and not target.dead:
					position = target.position
					target.pin_t = maxf(target.pin_t, 1.0)
					# la terre jaillit : tous les ennemis autour prennent des dégâts
					for o in arena.near(position, 28.0):
						hit(o, fdmg(6.0, 1.8), (o.position - position).normalized() * 60.0)
					arena.explosion(position, 28.0, Color(0.55, 0.35, 0.17, 0.6), true)
					arena.burst(position, Color("8a5a2b"), 16, 110.0)
					arena.float_text(position + Vector2(0, -16), Loc.t("SURPRISE !"), Color("c08040"))
					_action()
				sprite.modulate.a = 1.0
				state = "walk"
			return
	_wander(delta)
	if cd <= 0.0:
		cd = fcd(4.0)
		var list := arena.near(arena.player.position, 300.0).filter(func(e): return not e.dead)
		if not list.is_empty():
			target = _called() if _called() else list.pick_random()
			state = "dig"
			st_t = 0.5


func _herisson(delta: float) -> void:
	position += vel * _speed() * delta
	if position.x < 8.0 or position.x > Arena.W - 8.0:
		vel.x = -vel.x
	if position.y < 8.0 or position.y > Arena.H - 8.0:
		vel.y = -vel.y
	position = position.clamp(Vector2(8, 8), Vector2(Arena.W - 8, Arena.H - 8))
	sprite.rotation += 8.0 * delta
	if randf() < 0.01:
		vel = vel.rotated(randf_range(-1.0, 1.0))
	for e in arena.near(position, 10.0):
		var k: int = e.get_instance_id()
		if not hit_cd.has(k):
			hit_cd[k] = 0.6
			hit(e, fdmg(7.0, 2.0), vel.normalized() * 60.0)
			_action()


func _luciole(delta: float) -> void:
	# plane au-dessus de l'ennemi le plus proche de toi (ou de la cible du Sifflet)
	var w := _called()
	if w:
		target = w
	elif target == null or not is_instance_valid(target) or target.dead or t - st_t > 2.0:
		target = arena.nearest(arena.player.position, 400.0)
		st_t = t
	if target:
		position = position.move_toward(target.position + Vector2(sin(t * 3.0) * 10.0, -8.0 + cos(t * 2.0) * 6.0), 160.0 * _speed() * delta)
	else:
		_wander(delta)
	sprite.modulate = Color(1, 1, 0.6, 0.7 + 0.3 * sin(t * 10.0))
	# l'aura : +33 % de dégâts pour tous les ennemis dedans
	for e in lit:
		if is_instance_valid(e):
			e.firefly = false
	lit = arena.near(position, LUCIOLE_R)
	for e in lit:
		e.firefly = true


func _exit_tree_luciole() -> void:
	for e in lit:
		if is_instance_valid(e):
			e.firefly = false
	lit.clear()


func _corbeau(delta: float) -> void:
	match state:
		"dive":
			if target == null or not is_instance_valid(target) or target.dead:
				state = "back"
				return
			position = position.move_toward(target.position, 420.0 * _speed() * delta)
			_sitflip(target.position.x - position.x)
			if position.distance_to(target.position) < 8.0:
				hit(target, fdmg(20.0, 5.0), (target.position - arena.player.position).normalized() * 80.0)
				_action()
				arena.burst(position, Pal.INK, 10, 90.0)
				state = "back"
			return
		"back":
			var home := arena.player.position + Vector2(0, -30)
			position = position.move_toward(home, 300.0 * delta)
			if position.distance_to(home) < 6.0:
				state = "walk"
			return
	position = arena.player.position + Vector2(sin(t * 1.5) * 18.0, -30.0 + sin(t * 3.0) * 3.0)
	if cd <= 0.0:
		target = _called() if _called() else _strongest(350.0)
		cd = fcd(1.5)
		if target:
			state = "dive"


func _grenouille(delta: float) -> void:
	if state == "tongue":
		st_t -= delta
		if st_t <= 0.0:
			state = "walk"
		return
	# petits sauts
	cd2 -= delta
	if cd2 <= 0.0:
		cd2 = 1.2
		goal = arena.player.position + Vector2.from_angle(randf() * TAU) * randf_range(20.0, _leash())
	position = position.move_toward(goal, 140.0 * _speed() * delta)
	if position.distance_to(goal) > 2.0:
		sprite.position.y = -absf(sin(t * 12.0)) * 6.0
	if cd <= 0.0 and arena.nearest(position, GRENOUILLE_R) != null:
		# coup de langue circulaire : tous les ennemis autour
		cd = fcd(4.0)
		state = "tongue"
		st_t = 0.35
		ang = randf() * TAU
		_action()
		for e in arena.near(position, GRENOUILLE_R):
			hit(e, fdmg(10.0, 3.0), (e.position - position).normalized() * 70.0)
		arena.float_text(position + Vector2(0, -16), Loc.t("SLURP !"), Color("e85a8a"))


func _fantome(delta: float) -> void:
	match state:
		"cross":
			position += vel * delta
			for e in arena.near(position, 18.0):
				var k: int = e.get_instance_id()
				if not hit_cd.has(k):
					hit_cd[k] = 3.0
					e.blind_t = maxf(e.blind_t, 2.0)
					hit(e, fdmg(8.0, 2.5))
			if position.x < -30.0 or position.x > Arena.W + 30.0 or position.y < -30.0 or position.y > Arena.H + 30.0:
				state = "walk"
				position = arena.player.position + Vector2(0, -20)
			return
	sprite.modulate.a = 0.6
	_wander(delta, 70.0)
	if cd <= 0.0:
		cd = fcd(5.0)
		var p := arena.player.position
		if randf() < 0.5:
			var left := randf() < 0.5
			position = Vector2(-20.0 if left else Arena.W + 20.0, p.y)
			vel = Vector2(400.0 if left else -400.0, 0.0)
		else:
			var top := randf() < 0.5
			position = Vector2(p.x, -20.0 if top else Arena.H + 20.0)
			vel = Vector2(0.0, 400.0 if top else -400.0)
		_sitflip(vel.x)
		sprite.modulate.a = 0.9
		state = "cross"
		_action()


func _yuki(delta: float) -> void:
	var p := arena.player
	position = p.position + Vector2(-9.0, -16.0 + sin(t * 3.0) * 1.0)
	cd2 -= delta
	cd3 -= delta
	if cd <= 0.0:
		cd = fcd(8.0)
		p.heal(p.max_hp * 0.05)
		arena.burst(p.position, Pal.GOOD, 8, 60.0)
		_action()
	if cd2 <= 0.0 and p.paper <= 0:
		cd2 = fcd(12.0)
		p.paper += 1
		arena.float_text(p.position + Vector2(0, -26), Loc.t("YUKI TE PROTÈGE"), Color("9ad0ff"))
	if cd3 <= 0.0 and p.hp < p.max_hp * 0.25:
		cd3 = 10.0
		p.yuki_t = 3.0
		arena.float_text(p.position + Vector2(0, -26), Loc.t("VITE !"), Color("9ad0ff"))


func _pavel(delta: float) -> void:
	if ko_t > 0.0:
		ko_t -= delta
		visible = false
		if ko_t <= 0.0:
			visible = true
			hp = max_hp
			position = arena.player.position + Vector2(16, 0)
			arena.float_text(position + Vector2(0, -18), Loc.t("WOINIC REVIENT !"), Pal.GOOD)
		return
	# se place entre toi et l'ennemi le plus proche
	var p := arena.player.position
	var e := arena.nearest(p, 200.0)
	goal = p + ((e.position - p).normalized() * 26.0 if e else Vector2(18, 4))
	position = position.move_toward(goal, 120.0 * _speed() * delta)
	_sitflip(goal.x - position.x)
	# il encaisse les coups des ennemis collés à lui
	for o in arena.near(position, 14.0):
		if o.contact and not o.dead:
			hp -= o.dmg * 1.5 * delta
	if hp <= 0.0:
		ko_t = 10.0
		arena.burst(position, Pal.BAD, 14, 90.0)
		arena.float_text(position + Vector2(0, -18), Loc.t("WOINIC K.O."), Pal.BAD)


## Woinic est-il là pour attirer les ennemis ?
func pavel_up() -> bool:
	return form == "pavel" and ko_t <= 0.0


func _teemeo(delta: float) -> void:
	_wander(delta, 80.0)
	cd2 -= delta
	if cd2 <= 0.0:
		cd2 = fcd(2.5)
		if arena.shrooms.size() < 16:
			var sp := (arena.player.position + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 160.0)).clamp(Vector2(10, 10), Vector2(Arena.W - 10, Arena.H - 10))
			arena.shrooms.append({"pos": sp, "dmg": fdmg(4.0, 1.5)})
	# fléchettes : vraies balles, elles s'arrêtent sur le premier ennemi touché
	for dt in darts.duplicate():
		dt.pos += dt.vel * delta
		dt.life -= delta
		var hitme: Enemy = null
		for o in arena.near(dt.pos, 6.0):
			if not o.dead:
				hitme = o
				break
		if hitme:
			hitme.blind_t = maxf(hitme.blind_t, 2.0)
			hit(hitme, fdmg(6.0, 1.5))
			if not hitme.dead:
				arena._apply_el(hitme, Pal.POISON, fdmg(6.0, 1.5))   # toujours empoisonnées
			arena.burst(dt.pos, Color("c8e070"), 4, 50.0)
			darts.erase(dt)
		elif dt.life <= 0.0:
			darts.erase(dt)
	if cd <= 0.0:
		cd = fcd(2.5)
		var e: Enemy = _called() if _called() else arena.nearest(position, 260.0)
		if e:
			darts.append({"pos": position, "vel": (e.position - position).normalized() * 260.0, "life": 1.2})
			_action()
			Sfx.play("shoot")


## Le Paon : toutes les 10 s, fait la roue ; les ennemis proches (pas les boss) sont charmés 3 s.
func _paon(delta: float) -> void:
	if state == "roue":
		st_t -= delta
		if st_t <= 0.0:
			state = "walk"
		return
	_wander(delta, 70.0)
	if cd > 0.0 or arena.nearest(position, PAON_R) == null:
		return
	cd = fcd(10.0)
	state = "roue"
	st_t = 0.8
	var n := 0
	for e in arena.near(position, PAON_R):
		if arena.charm(e, 3.0):
			n += 1
	if n > 0:
		arena.float_text(position + Vector2(0, -20), Loc.t("CHARMÉS !"), Color("f08ac0"))
		Sfx.play("level")
	_action()


func _oiseau(delta: float) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		target = _called() if _called() else arena.nearest(position, 300.0)
		if target == null:
			_wander(delta, 120.0)
			return
		perch = Vector2.from_angle(randf() * TAU)
	# Il vole jusqu'à l'ennemi, se pose contre lui et le picore (petit coup de tête vers lui)
	var spot: Vector2 = target.position + perch * (target.radius + 4.0)
	position = position.move_toward(spot, 260.0 * _speed() * delta)
	var to_e: Vector2 = target.position - position
	_sitflip(to_e.x)
	peck_t = maxf(0.0, peck_t - delta)
	sprite.position = Vector2(0.0, sprite.position.y) + to_e.normalized() * 3.0 * sin(peck_t / 0.15 * PI)
	if cd <= 0.0 and position.distance_to(spot) < 6.0:
		cd = fcd(0.6)
		peck_t = 0.15
		hit(target, fdmg(bird_dmg, 0.0), to_e.normalized() * 20.0)
		_action()
		arena.burst(target.position - to_e.normalized() * target.radius, Pal.INK, 3, 50.0)


func _coin(at: Vector2, k: int) -> void:
	var glow := 0.5 + 0.5 * sin(t * 8.0 + k)
	draw_circle(at, 4.0 + glow, Color(Pal.ACCENT, 0.25))
	draw_circle(at, 2.6, Pal.INK)
	draw_circle(at, 2.0, Pal.ACCENT)
	if glow > 0.7:
		draw_line(at + Vector2(-4, 0), at + Vector2(4, 0), Color(1, 1, 1, 0.8), 1.0)
		draw_line(at + Vector2(0, -4), at + Vector2(0, 4), Color(1, 1, 1, 0.8), 1.0)


## Pie : va chercher les pièces brillantes et te les rapporte.
func _pie(delta: float) -> void:
	if fetch.is_empty():
		_wander(delta, 110.0)
		return
	var p := arena.player
	var dest: Vector2 = p.position + Vector2(0, -6) if carry else fetch[0].pos
	position = position.move_toward(dest, 190.0 * _speed() * delta)
	_sitflip(dest.x - position.x)
	if position.distance_to(dest) > 5.0:
		return
	if not carry:
		carry = true
		arena.burst(position, Pal.ACCENT, 4, 40.0)
		return
	_give(fetch.pop_front().v)
	carry = false


func _give(v: int) -> void:
	Run.gold += v
	arena.burst(arena.player.position, Pal.ACCENT, 12, 110.0)
	arena.float_text(arena.player.position + Vector2(0, -22), Loc.t("+%d OR") % v, Pal.ACCENT)
	Sfx.play("coin")
	_action()


## Fin de vague : la Pie te donne les pièces qu'elle n'a pas eu le temps de rapporter.
func _exit_tree() -> void:
	_exit_tree_luciole()
	for f in fetch:
		Run.gold += int(f.v)
	fetch.clear()


## Perroquet : prend ton dessin d'arme de mêlée et refait son geste (estoc, balayage, fauchage,
## coup d'écrasement) depuis là où il est, avec les dégâts de l'arme. Il ne bouge pas pendant le coup.
func _start_copy(wn: WeaponNode, e: Enemy) -> void:
	var dir := (e.position - position).normalized()
	var reach: float = wn.st.reach
	copy = {"st": wn.st, "t": 0.0, "angle": dir.angle(), "reach": reach, "len": wn.length, "hits": {},
		"slam": position + dir * minf(position.distance_to(e.position), reach), "slammed": false}
	copy_spr = Gfx.sprite(wn.own_tex, wn.sprite.material)
	copy_spr.modulate = Color(0.8, 1.0, 0.75)   # (teinte verte du perroquet : on voit que c'est une copie)
	copy_spr.z_index = 1
	add_child(copy_spr)
	_sitflip(dir.x)
	Sfx.play("swing")


func _copy_step(delta: float) -> void:
	var st: Dictionary = copy.st
	copy.t += delta / WeaponNode.swing_dur(st)
	var tt := clampf(float(copy.t), 0.0, 1.0)
	var pose := WeaponNode.swing_pose(st.style, tt, Vector2.ZERO, copy.angle, copy.reach, copy.len, copy.slam - position)
	copy_spr.position = pose[0]
	copy_spr.rotation = pose[1]
	copy_spr.flip_v = cos(pose[1]) < 0.0
	match st.style:
		"spin":
			if tt > 0.04 and tt < 0.96:
				# toute la lame coupe, du perroquet à la pointe
				var d := Vector2.from_angle(pose[1])
				var to: Vector2 = position + d * float(pose[3])
				for e in arena.near((position + to) / 2.0, position.distance_to(to) / 2.0 + st.hit_r + 14.0):
					if Geometry2D.get_closest_point_to_segment(e.position, position, to).distance_to(e.position) <= st.hit_r * 0.8 + e.radius:
						_copy_hit(e, d, 1.0)
		"slam", "stamp":
			if tt >= 0.6 and not copy.slammed:
				copy.slammed = true
				var r: float = arena.boom(float(st.aoe))
				arena.explosion(copy.slam, r, Color("5ec04a", 0.6))
				for e in arena.near(copy.slam, r):
					_copy_hit(e, (e.position - copy.slam).normalized(), 1.5)
		_:
			if pose[2]:
				var tip: Vector2 = position + pose[0] + Vector2.from_angle(pose[1]) * float(copy.len) * 0.3
				for e in arena.near(tip, st.hit_r):
					_copy_hit(e, Vector2.from_angle(pose[1]), 1.0)
	if copy.t >= 1.0:
		_end_copy()


## Un ennemi touché par le coup copié (une fois par coup), avec les dégâts de l'arme.
func _copy_hit(e: Enemy, dir: Vector2, knock_mult: float) -> void:
	var id_e := e.get_instance_id()
	if copy.hits.has(id_e):
		return
	copy.hits[id_e] = true
	var st: Dictionary = copy.st
	var h0: float = e.hp
	arena.hit_enemy(e, float(st.get("damage", 5.0)), st, dir, float(st.get("knock", 30.0)) * knock_mult)
	arena.fam_credit(id, h0 - maxf(0.0, e.hp))
	if e.dead:
		on_kill()


func _end_copy() -> void:
	copy = {}
	if copy_spr:
		copy_spr.queue_free()
		copy_spr = null


## Perroquet : se balade partout sur la page et répète une de tes armes.
func _perroquet(delta: float) -> void:
	if not copy.is_empty():
		_copy_step(delta)
		return
	if position.distance_to(goal) < 8.0:
		goal = Vector2(randf_range(30.0, Arena.W - 30.0), randf_range(30.0, Arena.H - 30.0))
	position = position.move_toward(goal, 85.0 * _speed() * delta)
	_sitflip(goal.x - position.x)
	if cd > 0.0:
		return
	var wns: Array = arena.player.weapons.filter(func(w): return is_instance_valid(w))
	var e := arena.nearest(position, 220.0)
	if wns.is_empty() or e == null:
		return
	cd = fcd(2.0)
	var wn: WeaponNode = wns.pick_random()
	var st: Dictionary = wn.st
	var dir := (e.position - position).normalized()
	arena.float_text(position + Vector2(0, -14), Loc.t("COPIÉ !"), Color("5ec04a"))
	_action()
	if st.kind == "ranged" and not st.get("bullets", []).is_empty() and not wn.bullet_tex.is_empty():
		var b: Dictionary = st.bullets[0]
		var sp: float = maxf(120.0, float(b.speed))
		arena.spawn_bullet(position + dir * 6.0, dir * sp, b, st, wn.bullet_tex[0], wn.art.get("beffect", ""),
			280.0 / sp, wn.art.get("boutline", false))
		Sfx.play("shoot")
	elif st.kind == "melee" and st.style in WeaponNode.SWING_STYLES:
		_start_copy(wn, e)
	else:
		# autre arme (Compas...) : il fonce donner un coup de bec avec
		position = e.position - dir * 8.0
		line_to = e.position
		line_t = 0.12
		line_col = Color("5ec04a")
		var h0: float = e.hp
		arena.hit_enemy(e, float(st.get("damage", 5.0)), st, dir, float(st.get("knock", 30.0)))
		arena.fam_credit(id, h0 - maxf(0.0, e.hp))
		arena.burst(e.position, Color("5ec04a"), 6, 70.0)
		if e.dead:
			on_kill()
