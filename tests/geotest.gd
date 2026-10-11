extends Node
## Le Géomètre (boss de la vague 10 du Tableau noir, parfois à la place de la Photocopieuse) :
## il se plante, trace des cercles annoncés 1 s qui brûlent 3 s, prend +50 % planté, et sous 50 %
## de PV trace 3 cercles et lance sa pointe.
## Godot --headless --path . res://tests/geotest.tscn [-- <capture.png>]

const DT := 1.0 / 30.0
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var args := OS.get_cmdline_user_args()

	# --- La carte peut tirer les deux boss à la vague 10
	var seen := {}
	for n in 60:
		seen[MapDB.boss_plan(2)[10]] = true
	_check(seen.has("geometre") and seen.has("photocopieuse"), "Tableau noir, vague 10 : Photocopieuse ou Géomètre (%s)" % str(seen.keys()))
	_check(EnemyDB.get_def("geometre").hp == EnemyDB.get_def("photocopieuse").hp, "mêmes PV que la Photocopieuse")

	# --- Le combat
	Run.start(0, 2)
	Run.wave = 10
	Run.boss_plan[10] = "geometre"
	Run.set_character(_blob(32, 180, Pal.SHADES[2][1]), "")
	Run.set_weapon_art("epee", 0, _blob(32, 90, Pal.SHADES[0][1]), "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), Pal.SHADES[6][1]), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()
	Run.hp = Run.stats.max_hp
	seed(11)
	var arena := Arena.new()
	add_child(arena)
	await get_tree().process_frame
	_check(arena.boss_id == "geometre", "la vague 10 lance bien Le Géomètre")
	# on avance jusqu'à ce qu'il soit là, puis jusqu'à son premier plantage
	var boss: Enemy = null
	var t := 0.0
	var planted_at := -1.0
	var max_rings := 0
	var burned := false
	while t < 30.0:
		arena.player.hp = arena.player.max_hp
		arena._process(DT)
		t += DT
		if boss == null and arena.boss and is_instance_valid(arena.boss):
			boss = arena.boss
		if boss and boss.state == "plant" and planted_at < 0.0:
			planted_at = t
		max_rings = maxi(max_rings, arena.rings.size())
		if planted_at > 0.0 and arena.rings.is_empty() and arena.hazards.size() > 20:
			burned = true
		if burned and boss.state != "plant":
			break
	_check(boss != null, "le boss apparaît")
	_check(planted_at > 0.0, "il se plante (à %.1f s)" % planted_at)
	_check(max_rings == 2, "au-dessus de 50 %% de PV : 2 cercles par plantage (%d)" % max_rings)
	_check(burned, "les cercles annoncés deviennent de l'encre qui brûle (%d flaques)" % arena.hazards.size())

	# --- Planté : +50 % de dégâts
	boss.state = "walk"
	var h0 := boss.hp
	boss.hurt(100.0)
	var d_walk := h0 - boss.hp
	boss.state = "plant"
	h0 = boss.hp
	boss.hurt(100.0)
	var d_plant := h0 - boss.hp
	_check(absf(d_plant / d_walk - 1.5) < 0.01, "planté : +50 %% de dégâts (%.0f → %.0f)" % [d_walk, d_plant])

	# --- Sous 50 % : 3 cercles, et il lance sa pointe en se relevant
	boss.hp = boss.max_hp * 0.4
	boss.state = "walk"
	boss.st_t = 0.1
	arena.rings.clear()
	var made := {}   # cercles créés pendant ce plantage (repérés par leur angle de départ)
	var threw := false
	t = 0.0
	if args.size() > 0:
		# capture : au moment où les 3 cercles se tracent
		while t < 6.0 and made.size() < 3:
			arena.player.hp = arena.player.max_hp
			arena._process(DT)
			t += DT
			for ring in arena.rings:
				made[ring.a0] = true
		for k in 12:
			arena.player.hp = arena.player.max_hp
			arena._process(DT)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0])
	while t < 12.0:
		arena.player.hp = arena.player.max_hp
		arena._process(DT)
		t += DT
		for ring in arena.rings:
			made[ring.a0] = true
		if not arena.strokes.is_empty():
			threw = true
			break
	_check(made.size() == 3, "sous 50 %% de PV : 3 cercles par plantage (%d)" % made.size())
	_check(threw, "sous 50 %% de PV : il lance sa pointe (%d traits annoncés)" % arena.strokes.size())

	arena.ended = true
	Run.active = false
	print("GEOTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)
	return img
