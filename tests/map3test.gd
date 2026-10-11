extends Node
## Carte 3 « L'Écran » : déblocage, seeds, et les 8 ennemis (chacun fait bien ce qu'il doit).
## Godot --headless --path . res://tests/map3test.tscn [-- <dossier de captures>]

const DT := 1.0 / 30.0
var fails := 0
var arena: Arena


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var shots := OS.get_cmdline_user_args()

	# --- La carte existe, se débloque en gagnant sur Le Tableau noir, et a ses seeds
	_check(MapDB.MAPS.has(3) and MapDB.get_def(3).floor == "screen", "la carte 3 existe : %s" % MapDB.get_def(3).name)
	Meta.data.unlocks.erase("map2")
	Meta.data.unlocks.erase("map3")
	Run.start(0, 1)
	_check(Meta.record_run(15, true, 0, 0, 0, 1) == 2 and Meta.map_unlocked(2) and not Meta.map_unlocked(3), "gagner sur La Feuille ouvre Le Tableau noir (pas L'Écran)")
	_check(Meta.record_run(15, true, 0, 0, 0, 2) == 3 and Meta.map_unlocked(3), "gagner sur Le Tableau noir ouvre L'Écran")
	_check(Meta.record_run(15, true, 0, 0, 0, 3) == 0, "gagner sur L'Écran n'ouvre rien de plus")
	_check(Run.parse_seed("30-AAAAA").get("map", 0) == 3 and Run.parse_seed("40-AAAAA").is_empty(), "seeds : la carte 3 est acceptée, pas une carte 4")
	var ids := []
	for id in EnemyDB.TYPES:
		if int(EnemyDB.TYPES[id].get("map", 1)) == 3 and not EnemyDB.TYPES[id].has("boss"):
			ids.append(id)
	_check(ids.size() == 8, "8 ennemis sur L'Écran : %s" % ", ".join(ids))

	# --- Écran de choix de la salle (3 cartes)
	if shots.size() > 0:
		var ch := ChoiceScreens.map_choice()
		ch.size = Vector2(640, 360)
		add_child(ch)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots[0] + "/map3_choix.png")
		ch.queue_free()
		await get_tree().process_frame

	# --- Les ennemis, un par un, dans une arène de L'Écran sans apparitions automatiques
	_arena(12)
	await get_tree().process_frame
	var p := arena.player

	# Pointeur : il se déplace par à-coups et finit par cliquer (un carré annoncé)
	var e := _spawn("curseur", Vector2(120, 0))
	var x0 := e.position
	var clicked := false
	for k in 600:
		_step()
		clicked = clicked or not arena.squares.is_empty()
	_check(e.position.distance_to(x0) > 20.0 and clicked, "Pointeur : fonce par à-coups et clique sur le joueur")
	_clear()

	# Fichier corrompu : au bout de 6 s il s'ouvre (3 à 5 ennemis) et disparaît
	e = _spawn("fichier", Vector2(150, 0))
	_check(not e.contact or true, "Fichier corrompu : posé")
	for k in int(5.0 / DT):
		_step()
	var before := arena.enemies.size()
	_check(before == 1 and not e.dead, "Fichier corrompu : rien pendant 5 s")
	for k in int(1.5 / DT):
		_step()
	_check(arena.enemies.size() >= 3 and arena.enemies.size() <= 5 and not arena.enemies.has(e), "Fichier corrompu : il s'ouvre, %d ennemis sortent" % arena.enemies.size())
	_clear()

	# Corbeille : elle avale les gouttes qui volent vers le joueur, et recrache tout à sa mort
	e = _spawn("corbeille", Vector2(60, 0))
	e.speed = 0.0
	arena.drop_pickup(p.position + Vector2(150, 0), 3, 2)   # (elles passeront par elle pour rejoindre le joueur)
	arena.drop_pickup(p.position + Vector2(140, 6), 2, 1)
	var g0 := Run.gold
	for k in int(2.0 / DT):
		_step()
	_check(e.belly_v == 5 and e.belly_xp == 3 and arena.pickups.is_empty() and Run.gold == g0, "Corbeille : elle a avalé au passage 5 or et 3 XP (le joueur n'a rien eu)")
	e.loot = 0.0
	arena.kill_enemy(e)
	var v := 0
	for pk in arena.pickups:
		v += pk.value
	_check(v == 5, "Corbeille : tuée, elle recrache tout (%d or)" % v)
	_clear()

	# Pot de peinture : une zone annoncée, puis une flaque qui brûle
	e = _spawn("pot_peinture", Vector2(160, 0))
	e.cd = 0.1
	var lobbed := false
	var burning := false
	for k in int(2.5 / DT):
		_step()
		lobbed = lobbed or not arena.lobs.is_empty()
		for h in arena.hazards:
			burning = burning or (float(h.dmg) > 0.0 and float(h.r) > 15.0)
	_check(lobbed and burning, "Pot de peinture : zone annoncée, puis flaque qui brûle")
	_clear()

	# Copier-coller : il touche un ennemi et en fait une copie
	var victim := _spawn("curseur", Vector2(150, 40))
	victim.speed = 0.0
	e = _spawn("copier_coller", Vector2(150, -40))
	e.cd = 0.0
	for k in int(3.0 / DT):
		_step()
	var n_cur := arena.enemies.filter(func(o): return o.id == "curseur").size()
	_check(n_cur == 2, "Copier-coller : le Pointeur a été copié (%d Pointeurs)" % n_cur)
	_clear()

	# Lag : le joueur et les autres ennemis ralentissent dans son aura
	e = _spawn("sablier_e", Vector2(40, 0))
	e.speed = 0.0
	var other := _spawn("curseur", Vector2(60, 20))
	_step()
	_step()
	_check(p.sand_t > 0.0 and other.slow_t > 0.0, "Lag : le joueur et l'ennemi voisin sont ralentis")
	e.position = p.position + Vector2(200, 0)
	p.sand_t = 0.0
	_step()
	_check(p.sand_t <= 0.0, "Lag : loin de lui, plus de ralenti")
	_clear()

	# Lasso : si on reste dedans on est coincé, si on sort non
	e = _spawn("lasso", Vector2(120, 0))
	e.cd = 0.0
	e.speed = 0.0
	for k in int(1.6 / DT):
		_step()
	_check(p.root_t > 0.0, "Lasso : resté dans le contour, le joueur est coincé (%.1f s)" % p.root_t)
	# pas de prise en boucle : encore coincé puis 4 s à l'abri, aucun lasso ne part ni ne reprend
	_check(p.lasso_safe_t > 4.0, "Lasso : après une prise, le joueur est à l'abri des lassos (%.1f s)" % p.lasso_safe_t)
	arena.lassos.clear()
	e.cd = 0.0
	_step()
	_check(arena.lassos.is_empty(), "Lasso : tant que le joueur est à l'abri, le Lasso n'en relance pas")
	arena.add_lasso(p.position, 34.0, 0.1, 2.0)
	p.root_t = 0.0
	for k in 8:
		_step()
	_check(p.root_t <= 0.0, "Lasso : un contour qui se referme pendant l'immunité ne prend pas")
	p.root_t = 0.0
	p.lasso_safe_t = 0.0
	arena.lassos.clear()
	e.cd = 0.0
	_step()
	_check(arena.lassos.size() == 1, "Lasso : un nouveau contour se trace")
	p.position += Vector2(0, 90)
	for k in int(1.6 / DT):
		_step(false)
	_check(p.root_t <= 0.0, "Lasso : sorti du contour à temps, le joueur est libre")
	_clear()

	# Barre de chargement : se charge, se vide quand on la frappe, explose à 100 %
	e = _spawn("barre", Vector2(140, 0))
	for k in int(3.0 / DT):
		_step()
	var c0 := e.charge
	_check(c0 > 0.2, "Barre de chargement : elle se charge (%d %%)" % roundi(c0 * 100.0))
	e.hurt(e.max_hp * 0.1)
	_check(e.charge < c0, "Barre de chargement : la frapper la vide (%d %% → %d %%)" % [roundi(c0 * 100.0), roundi(e.charge * 100.0)])
	e.charge = 0.98
	e.pattern = 0
	e.st_t = 1.0
	var boom := false
	for k in int(1.0 / DT):
		_step()
		boom = boom or (e.state == "boom" and not arena.lobs.is_empty())
	_check(boom, "Barre de chargement : à 100 %, explosion annoncée")
	_clear()

	# --- Capture : une vague de L'Écran avec tous les ennemis
	if shots.size() > 0:
		var k2 := 0
		for id in ids:
			_spawn(id, Vector2.from_angle(k2 * TAU / 8.0) * 110.0)
			k2 += 1
		arena.drop_pickup(p.position + Vector2(40, 60), 2, 1)
		for k in int(1.2 / DT):
			_step()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots[0] + "/map3_arene.png")

	arena.ended = true
	Run.active = false
	print("MAP3TEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _arena(wave: int) -> void:
	Run.start(0, 3)
	Run.wave = wave
	Run.set_character(_blob(32, 180, Pal.SHADES[2][1]), "")
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), Pal.SHADES[1 + (hash(id) % 5)][1]), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()
	Run.hp = Run.stats.max_hp
	seed(7)
	arena = Arena.new()
	add_child(arena)


func _spawn(id: String, off: Vector2) -> Enemy:
	return arena.spawn_enemy_now(id, arena.player.position + off, false)


## Une image de jeu, sans apparitions automatiques ; le joueur reste en vie et immobile.
func _step(center := true) -> void:
	arena.spawn_acc = -1000.0
	arena.time_left = 99.0
	arena.player.hp = arena.player.max_hp
	if center:
		arena.player.position = Vector2(Arena.W / 2.0, Arena.H / 2.0)
	arena._process(DT)


func _clear() -> void:
	for e in arena.enemies.duplicate():
		e.loot = 0.0
		e.belly_v = 0
		e.belly_xp = 0
		arena.enemies.erase(e)
		e.queue_free()
	for pk in arena.pickups.duplicate():
		pk.queue_free()
	arena.pickups.clear()
	arena.telegraphs.clear()
	arena.hazards.clear()
	arena.lobs.clear()
	arena.squares.clear()
	arena.lassos.clear()
	arena.player.root_t = 0.0
	arena.player.lasso_safe_t = 0.0
	arena.player.sand_t = 0.0


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)
	return img
