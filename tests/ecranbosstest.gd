extends Node
## Les trois autres boss de L'Écran : Le Bug et Le Tableur (vague 10), Le Curseur (vague 15).
## Godot --headless --path . res://tests/ecranbosstest.tscn [-- <dossier de captures>]

const DT := 1.0 / 30.0
var fails := 0
var arena: Arena
var shots := []


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	shots = OS.get_cmdline_user_args()
	var seen := {}
	for n in 60:
		seen[MapDB.boss_plan(3)[10]] = true
	_check(seen.has("bug") and seen.has("tableur") and MapDB.boss_plan(3)[15] == "curseur_boss", "L'Écran : vague 10 Le Bug ou Le Tableur, vague 15 Le Curseur")

	# ============================================================ Le Bug
	var boss := await _fight("bug", 10)
	# Glitch : des copies apparaissent autour du joueur et tirent sur lui
	boss.cd = 99.0
	boss.cd2 = 99.0
	boss.cd3 = 99.0
	boss.cd4 = 0.0
	for b0 in arena.bullets.duplicate():
		arena.bullets.erase(b0)
		b0.queue_free()
	_steps(int(1.0 / DT))
	var glitch_shots: Array = arena.bullets.filter(func(b): return b.hostile)
	_check(glitch_shots.size() >= 6 and boss.cd4 > 5.0, "Le Bug se dédouble : ses copies tirent (%d tirs en 1 s)" % glitch_shots.size())
	boss.cd = 0.0
	boss.cd2 = 0.0
	boss.cd3 = 0.0
	var p := arena.player
	var tp := 0
	var last_pos := boss.position
	var kinds := {}
	var t := 0.0
	while t < 40.0:
		_step()
		t += DT
		if boss.position.distance_to(last_pos) > 60.0:
			tp += 1
		last_pos = boss.position
		for k in arena.bugs.active:
			kinds[k] = true
	_check(tp >= 5, "Le Bug : il se téléporte (%d fois en 40 s)" % tp)
	_check(kinds.size() >= 2, "Le Bug : il lance les gros bugs (%s)" % ", ".join(kinds.keys()))
	var heavy_only := true
	for k in kinds:
		heavy_only = heavy_only and ScreenBugs.HEAVY.has(k)
	_check(heavy_only and not arena.bugs.auto, "Le Bug : pendant son combat, aucun bug léger automatique")
	await _end()

	# ============================================================ Le Tableur
	boss = await _fight("tableur", 10)
	p = arena.player
	var bands_seen := 0
	var formula_seen := ""
	var summed := false
	var hit_by_band := false
	t = 0.0
	for k in 5:
		arena.spawn_enemy_now("curseur", Vector2(200, 80 + k * 50), false).speed = 0.0   # une colonne à additionner
	while t < 45.0:
		var n0 := arena.bands.size()
		var hp0 := p.hp
		_step(false)
		t += DT
		bands_seen += maxi(0, arena.bands.size() - n0)
		if not arena.formula.is_empty():
			formula_seen = String(arena.formula.text)
		for e in arena.enemies:
			if not e.is_boss and e.base_scale > 1.5:
				summed = true
		if shots.size() > 0 and arena.bands.size() >= 2 and not hit_by_band and not arena.formula.is_empty():
			hit_by_band = true
			await _shot("tableur")
	_check(bands_seen >= 4, "Le Tableur : des lignes et colonnes s'allument puis explosent (%d bandes)" % bands_seen)
	_check(formula_seen != "", "Le Tableur : il applique une formule (%s)" % formula_seen)
	_check(summed, "Le Tableur : il fusionne les ennemis d'une colonne en un gros")
	# la formule change vraiment les dégâts du joueur
	arena.formula = {"text": "=DÉGÂTS/2", "t": 5.0, "dmg": 0.5, "speed": 1.0}
	var dummy := arena.spawn_enemy_now("curseur", p.position + Vector2(40, 0), false)
	dummy.hp = 99999.0
	dummy.max_hp = 99999.0
	dummy.dodge = 0.0
	seed(1)
	arena.hit_enemy(dummy, 100.0, {}, Vector2.ZERO, 0.0)
	var half := 99999.0 - dummy.hp
	arena.formula = {}
	dummy.hp = 99999.0
	seed(1)
	arena.hit_enemy(dummy, 100.0, {}, Vector2.ZERO, 0.0)
	var full := 99999.0 - dummy.hp
	_check(absf(half / full - 0.5) < 0.01, "Le Tableur : « =DÉGÂTS/2 » divise bien tes dégâts par 2 (%.0f → %.0f)" % [full, half])
	await _end()

	# ============================================================ Le Curseur
	boss = await _fight("curseur_boss", 15)
	p = arena.player
	p.god = true   # (invincible : sinon chaque coup reçu fige le monde un instant et fausse les mesures)
	p.st.dodge = 0.0   # (pas d'esquive : sinon les vérifications de dégâts dépendent du hasard)

	# --- Phase 1 : il lance un ennemi
	var ammo := arena.spawn_enemy_now("curseur", boss.position + Vector2(20, 0), false)
	boss.atk_bag = ["throw"]
	boss.state = "walk"
	boss.st_t = 0.0
	_steps(2)
	_check(boss.state == "lift" and ammo.held_by == boss, "Le Curseur : il soulève un ennemi")
	var flew := false
	for k in int(2.5 / DT):
		_step()
		if not is_instance_valid(ammo) or ammo.dead:
			break
		flew = flew or ammo.thrown_t > 0.0
	_check(flew and (not is_instance_valid(ammo) or ammo.dead), "Le Curseur : il le lance, l'ennemi explose au bout de sa course")

	# --- Phase 1 : une flèche de projectiles, en formation
	_clear_enemies(boss)
	for b0 in arena.bullets.duplicate():
		arena.bullets.erase(b0)
		b0.queue_free()
	boss.toile_phase = 1
	boss.position = p.position + Vector2(-160, 0)
	boss.atk_bag = ["arrows"]
	boss.state = "walk"
	boss.st_t = 0.0
	_steps(1)
	var shots_now: Array = arena.bullets.filter(func(b): return b.hostile)
	_check(shots_now.size() == Enemy.ARROW_SHAPE.size(), "Le Curseur : une flèche de %d projectiles (%d)" % [Enemy.ARROW_SHAPE.size(), shots_now.size()])
	var same := true
	for b1 in shots_now:
		same = same and (b1.vel as Vector2).distance_to(shots_now[0].vel) < 0.01
	_check(same and (shots_now[0].vel as Vector2).normalized().dot((p.position - boss.position).normalized()) > 0.95, "Le Curseur : la flèche part d'un bloc, droit vers le joueur")
	for b2 in arena.bullets.duplicate():
		arena.bullets.erase(b2)
		b2.queue_free()
	boss.toile_phase = 3
	boss.atk_bag = ["arrows"]
	boss.state = "walk"
	boss.st_t = 0.0
	_steps(1)
	_check(arena.bullets.filter(func(b): return b.hostile).size() == 3 * Enemy.ARROW_SHAPE.size(), "Le Curseur, phase 3 : trois flèches en éventail")
	for b3 in arena.bullets.duplicate():
		arena.bullets.erase(b3)
		b3.queue_free()
	boss.toile_phase = 1

	# --- Phase 1 : il attrape le joueur et le traîne à la Corbeille
	_clear_enemies(boss)
	boss.atk_bag = ["hunt"]
	boss.state = "walk"
	boss.st_t = 0.0
	var caught := false
	for k in int(4.0 / DT):
		_step()
		if boss.state == "carry":
			caught = true
			break
	_check(caught and boss.grabbed, "Le Curseur : sa main suit le joueur immobile et l'attrape")
	var d0 := p.position.distance_to(Arena.TRASH_POS)
	for k in int(1.0 / DT):
		_step(false)
	_check(p.position.distance_to(Arena.TRASH_POS) < d0 - 40.0, "Le Curseur : il traîne le joueur vers la Corbeille")
	p.god = false
	p.max_hp = 99999.0   # (assez de PV pour survivre au test)
	p.hp = p.max_hp
	p.inv = 0.0
	var thrown_in := false
	for k in int(8.0 / DT):
		var hp0 := p.hp
		arena.spawn_acc = -9999.0
		arena._process(DT)
		if boss.state != "carry":
			thrown_in = p.hp < hp0
			break
	_check(thrown_in and not boss.grabbed, "Le Curseur : sans secouer, le joueur finit à la Corbeille (il perd %d PV)" % int(p.max_hp - p.hp))
	p.god = true
	p.hp = p.max_hp
	arena.hitstop_t = 0.0
	# secouer les touches libère
	boss.state = "carry"
	boss.grabbed = true
	boss.struggle = Enemy.STRUGGLE_NEED
	boss.position = Vector2(200, 200)
	_step(false)
	_check(boss.state == "jam" and not boss.grabbed, "Le Curseur : assez de secousses, le joueur se libère et le boss est sonné")
	var hj := boss.hp
	boss.boss_inv = 0.0
	boss.hurt(100.0)
	_check(absf((hj - boss.hp) - 150.0) < 1.0, "Le Curseur sonné prend +50 %% de dégâts (%.0f)" % (hj - boss.hp))

	# --- Premier plantage, puis il redevient touchable
	boss.state = "walk"
	boss.hp = boss.max_hp * 0.55
	arena.hitstop_t = 0.0
	_steps(3)
	_check(boss.toile_phase == 2 and arena.hud.crash_t > 0.0 and arena.hud.crash_kind == "crash", "Le Curseur à 60 % : le jeu plante (écran d'erreur)")
	_check(arena.void_target == 0.0, "... et l'arène ne rétrécit plus")
	if shots.size() > 0:
		await _shot("curseur_plantage")
	arena.hud.crash_t = 0.0
	arena.hitstop_t = 0.0
	for k in int(1.5 / DT):
		boss.st_t = 9.0
		_step()
	var hp_inv := boss.hp
	boss.hurt(50.0)
	_check(boss.hp < hp_inv, "Le Curseur : après le plantage, on peut de nouveau le blesser")

	# --- Phase 2 : Sélection + Suppr (le joueur ET les ennemis dedans)
	_clear_enemies(boss)
	boss.atk_bag = ["select"]
	boss.state = "walk"
	boss.st_t = 0.0
	_steps(2)
	_check(arena.bands.size() == 1 and arena.bands[0].get("sel", false), "Le Curseur : un rectangle de sélection se trace")
	var victim := arena.spawn_enemy_now("curseur", (arena.bands[0].rect as Rect2).get_center(), false)
	victim.speed = 0.0
	if shots.size() > 0:
		for k in 18:
			boss.st_t = 9.0
			_step()
		await _shot("curseur_selection")
	for k in int(1.4 / DT):
		boss.st_t = 9.0
		_step()
	_check(not is_instance_valid(victim) or victim.dead, "Le Curseur : SUPPR supprime aussi l'ennemi qui était dans la sélection")

	# --- Phase 2 : il redimensionne le joueur
	var r0 := p.radius
	p.resize(1.8, 6.0)
	var mid: Vector2 = p.sprite.position + p.sprite_c * p.sprite.scale.x   # centre du dessin, vu depuis le joueur
	_check(is_equal_approx(p.sprite.scale.x, 1.8) and mid.length() < 0.01, "Redimensionné : le dessin grossit autour de son centre, sans se décaler (%.1f, %.1f)" % [mid.x, mid.y])
	_check(p.radius > r0 * 1.7 and p.size_k > 1.0, "Redimensionné : énorme (rayon %.0f → %.0f)" % [r0, p.radius])
	p.resize(0.55, 6.0)
	var dummy2 := arena.spawn_enemy_now("curseur", p.position + Vector2(40, 0), false)
	dummy2.hp = 99999.0
	dummy2.max_hp = 99999.0
	dummy2.dodge = 0.0
	seed(2)
	arena.hit_enemy(dummy2, 100.0, {}, Vector2.ZERO, 0.0)
	var small_d := 99999.0 - dummy2.hp
	p.resize(1.0, 0.0)
	dummy2.hp = 99999.0
	seed(2)
	arena.hit_enemy(dummy2, 100.0, {}, Vector2.ZERO, 0.0)
	var norm_d := 99999.0 - dummy2.hp
	_check(absf(small_d / norm_d - 0.6) < 0.01 and is_equal_approx(p.radius, r0), "Redimensionné : minuscule, les coups font 60 % ; puis retour à la normale")
	_clear_enemies(boss)

	# --- Second plantage, phase 3
	boss.state = "walk"
	boss.boss_inv = 0.0
	boss.hp = boss.max_hp * 0.2
	arena.hitstop_t = 0.0
	_steps(3)
	_check(boss.toile_phase == 3 and arena.hud.crash_pct, "Le Curseur à 25 % : second plantage, avec le faux pourcentage")
	arena.hud.crash_t = 0.0
	arena.hitstop_t = 0.0
	boss.st_t = 9.0
	_steps(3)

	# réduire la fenêtre : faux bureau, on rouvre d'un clic ; sinon elle revient seule
	arena.hud.minimize(6.0)
	_check(arena.hud.desk != null, "Le Curseur réduit la fenêtre : le faux bureau s'affiche")
	if shots.size() > 0:
		await _shot("curseur_bureau")
	(arena.hud.desk.get_meta("btn") as Button).pressed.emit()
	_check(arena.hud.desk == null, "Cliquer « PaintIt » dans la barre des tâches rouvre le jeu")
	arena.hud.minimize(0.5)
	for k in 40:
		arena.hud._process(DT)
	_check(arena.hud.desk == null, "Sans cliquer, la fenêtre revient toute seule")

	# il traîne la fenêtre : l'image glisse
	arena.win_drag_t = Arena.WIN_DRAG_SEC
	var max_off := 0.0
	for k in int(3.0 / DT):
		boss.st_t = 9.0
		_step()
		max_off = maxf(max_off, arena.cam.offset.length())
	_check(max_off > 40.0, "Le Curseur traîne la fenêtre : l'image se décale (jusqu'à %d px)" % int(max_off))
	arena.win_drag_t = 0.0

	# Chargement (à la place de l'Alt+F4) : immobile, il crache une spirale de points, et tu rames
	for b0 in arena.bullets.duplicate():
		arena.bullets.erase(b0)
		b0.queue_free()
	boss.atk_bag = ["loading"]
	boss.state = "walk"
	boss.st_t = 0.0
	boss.boss_inv = 0.0
	_steps(2)
	_check(boss.state == "loading" and p.lag_t > 0.0, "Le Curseur lance un Chargement : le joueur est ralenti")
	var pos0 := boss.position
	_steps(int(1.5 / DT))
	var spiral: Array = arena.bullets.filter(func(b): return b.hostile)
	_check(spiral.size() >= 30 and boss.position.distance_to(pos0) < 1.0, "Chargement : une spirale de %d points, et il ne bouge pas" % spiral.size())
	if shots.size() > 0:
		await _shot("curseur_chargement")
	_steps(int(2.0 / DT))
	_check(boss.state != "loading", "Chargement : il s'arrête au bout de 3 s")
	_check(Arena.WIN_DRAG_SEC >= 8.0, "La fenêtre traînée dure %d s" % int(Arena.WIN_DRAG_SEC))

	# fausse victoire : presque mort, il revient
	boss.state = "walk"
	boss.st_t = 9.0
	boss.boss_inv = 0.0
	boss.hp = boss.max_hp * 0.03
	_steps(3)
	_check(boss.fake_done and arena.hud.crash_kind == "win" and boss.hp > boss.max_hp * 0.1, "Fausse victoire : l'écran annonce la victoire, et il revient à %d %% de PV" % roundi(boss.hp / boss.max_hp * 100.0))
	if shots.size() > 0:
		arena.hud.crash_t = 0.4
		await _shot("curseur_fausse_victoire")
	arena.hud.crash_t = 0.0
	arena.hud.crash_view.visible = false
	arena.hitstop_t = 0.0
	boss.boss_inv = 0.0
	boss.hp = boss.max_hp * 0.03
	boss.st_t = 9.0
	_steps(3)
	_check(boss.hp < boss.max_hp * 0.05 and not arena.hud.crash_view.visible, "La fausse victoire n'arrive qu'une fois")
	await _end()

	Run.active = false
	print("ECRANBOSSTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _fight(boss_id: String, wave: int) -> Enemy:
	Run.start(0, 3)
	Run.wave = wave
	Run.boss_plan[wave] = boss_id
	Run.set_character(_blob(32, 180, Pal.SHADES[2][1]), "")
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), Pal.SHADES[1 + (hash(id) % 5)][1]), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()
	Run.hp = Run.stats.max_hp
	seed(5)
	arena = Arena.new()
	add_child(arena)
	await get_tree().process_frame
	var t := 0.0
	while t < 8.0 and not (arena.boss and is_instance_valid(arena.boss)):
		_step()
		t += DT
	_check(arena.boss != null and arena.boss.id == boss_id, "%s : le boss apparaît" % EnemyDB.get_def(boss_id).name)
	return arena.boss


func _end() -> void:
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame


func _shot(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots[0] + "/" + name + ".png")


func _clear_enemies(keep: Enemy) -> void:
	for e in arena.enemies.duplicate():
		if e != keep:
			e.loot = 0.0
			arena.enemies.erase(e)
			e.queue_free()
	arena.telegraphs.clear()
	arena.spawn_acc = -9999.0


## Des images de jeu sans toucher aux PV du joueur.
func _step_raw(n: int) -> void:
	for k in n:
		arena.player.position = Vector2(Arena.W / 2.0, Arena.H / 2.0)
		arena._process(DT)


func _steps(n: int) -> void:
	for k in n:
		_step()


func _step(center := true) -> void:
	arena.player.hp = arena.player.max_hp
	if center:
		arena.player.position = Vector2(Arena.W / 2.0, Arena.H / 2.0)
	arena._process(DT)


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)
	return img
