class_name WeaponNode
extends Node2D
## Une arme dessinée, posée à un endroit choisi sur le perso, qui attaque toute seule
## l'ennemi le plus proche. Le type d'arme décide COMMENT elle attaque :
## mêlée  : thrust (estoc), sweep (arc), spin (tour complet), slam (onde de choc)
## distance : shot, spread (éventail), homing (tête chercheuse), lob (obus explosif)
## spéciales (épiques+) : trail (Pinceau), orbit (Compas), stamp (Tampon)
## légendaires : erase (Gomme sacrée), prism (Palette vivante), clone (Autoportrait)

var player: Player
var w: Dictionary
var st: Dictionary
var art: Dictionary
var cd := 0.0
var sprite: Sprite2D
var length := 16.0
var attacking := false
var atk_t := 0.0
var atk_dir := Vector2.RIGHT
var atk_angle := 0.0
var slam_point := Vector2.ZERO
var slam_done := false
var hit_ids := {}
var aim := 0.0
var recoil := 0.0
var bullet_tex: Array = []
var own_tex: Texture2D
var stamp_mask: Image       # Tampon : le dessin agrandi, sert de zone de dégâts
var stamp_ghost: Image      # ... et de trace au sol
var stamp_tex: Texture2D
var orbs: Array = []        # Palette vivante : un orbe par couleur {tex, wst, mult}
var clone_tex: Texture2D    # Autoportrait
var orbit_a := 0.0
var orbit_hits := {}
var paint_last := Vector2.INF
var trail: Line2D            # traînée du coup (coordonnées du monde)
var trail_pts: Array = []
var heat := 0                # Crayon HB : coups donnés pendant la vague
var beam: Line2D             # Loupe : le rayon
var beam_target: Enemy
var beam_t := 0.0
var beam_acc := 0.0
var beam_wst := {}
var special_t := 0.0
var atk_n := 0               # Métronome : attaques données
var metro := 1.0             # ×2,5 sur l'attaque en cours         # Miroir déformant / Grande Signature : minuterie


func setup(p: Player, weapon: Dictionary) -> void:
	player = p
	w = weapon
	st = weapon.st
	art = Run.art_of(w)
	# En combat on utilise le dessin D'ORIGINE : son côté droit est la pointe / le canon, qui vise
	# l'ennemi. La rotation / le miroir choisis au rangement ne servent que pour la pose au repos.
	var trimmed := Analyzer.trim(art.image)
	length = trimmed.get_width()
	own_tex = Gfx.texture(trimmed)
	sprite = Gfx.sprite(own_tex, Gfx.material(art.effect, art.get("outline", false)))
	add_child(sprite)
	z_index = 1
	cd = randf() * st.cooldown
	if st.kind == "ranged":
		for b in st.bullets:
			bullet_tex.append(Gfx.texture(WeaponDB.orb(Pal.SHADES[2][1]) if st.style == "mist" else b.image))
	match st.style:
		"stamp":
			var sc: float = 2.0 * Stats.RAR_REACH[w.rar]
			stamp_mask = trimmed.duplicate()
			stamp_mask.resize(maxi(1, roundi(trimmed.get_width() * sc)), maxi(1, roundi(trimmed.get_height() * sc)), Image.INTERPOLATE_NEAREST)
			stamp_tex = Gfx.texture(stamp_mask)
			stamp_ghost = stamp_mask.duplicate()
			for y in stamp_ghost.get_height():
				for x in stamp_ghost.get_width():
					var c := stamp_ghost.get_pixel(x, y)
					if c.a > 0.0:
						stamp_ghost.set_pixel(x, y, Color(c, c.a * 0.4))
		"prism":
			var frac: Array = art.a.frac
			for el in Pal.COUNT:
				if frac[el] < 0.04:
					continue
				var f := []
				f.resize(Pal.COUNT)
				f.fill(0.0)
				var wst := st.duplicate()
				if el > 0:
					f[el] = 1.0   # effet élémentaire garanti
				wst.frac = f
				orbs.append({"tex": Gfx.texture(WeaponDB.orb(Pal.main_color(el) if el > 0 else Pal.INK)), "wst": wst,
					"mult": 1.0 if el > 0 else 1.3})
			if orbs.is_empty():
				orbs.append({"tex": bullet_tex[0], "wst": st, "mult": 1.3})
		"clone":
			clone_tex = Gfx.texture(Analyzer.trim(Run.build_player_image()))
		"orbit":
			orbit_a = randf() * TAU
	position = _home()
	if st.kind == "melee":
		trail = Line2D.new()
		trail.top_level = true
		trail.width = 4.0
		trail.z_index = 2
		var el := Run.weapon_element(w)
		var tc: Color = Pal.main_color(el) if el > 0 else Color.WHITE
		var g := Gradient.new()
		g.set_color(0, Color(tc, 0.0))
		g.set_color(1, Color(tc, 0.55))
		trail.gradient = g
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(trail)


## Position choisie par le joueur sur son perso (suit le perso quand il se retourne).
func _home() -> Vector2:
	var a: Vector2 = w.anchor
	return Vector2(a.x * player.body.scale.x, a.y) + player.body.position


## Pose au repos (aucun ennemi à portée) : celle choisie au rangement, en miroir quand le perso
## regarde à gauche.
func _rest_pose() -> void:
	var left := player.body.scale.x < 0.0
	var rest := float(w.get("rot", 0)) * PI / 2.0
	var target_rot := PI - rest if left else rest
	var fl: bool = w.get("flip", false)
	rotation = lerp_angle(rotation, target_rot, 0.25)
	aim = rotation
	# Miroir gauche/droite de la pose = pivoter de 180° (PI - rest) et retourner verticalement.
	sprite.flip_h = fl
	sprite.flip_v = left


func _atk_mult() -> float:
	var m: float = 1.0 + player.st.atk_speed / 100.0
	if player.arena.elapsed < 10.0:
		m += 0.6 * Run.amulet_count("croquis_rapide")
	m += 0.03 * player.arena.fly_n * Run.amulet_count("papillon")   # Effet papillon
	m += player.arena.dynamo_bonus()   # Dynamo
	m += player.arena.combo_bonus()    # Combo
	if player.arena.stream:
		m += player.arena.stream.atk_bonus()   # Le Stream : HYPE TRAIN
	return maxf(0.2, m)


func _range_mult() -> float:
	var r: float = 1.0 + player.st.range / 100.0
	if st.kind == "melee":
		r += 0.3 * Run.amulet_count("ressort")   # Ressort
		r += 0.1 * Run.amulet_count("perche_selfie")   # Perche à selfie
	return r


func tick(delta: float) -> void:
	var arena := player.arena
	cd -= delta * _atk_mult() * (2.0 if Run.amulet_count("boisson") > 0 else 1.0)   # (Boisson énergisante)
	_update_trail()
	if st.style == "orbit":
		_orbit_step(delta)
		return
	if st.style == "mirror" or st.style == "signature":
		_special_step(delta)
		return
	var home := _home()
	var rng: float
	if st.kind == "melee":
		rng = st.reach * _range_mult() + 10.0
		if st.style == "spin":
			rng = st.reach * _range_mult() * 0.9
	else:
		rng = st.range * _range_mult()
	var origin := player.position + home
	var target: Enemy = arena.nearest(origin, rng)

	if attacking:
		_melee_step(delta)
		return

	position = position.lerp(home, 0.5)
	if target:
		var want := (target.position - origin).angle()
		if Run.amulet_count("pinceau_fou") > 0:
			want = randf() * TAU
		aim = lerp_angle(aim, want, 0.3)
		rotation = aim
		sprite.flip_h = false
		sprite.flip_v = cos(aim) < 0.0   # visée à gauche : miroir pour garder l'arme à l'endroit
	else:
		_rest_pose()
	recoil = lerpf(recoil, 0.0, 0.25)
	sprite.position.x = -recoil
	if st.style == "beam":
		_beam_step(delta, target)
		return

	if cd <= 0.0 and target:
		cd = st.cooldown
		# Métronome : une attaque sur 5 fait ×2,5 (1 sur 4 avec deux, 1 sur 3 avec trois...)
		atk_n += 1
		var metro_n := Run.amulet_count("metronome")
		metro = 2.5 if metro_n > 0 and atk_n % maxi(2, 6 - metro_n) == 0 else 1.0
		if metro > 1.0:
			arena.float_text(player.position + position + Vector2(0, -14), "×2,5", Pal.ACCENT)
		# Double exposition : l'attaque se relance aussitôt
		if Run.amulet_count("double_expo") > 0 and randf() < 0.25:
			cd = 0.06
		if st.kind == "melee":
			_start_melee(target)
		else:
			_fire(target)


# ------------------------------------------------------------------ Mêlée

func _start_melee(target: Enemy) -> void:
	attacking = true
	atk_t = 0.0
	slam_done = false
	hit_ids.clear()
	var origin := player.position + _home()
	atk_dir = (target.position - origin).normalized()
	atk_angle = atk_dir.angle()
	var reach: float = st.reach * _range_mult()
	slam_point = origin + atk_dir * minf(origin.distance_to(target.position), reach)
	paint_last = Vector2.INF
	sprite.flip_h = false
	Sfx.play("swing")
	if st.style == "erase":
		_erase_line(origin)
	var dt := Run.amulet_count("double_trait")
	for i in dt:
		var a := atk_angle + (i - (dt - 1) / 2.0) * 0.25
		var p := player.arena.spawn_bullet(origin, Vector2.from_angle(a) * 260.0,
			{"damage": st.damage * 0.6, "radius": st.hit_r, "pierce": 2}, st, own_tex, art.effect, 1.2, art.get("outline", false))
		p.spin = 12.0


## Gestes de mêlée que le Perroquet sait copier (les autres styles ont leur propre mécanique).
const SWING_STYLES := ["thrust", "erase", "scissors", "pencil", "sweep", "trail", "gust", "spin", "slam", "stamp"]


## Durée d'un coup de mêlée (s), avant la vitesse d'attaque. (Aussi utilisée par le Perroquet.)
static func swing_dur(wst: Dictionary) -> float:
	var dur := 0.3
	match wst.style:
		"spin":
			dur = 0.55
		"gust":
			dur = 0.4
		"slam", "stamp":
			dur = 0.5
		"erase":
			dur = 0.35
	dur *= clampf(wst.cooldown / 0.6, 0.35, 1.0)   # petites armes rapides = coups plus vifs
	dur *= float(wst.get("atk_dur", 1.0))          # Lance : estoc sec, revient vite
	return dur


## Pose de l'arme à l'instant t (0 à 1) d'un coup, par rapport à son porteur :
## [position, rotation, la pointe touche ?, allonge de la Faux]. (Aussi utilisée par le Perroquet.)
static func swing_pose(style: String, t: float, home: Vector2, angle: float, reach: float, len: float, slam_local: Vector2) -> Array:
	match style:
		"sweep", "trail", "gust":
			var a := angle - 1.2 + 2.4 * t
			var ext := sin(t * PI)
			return [home * (1.0 - ext) + (home + Vector2.from_angle(a) * reach * 0.75) * ext, a, ext > 0.25, 0.0]
		"spin":
			# Faux : grand fauchage. La lame part près du corps, s'ouvre en spirale jusqu'à
			# pleine allonge et fait 1 tour 1/4 (accélère puis freine) ; TOUTE la lame coupe.
			var k := t * t * (3.0 - 2.0 * t)
			var a := angle - 0.6 + TAU * 1.25 * k
			var open := minf(1.0, t * 2.5)
			var close := clampf((t - 0.85) / 0.15, 0.0, 1.0)
			var rr := reach * (0.4 + 0.6 * open) * (1.0 - 0.5 * close)
			return [Vector2.from_angle(a) * maxf(4.0, rr - len * 0.5), a, false, rr]
		"slam", "stamp":
			# Monte, fonce sur le point d'impact (atteint à t = 0,6), puis revient
			if t < 0.6:
				var k := t / 0.6
				return [home.lerp(slam_local, k * k) + Vector2(0, -sin(k * PI) * 18.0), angle - 1.4 * (1.0 - k), false, 0.0]
			return [slam_local.lerp(home, (t - 0.6) / 0.4), angle, false, 0.0]
	# estoc (thrust, erase, scissors, pencil)
	var ext := sin(t * PI)
	return [home * (1.0 - ext) + (home + Vector2.from_angle(angle) * reach) * ext, angle, ext > 0.35 and style != "erase", 0.0]


func _melee_step(delta: float) -> void:
	atk_t += delta / (swing_dur(st) / sqrt(_atk_mult()))
	var t := clampf(atk_t, 0.0, 1.0)
	var reach: float = st.reach * _range_mult()
	if st.style in ["slam", "stamp"] and t >= 0.6 and not slam_done:
		slam_done = true
		if st.style == "stamp":
			_stamp_impact()
		else:
			_slam_impact()
	var pose := swing_pose(st.style, t, _home(), atk_angle, reach, length, slam_point - player.position)
	position = pose[0]
	rotation = pose[1]
	var hit_on: bool = pose[2]
	if st.style == "spin" and t > 0.04 and t < 0.96:
		_reap(rotation, pose[3])
	sprite.flip_v = cos(rotation) < 0.0
	if hit_on:
		var tip := player.position + position + Vector2.from_angle(rotation) * length * 0.3
		for e in player.arena.near(tip, st.hit_r):
			var id: int = e.get_instance_id()
			if hit_ids.has(id):
				continue
			hit_ids[id] = true
			var d: float = st.damage
			var kb: float = st.knock
			if st.style == "pencil":
				d *= 1.0 + minf(1.5, 0.03 * heat)   # Crayon HB : s'échauffe
				heat += 1
			elif st.style == "gust":
				kb *= 5.0   # Éventail : repousse très fort
			d *= metro
			kb *= 1.0 + Run.amulet_count("ressort")
			player.arena.hit_enemy(e, d, st, Vector2.from_angle(rotation), kb)
		if st.style == "trail":
			_paint(tip)
	if atk_t >= 1.0:
		attacking = false
		aim = rotation


## Faux : tout le segment du perso à la pointe coupe ; chaque ennemi une fois par coup.
func _reap(a: float, rr: float) -> void:
	var arena := player.arena
	var dir := Vector2.from_angle(a)
	var from := player.position + dir * 6.0   # du perso (le manche) jusqu'à la pointe
	var to := player.position + dir * rr
	var mid := (from + to) / 2.0
	for e in arena.near(mid, from.distance_to(to) / 2.0 + st.hit_r + 14.0):
		var id: int = e.get_instance_id()
		if hit_ids.has(id):
			continue
		if Geometry2D.get_closest_point_to_segment(e.position, from, to).distance_to(e.position) > st.hit_r * 0.8 + e.radius:
			continue
		hit_ids[id] = true
		# projeté vers l'extérieur, un peu dans le sens de la rotation
		var push: Vector2 = ((e.position - player.position).normalized() + dir.orthogonal() * 0.5).normalized()
		arena.hit_enemy(e, st.damage * metro, st, push, st.knock * (1.0 + Run.amulet_count("ressort")))


func _slam_impact() -> void:
	var arena := player.arena
	var r: float = arena.boom(st.aoe * _range_mult())
	arena.explosion(slam_point, r, Color(Pal.INK, 0.7))
	arena.shake(4.0)
	for e in arena.near(slam_point, r):
		arena.hit_enemy(e, arena.boom_dmg(st.damage), st, (e.position - slam_point).normalized(), st.knock * 1.5)


## Traînée : la pointe laisse un sillage pendant les coups (et le Compas en permanence).
func _update_trail() -> void:
	if trail == null:
		return
	var active: bool = attacking or st.style == "orbit"
	if active:
		trail_pts.append(global_position + Vector2.from_angle(global_rotation) * length * 0.45)
		while trail_pts.size() > (10 if st.style == "orbit" else 7):
			trail_pts.pop_front()
	elif not trail_pts.is_empty():
		trail_pts.pop_front()
	trail.points = PackedVector2Array(trail_pts)


## Pinceau : dépose des flaques d'encre amies le long du coup.
func _paint(tip: Vector2) -> void:
	if tip.distance_to(paint_last) < st.hit_r * 0.8:
		return
	paint_last = tip
	player.arena.add_zone(tip, st.hit_r * 0.9, 2.5, st.damage * 0.7, Run.weapon_element(w))


## Compas : tourne en permanence autour du perso et coupe tout ce qu'il croise.
func _orbit_step(delta: float) -> void:
	var arena := player.arena
	var period := 0.9 * clampf(st.cooldown / 0.85, 0.5, 1.4) / _atk_mult()
	orbit_a = wrapf(orbit_a + TAU * delta / period, 0.0, TAU)
	var r: float = st.reach * _range_mult() * 0.75
	# Centré sur le perso (et pas sur l'endroit où l'arme est posée, qui passe en miroir
	# quand le perso se retourne) : le cercle ne saute pas en changeant de direction.
	position = Vector2.from_angle(orbit_a) * r
	rotation = orbit_a + PI / 2.0
	sprite.flip_v = false
	sprite.flip_h = false
	var now := arena.elapsed
	var tip := player.position + position
	for e in arena.near(tip, st.hit_r + length * 0.3):
		var id: int = e.get_instance_id()
		if now - float(orbit_hits.get(id, -99.0)) < period * 0.5:
			continue
		orbit_hits[id] = now
		arena.hit_enemy(e, st.damage, st, Vector2.from_angle(orbit_a), st.knock * 0.5)
	if orbit_hits.size() > 300:
		orbit_hits.clear()


## Tampon : le dessin (agrandi) s'imprime au sol. Seuls les ennemis SOUS l'encre prennent le coup.
func _stamp_impact() -> void:
	var arena := player.arena
	var sz := Vector2(stamp_mask.get_size())
	var top := slam_point - sz / 2.0
	arena.stamp_floor(stamp_ghost, top)
	arena.flash_image(stamp_tex, slam_point)
	arena.shake(5.0)
	Sfx.play("explode")
	for e in arena.near(slam_point, sz.length() / 2.0 + 16.0):
		if _under_ink(e.position - top, e.radius):
			arena.hit_enemy(e, st.damage * 1.5, st, (e.position - slam_point).normalized(), st.knock * 1.5)


func _under_ink(p: Vector2, r: float) -> bool:
	for o in [Vector2.ZERO, Vector2(r * 0.7, 0), Vector2(-r * 0.7, 0), Vector2(0, r * 0.7), Vector2(0, -r * 0.7)]:
		var q := Vector2i(p + o)
		if q.x >= 0 and q.y >= 0 and q.x < stamp_mask.get_width() and q.y < stamp_mask.get_height() and stamp_mask.get_pixelv(q).a > 0.5:
			return true
	return false


## Gomme sacrée : un long trait de gomme. Les ennemis touchés peuvent être EFFACÉS d'un coup.
func _erase_line(origin: Vector2) -> void:
	var arena := player.arena
	var a := origin
	var b: Vector2 = origin + atk_dir * st.reach * _range_mult() * 1.7
	var width: float = st.hit_r * 0.55
	arena.erase_stroke(a, b, width)
	for e in arena.near((a + b) / 2.0, a.distance_to(b) / 2.0 + 24.0):
		if e.dead:
			continue
		if Geometry2D.get_closest_point_to_segment(e.position, a, b).distance_to(e.position) > width + e.radius:
			continue
		if e.is_boss:
			e.hurt(e.max_hp * 0.03, false, Vector2.ZERO)
			arena.hit_enemy(e, st.damage * 1.5, st, atk_dir, 0.0)
		elif randf() < (0.15 if e.elite else 0.3):
			arena.float_text(e.position + Vector2(0, -12), Loc.t("EFFACÉ"), Pal.TEXT)
			e.hurt(e.hp + 1.0, true, Vector2.ZERO)
		else:
			e.hurt(e.max_hp * 0.25, false, Vector2.ZERO)
			arena.hit_enemy(e, st.damage, st, atk_dir, st.knock)


# ------------------------------------------------------------------ Distance

func _fire(target: Enemy) -> void:
	var arena := player.arena
	if st.style == "prism":
		_fire_prism()
		return
	if st.style == "clone":
		_fire_clone()
		return
	if st.style == "cage":
		var bc: Dictionary = st.bullets[0]
		arena.add_bird(bullet_tex[0], art.beffect, art.get("boutline", false), bc.damage, st.get("frac", []))
		recoil = 3.0
		Sfx.play("shoot")
		return
	if st.style == "well":
		var b: Dictionary = st.bullets[0]
		arena.add_well(target.position, 70.0 * _range_mult(), b.damage * 3.0, st)
		recoil = 3.0
		Sfx.play("shoot")
		return
	var copies := 1 + Run.amulet_count("miroir")
	var muzzle := player.position + position + Vector2.from_angle(aim) * length * 0.5
	var base := aim + deg_to_rad(randf_range(-st.spread, st.spread))
	var life_range: float = st.range * _range_mult()
	var pellets: int = st.pellets
	for c in copies:
		for k in pellets:
			var a := base + (c - (copies - 1) / 2.0) * 0.2 + (k - (pellets - 1) / 2.0) * 0.28
			for i in st.bullets.size():
				var b: Dictionary = st.bullets[i]
				var off: Vector2 = b.center.rotated(a)
				var life: float = life_range / b.speed
				if st.style == "lob":
					life = clampf(muzzle.distance_to(target.position) / b.speed, 0.15, life)
				var p := arena.spawn_bullet(muzzle + off, Vector2.from_angle(a) * b.speed, b, st, bullet_tex[i],
					art.beffect, life, art.get("boutline", false))
				p.dmg *= metro
				if st.style == "homing":
					p.homing = true
				elif st.style == "boomerang":
					p.boomerang = true
					p.out_t = life * 0.5
					p.life = 10.0
					p.pierce = 999
				elif st.style == "mist":
					p.life = life * 0.45
				elif st.style == "lob":
					p.lob_r = 16.0 + b.radius * 2.5
	recoil = 4.0
	arena.burst(muzzle, Color(1, 0.95, 0.8), 3, 70.0, Vector2.from_angle(aim), 0.5)   # éclat au canon
	Sfx.play("shoot")


## Loupe : rayon continu sur la cible ; plus il y reste, plus il brûle (×1 → ×4 en 3 s).
func _beam_step(delta: float, target: Enemy) -> void:
	var arena := player.arena
	if beam == null:
		beam = Line2D.new()
		beam.top_level = true
		beam.z_index = 3
		beam.width = 2.0
		beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(beam)
		beam_wst = st.duplicate()
		var f: Array = (st.frac as Array).duplicate()
		for i in f.size():
			f[i] *= 0.15   # beaucoup de petits coups : moins de chances d'effet par coup
		beam_wst.frac = f
	if target == null:
		beam.visible = false
		beam_target = null
		beam_t = 0.0
		return
	if target != beam_target:
		beam_target = target
		beam_t = 0.0
	beam_t += delta
	var ramp := 1.0 + minf(3.0, beam_t)
	var from := player.position + position + Vector2.from_angle(aim) * length * 0.5
	beam.visible = true
	beam.points = PackedVector2Array([from, target.position])
	beam.width = 1.5 + ramp
	beam.default_color = Color(1.0, 1.0 - 0.15 * ramp, 0.6 - 0.12 * ramp, 0.85)
	beam_acc += delta * _atk_mult()
	while beam_acc >= 0.1:
		beam_acc -= 0.1
		var b: Dictionary = st.bullets[0]
		arena.hit_enemy(target, b.damage / st.cooldown * 0.1 * ramp * 0.6, beam_wst, Vector2.ZERO, 0.0)
		if target.dead:
			break


## Miroir déformant (onde qui renvoie les tirs) et Grande Signature (trait géant) : pas de cible.
func _special_step(delta: float) -> void:
	var arena := player.arena
	position = position.lerp(_home(), 0.5)
	_rest_pose()
	special_t -= delta * _atk_mult()
	if special_t > 0.0:
		return
	var b: Dictionary = st.bullets[0]
	if st.style == "mirror":
		special_t = 2.0
		var r := 90.0 * _range_mult()
		var n := 0
		for p in arena.bullets:
			if not p.hostile or p.position.distance_to(player.position) > r:
				continue
			var tg: Enemy = arena.nearest(p.position, 500.0)
			var dir := (tg.position - p.position).normalized() if tg else -p.vel.normalized()
			p.hostile = false
			p.hang = 0.0
			p.wst = st
			p.dmg = maxf(p.dmg * 3.0, b.damage * 1.5)
			p.pierce = 1
			p.hit_ids.clear()
			p.vel = dir * maxf(p.vel.length(), 220.0)
			n += 1
		arena.explosion(player.position, r, Color(0.8, 0.9, 1.0, 0.5), true)
		if n > 0:
			arena.float_text(player.position + Vector2(0, -26), Loc.t("RENVOI ×%d") % n, Color(0.8, 0.9, 1.0))
	else:
		special_t = 5.0
		var mult := 1.0 + Run.kills * 0.004   # plus fort avec les ennemis tués dans la partie
		# Passe à la hauteur d'un des ennemis les plus proches (sinon près de toi)
		var y := player.position.y + randf_range(-40.0, 40.0)
		var close := arena.enemies.filter(func(e): return not e.dead and e.position.distance_to(player.position) < 220.0)
		if not close.is_empty():
			y = (close.pick_random() as Enemy).position.y
		arena.signature(y, b.damage * 4.0 * mult, st, null if bullet_tex.is_empty() else bullet_tex[0])


## Palette vivante : un orbe chercheur par couleur du dessin, avec son effet garanti.
func _fire_prism() -> void:
	var arena := player.arena
	var b: Dictionary = st.bullets[0]
	var muzzle := player.position + position + Vector2.from_angle(aim) * length * 0.5
	var n := orbs.size()
	for i in n:
		var o: Dictionary = orbs[i]
		var a := aim + (i - (n - 1) / 2.0) * 0.4
		var bb := {"damage": b.damage * o.mult, "radius": b.radius, "pierce": b.pierce}
		var p := arena.spawn_bullet(muzzle, Vector2.from_angle(a) * b.speed, bb, o.wst, o.tex, "", st.range * _range_mult() / b.speed)
		p.homing = true
	recoil = 3.0
	Sfx.play("shoot")


## Autoportrait : un clone du perso court vers l'ennemi et explose.
func _fire_clone() -> void:
	var arena := player.arena
	var b: Dictionary = st.bullets[0]
	var bb := {"damage": b.damage, "radius": maxf(6.0, player.radius), "pierce": 0}
	var p := arena.spawn_bullet(player.position + position, Vector2.from_angle(aim) * maxf(90.0, b.speed), bb, st, clone_tex,
		Run.char_effect, 4.0, Run.char_outline)
	p.homing = true
	p.upright = true
	p.burst_r = 34.0 + player.radius * 2.0
	Sfx.play("shoot")
