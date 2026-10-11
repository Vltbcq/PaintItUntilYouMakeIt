extends Node
## Le Virus (boss de la vague 5 de L'Écran) et ses fenêtres de pub : chaque type de fenêtre se
## ferme comme prévu (croix, piège, captchas, pub honnête), le QTE manette, le plafond de 8.
## Godot --headless --path . res://tests/virustest.tscn [-- <dossier de captures>]

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
	_check(MapDB.boss_plan(3)[5] == "virus", "L'Écran, vague 5 : Le Virus")

	Run.start(0, 3)
	Run.wave = 5
	Run.set_character(_blob(32, 180, Pal.SHADES[2][1]), "")
	Run.set_weapon_art("epee", 0, _blob(32, 90, Pal.SHADES[0][1]), "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), Pal.SHADES[4][1]), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()
	Run.hp = Run.stats.max_hp
	seed(21)
	arena = Arena.new()
	add_child(arena)
	await get_tree().process_frame
	_check(arena.boss_id == "virus", "la vague 5 lance bien Le Virus")
	var pops: VirusPopups = arena.hud.ensure_popups()

	# --- Chaque type de fenêtre
	var w := pops.spawn("ad")
	(w.get_meta("x") as Button).pressed.emit()
	_check(pops.count() == 0 and pops.closed == 1, "pub : la croix la ferme")

	w = pops.spawn("tiny")
	_check((w.get_meta("x") as Button).size.y <= 6.0, "croix minuscule : %d px de haut" % int((w.get_meta("x") as Button).size.y))
	pops.close(w)

	w = pops.spawn("trap")
	var fermer: Button = null
	for c in w.get_children():
		if c is Button and (c as Button).text == "FERMER":
			fermer = c
	fermer.pressed.emit()
	_check(pops.count() == 2, "bouton piégé : FERMER ouvre deux fenêtres de plus (%d ouvertes)" % pops.count())
	pops.close_all()

	w = pops.spawn("memory")
	var n_am := Run.amulets.size()
	for c in w.get_children():
		if c is Button and (c as Button).text == "Accepter":
			(c as Button).pressed.emit()
	_check(pops.count() == 0 and Run.amulets.size() == n_am, "« Mémoire pleine » : du bluff, aucune amulette supprimée")

	w = pops.spawn("honest")
	var g0 := Run.gold
	for c in w.get_children():
		if c is Button and (c as Button).text == "ICI":
			(c as Button).pressed.emit()
	_check(Run.gold > g0 and pops.count() == 0, "pub honnête : +%d or" % (Run.gold - g0))

	# captcha des taches : une case vide remet à zéro, toutes les taches ferment
	w = pops.spawn("c_spots")
	_check(not w.has_meta("x"), "les énigmes n'ont pas de croix : il faut les résoudre")
	var cells: Array = w.get_meta("cells")
	var spots: Array = w.get_meta("spots")
	var empty := -1
	for i in 9:
		if not spots.has(i):
			empty = i
			break
	(cells[spots[0]] as Button).pressed.emit()
	(cells[empty] as Button).pressed.emit()
	for i in spots:
		if i != spots[0]:
			(cells[i] as Button).pressed.emit()
	_check(pops.count() == 1, "captcha des taches : une erreur remet à zéro (toujours ouverte)")
	for i in spots:
		(cells[i] as Button).pressed.emit()
	_check(pops.count() == 0, "captcha des taches : toutes les taches cliquées, la fenêtre se ferme")

	# captcha du rond : que des carrés, puis l'un devient rond après 2 s
	w = pops.spawn("c_round")
	var rb: Array = w.get_meta("round_btns")
	var ri: int = w.get_meta("round_i")
	(rb[ri] as Button).pressed.emit()
	_check(pops.count() == 1 and not w.get_meta("round_ok"), "captcha du rond : au début, que des carrés (cliquer ne fait rien)")
	for k in int(2.3 / DT):
		pops._process(DT)
	_check(w.get_meta("round_ok"), "captcha du rond : après 2 s, un carré devient rond")
	(rb[ri] as Button).pressed.emit()
	_check(pops.count() == 0, "captcha du rond : cliquer le rond ferme la fenêtre")

	# --- Manette : 3 touches dans l'ordre sur la fenêtre du dessus
	w = pops.spawn("ad")
	_pad(JOY_BUTTON_START)   # (n'importe quelle touche : le jeu passe en mode manette)
	_check(pops.pad and w.has_meta("qte"), "manette : la fenêtre du dessus affiche sa suite de 3 touches")
	var seq: Array = w.get_meta("qte")
	_pad(VirusPopups.QTE_KEYS[int(seq[0])])
	_pad(VirusPopups.QTE_KEYS[(int(seq[1]) + 1) % 4])   # erreur
	_check(int(w.get_meta("qte_at")) == 0 and pops.count() == 1, "manette : une erreur fait recommencer la suite")
	for k in seq:
		_pad(VirusPopups.QTE_KEYS[int(k)])
	_check(pops.count() == 0, "manette : la bonne suite ferme la fenêtre")
	var mm := InputEventMouseMotion.new()
	pops._input(mm)
	_check(not pops.pad, "retour à la souris : le mode manette s'arrête")

	# --- Plafond
	for k in 20:
		pops.spawn()
	_check(pops.count() == VirusPopups.MAX, "jamais plus de %d fenêtres" % VirusPopups.MAX)
	var puzzles := pops.wins.filter(func(q): return String(q.get_meta("kind")).begins_with("c_")).size()
	_check(puzzles <= VirusPopups.MAX_PUZZLES, "jamais plus de %d énigmes sans croix à la fois (%d)" % [VirusPopups.MAX_PUZZLES, puzzles])
	if shots.size() > 0:
		for k in int(1.0 / DT):
			_step()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shots[0] + "/virus.png")
	pops.close_all()

	# --- Le boss en ouvre tout seul, et sa mort les ferme toutes
	var boss: Enemy = null
	var t := 0.0
	while t < 14.0:
		_step()
		t += DT
		if arena.boss and is_instance_valid(arena.boss):
			boss = arena.boss
	_check(boss != null and pops.count() >= 2 and pops.count() <= 5, "en 14 s de combat, Le Virus a ouvert %d fenêtres (une toutes les 3,5 s)" % pops.count())
	arena.kill_enemy(boss)
	_check(pops.count() == 0, "Le Virus vaincu : toutes ses fenêtres se ferment")

	arena.ended = true
	Run.active = false
	print("VIRUSTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _pad(button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	arena.hud.popups._input(ev)


func _step() -> void:
	arena.player.hp = arena.player.max_hp
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
