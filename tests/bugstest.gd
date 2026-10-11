extends Node
## Les bugs de L'Écran : la règle de la carte (bugs légers automatiques, un seul à la fois) et les
## gros bugs du boss (commandes inversées, écran à l'envers, retour en arrière, barre de vie folle).
## Godot --headless --path . res://tests/bugstest.tscn [-- <dossier de captures>]

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

	# --- Pas de bugs sur les autres cartes
	_arena(1)
	await get_tree().process_frame
	_check(arena.bugs == null, "La Feuille : aucun bug")
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame

	# --- L'Écran : un bug léger tombe tout seul, jamais deux à la fois
	_arena(3)
	await get_tree().process_frame
	var b := arena.bugs
	_check(b != null and b.auto, "L'Écran : les bugs automatiques sont actifs pendant une vague normale")
	var seen := {}
	var max_at_once := 0
	var t := 0.0
	while t < 120.0:
		_step()
		t += DT
		for k in b.active:
			seen[k] = true
		max_at_once = maxi(max_at_once, b.active.size() + b.pending.size())
	_check(seen.size() >= 3, "en 2 minutes, plusieurs bugs différents sont passés : %s" % ", ".join(seen.keys()))
	_check(max_at_once == 1, "jamais deux bugs à la fois (%d au plus)" % max_at_once)
	var only_light := true
	for k in seen:
		only_light = only_light and ScreenBugs.LIGHT.has(k)
	_check(only_light, "la carte ne lance que des bugs légers")

	# --- Chaque bug léger démarre et s'arrête proprement
	b.auto = false
	b.active.clear()
	b.pending.clear()
	b.launch("invert", 0.0)
	_step()
	_check(b.is_on("invert") and b.rect.visible and float(b.mat.get_shader_parameter("invert")) == 1.0, "couleurs inversées : le filtre est posé")
	if shots.size() > 0:
		for id in ["curseur", "corbeille", "pot_peinture", "barre"]:
			arena.spawn_enemy_now(id, arena.player.position + Vector2.from_angle(randf() * TAU) * 100.0, false)
		b.launch("shift", 0.0)
		for k in 20:
			_step()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots[0] + "/bugs_inverse.png")
	for k in int(4.5 / DT):
		_step()
	_check(not b.is_on("invert") and not b.rect.visible and float(b.mat.get_shader_parameter("invert")) == 0.0, "couleurs inversées : tout revient à la normale après 4 s")
	var n0 := arena.world.get_child_count()
	b.launch("trail", 0.0)
	for k in int(1.0 / DT):
		_step()
	_check(arena.world.get_child_count() > n0, "traînée : des copies fantômes du joueur apparaissent")

	# --- Les gros bugs (ceux du boss)
	b.active.clear()
	b.launch("flip", 0.0)
	_step()
	_check(not arena.cam.ignore_rotation and is_equal_approx(arena.cam.rotation, PI), "écran à l'envers : la caméra est retournée")
	for k in int(4.5 / DT):
		_step()
	_check(arena.cam.ignore_rotation, "écran à l'envers : la caméra revient à l'endroit")
	b.launch("controls", 0.0)
	_step()
	_check(b.is_on("controls"), "commandes inversées : actif")
	b.active.clear()
	# retour en arrière : le joueur revient où il était 1,5 s plus tôt
	b.hist.clear()
	var p := arena.player
	var start := Vector2(200, 200)
	for k in int(2.0 / DT):
		p.position = start + Vector2(k * 3.0, 0)
		_step(false)
	var before := p.position
	b.launch("rewind", 0.0)
	_step(false)
	_check(p.position.distance_to(before) > 80.0 and p.position.x < before.x, "retour en arrière : le joueur recule de %d px" % roundi(before.x - p.position.x))
	b.launch("fakehp", 0.0)
	_step()
	_check(b.is_on("fakehp"), "barre de vie folle : actif")

	# --- Le joueur a déjà l'effet : ce bug-là est ignoré
	b.active.clear()
	b.pending.clear()
	_check("flip" in b.heavy_choices(), "sans amulette, le boss peut retourner l'écran")
	Run.set_amulet_art("envers", _blob(16, 40, Pal.SHADES[3][1]), "")
	Run.add_amulet("envers", Run.amulet_art["envers"].image, Vector2i(30, 30))
	_check(not "flip" in b.heavy_choices() and "controls" in b.heavy_choices(), "avec Tête à l'envers, il choisit un autre bug")

	arena.ended = true
	Run.active = false
	print("BUGSTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _arena(map_id: int) -> void:
	Run.start(0, map_id)
	Run.wave = 4
	Run.set_character(_blob(32, 180, Pal.SHADES[2][1]), "")
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), Pal.SHADES[1 + (hash(id) % 5)][1]), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()
	Run.hp = Run.stats.max_hp
	seed(3)
	arena = Arena.new()
	add_child(arena)


func _step(center := true) -> void:
	arena.spawn_acc = -1000.0
	arena.time_left = 99.0
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
