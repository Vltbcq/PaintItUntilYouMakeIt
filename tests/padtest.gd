extends Node
## Manette : le curseur piloté au stick clique, glisse, dessine au pixel près, et rend la main à la souris.
## Godot --headless --path . res://tests/padtest.tscn

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _btn(b: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _axis(a: int, v: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = a
	ev.axis_value = v
	Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _tap(b: int) -> void:
	_btn(b, true)
	await _frames(2)
	_btn(b, false)
	await _frames(2)


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.data = Meta.data.duplicate(true)
	Meta.unlock_all()
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(2)
	_check(not Pad.active, "au départ : la souris a la main")

	# --- Un bouton : le stick amène le curseur dessus, A clique
	var clicks := [0]
	var b := UI.button("Test", func(): clicks[0] += 1)
	b.position = Vector2(400, 180)
	b.size = Vector2(80, 20)
	add_child(b)
	await _frames(2)
	Pad.pos = Vector2(320, 190)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(3)
	_check(Pad.active, "toucher le stick donne la main à la manette")
	var x0 := Pad.pos.x
	for k in 40:
		await get_tree().process_frame
		if Pad.pos.x >= 420.0:
			break
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(2)
	_check(Pad.pos.x > x0 + 60.0 and absf(Pad.pos.y - 190.0) < 1.0, "le stick déplace le curseur (%d → %d)" % [int(x0), int(Pad.pos.x)])
	Pad.pos = Vector2(440, 190)
	await _tap(JOY_BUTTON_A)
	_check(clicks[0] == 1, "A clique le bouton sous le curseur (%d clic)" % clicks[0])
	Pad.pos = Vector2(100, 100)
	await _tap(JOY_BUTTON_A)
	_check(clicks[0] == 1, "A à côté ne clique rien")
	# gâchette gauche : plus lent
	Pad.pos = Vector2(100, 100)
	_axis(JOY_AXIS_LEFT_X, 1.0)
	await _frames(10)
	var fast := Pad.pos.x - 100.0
	Pad.pos = Vector2(100, 100)
	_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(10)
	var slow := Pad.pos.x - 100.0
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(2)
	_check(slow > 0.0 and slow < fast * 0.5, "LT ralentit le curseur (%.1f px contre %.1f)" % [slow, fast])
	# Y = Entrée, B = Échap (raccourcis des boutons)
	var keys := []
	var by := UI.hotkey(UI.button("Valider", func(): keys.append("Y")), [KEY_ENTER])
	var bb := UI.hotkey(UI.button("Retour", func(): keys.append("B")), [KEY_ESCAPE])
	by.position = Vector2(10, 300)
	bb.position = Vector2(120, 300)
	add_child(by)
	add_child(bb)
	await _frames(2)
	await _tap(JOY_BUTTON_Y)
	await _tap(JOY_BUTTON_B)
	_check(keys == ["Y", "B"], "Y valide (Entrée), B revient (Échap) : %s" % str(keys))
	await get_tree().create_timer(0.8).timeout   # (les infobulles sont revues deux fois par seconde)
	_check(by.tooltip_text.contains("(Y)") and bb.tooltip_text.contains("(B)") and not by.shortcut_in_tooltip, "les infobulles annoncent les boutons de la manette (%s, %s)" % [by.tooltip_text, bb.tooltip_text])
	b.queue_free()
	by.queue_free()
	bb.queue_free()

	# --- La toile : A maintenu + croix = un trait pixel par pixel ; X gomme ; LB défait
	Run.start(0, 1)
	var cfg := DrawCfg.character()
	var ds := DrawScreen.new(cfg)
	ds.size = Vector2(640, 360)
	add_child(ds)
	await _frames(4)
	_check(Pad.canvas == ds.view, "la toile s'inscrit auprès de la manette")
	# les indications de touches passent à la manette (et reviennent avec la souris, vérifié à la fin)
	await get_tree().create_timer(0.8).timeout
	var undo: Array = ds.find_children("*", "Button", true, false).filter(func(x): return x.tooltip_text == "Défaire (LB)")
	_check(undo.size() == 1 and Pad.txt("Échap : pause") == "Start : pause", "indications : « Défaire (Ctrl+Z) » devient « Défaire (LB) », « Échap : pause » devient « Start : pause »")
	var kb := UI.label("Molette / + - : zoom", 10, Pal.TEXT)
	add_child(kb)
	await get_tree().create_timer(0.8).timeout
	_check(kb.text == "LB / RB : zoom", "une étiquette qui parle de la molette parle de LB / RB (%s)" % kb.text)
	var view: CanvasView = ds.view
	var xf := view.get_global_transform()
	var start := Vector2i(5, 6)
	Pad.pos = xf * ((Vector2(start) + Vector2(0.5, 0.5)) * view.px)
	var ink0: int = Analyzer.analyze(ds.img).pixels
	_btn(JOY_BUTTON_A, true)
	await _frames(2)
	for k in 3:
		await _tap(JOY_BUTTON_DPAD_RIGHT)
	_btn(JOY_BUTTON_A, false)
	await _frames(2)
	var drawn := 0
	for k in 4:
		drawn += int(ds.img.get_pixel(start.x + k, start.y).a > 0.5)
	_check(drawn == 4 and int(Analyzer.analyze(ds.img).pixels) == ink0 + 4, "A maintenu + 3 pas de croix : 4 pixels en ligne (%d)" % drawn)
	_check(view.cell_at(xf.affine_inverse() * Pad.pos) == start + Vector2i(3, 0), "la croix avance d'une case exactement")
	# X gomme la case sous le curseur
	await _tap(JOY_BUTTON_X)
	_check(ds.img.get_pixel(start.x + 3, start.y).a < 0.5, "X gomme le pixel sous le curseur")
	# LB défait (la gomme), RB refait
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(ds.img.get_pixel(start.x + 3, start.y).a > 0.5, "LB défait")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(ds.img.get_pixel(start.x + 3, start.y).a < 0.5, "RB refait")
	ds.queue_free()
	await _frames(3)
	_check(Pad.canvas == null, "toile fermée : la manette l'oublie")

	# --- Poser une arme : LB tourne, RB retourne, et les boutons l'annoncent
	var wimg := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	wimg.fill_rect(Rect2i(2, 8, 20, 6), Pal.SHADES[1][1])
	Run.set_character(wimg, "")
	var ps := PlaceScreen.new("weapon", wimg, WeaponDB.get_def("epee"))
	ps.size = Vector2(640, 360)
	add_child(ps)
	await get_tree().create_timer(0.8).timeout
	_check(Pad.turning(), "écran de pose : la manette le sait")
	var labels: Array = ps.find_children("*", "Button", true, false).map(func(x): return x.text)
	_check("Tourner (LB)" in labels and "Miroir (RB)" in labels, "les boutons annoncent LB et RB (%s)" % str(labels))
	var rot0: int = ps.rot
	var flip0: bool = ps.flip
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	_check(ps.rot == (rot0 + 1) % 4, "LB tourne l'arme d'un quart de tour")
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(ps.flip != flip0, "RB la retourne en miroir")
	ps.queue_free()
	await _frames(3)
	_check(not Pad.turning(), "écran de pose fermé : LB / RB refont défiler")

	# --- En combat : pas de curseur, A ne clique rien ; en pause : le curseur revient
	var cimg := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	cimg.fill_rect(Rect2i(6, 6, 12, 12), Pal.SHADES[1][1])
	Run.set_character(cimg, "")
	Run.set_weapon_art("epee", 0, cimg, "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	var arena := Arena.new()
	add_child(arena)
	await _frames(3)
	_check(Pad.in_play() and not Pad._cursor.visible, "vague en cours : pas de curseur")
	var hit := [0]
	var hb := UI.button("x", func(): hit[0] += 1)
	hb.process_mode = Node.PROCESS_MODE_ALWAYS
	hb.position = Vector2(300, 170)
	hb.size = Vector2(40, 20)
	var top := CanvasLayer.new()
	top.layer = 60
	add_child(top)
	top.add_child(hb)
	await _frames(2)
	Pad.pos = Vector2(320, 180)
	await _tap(JOY_BUTTON_A)
	_check(hit[0] == 0, "vague en cours : A ne clique pas")
	var z0: float = arena.cam.zoom.x
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_check(not is_equal_approx(arena.cam.zoom.x, z0), "vague en cours : RB / LB zooment (%.2f → %.2f)" % [z0, arena.cam.zoom.x])
	get_tree().paused = true
	await _frames(3)
	_check(not Pad.in_play() and Pad._cursor.visible, "en pause : le curseur revient")
	await _tap(JOY_BUTTON_A)
	_check(hit[0] == 1, "en pause : A clique")
	get_tree().paused = false
	arena.queue_free()
	top.queue_free()
	await _frames(3)

	# --- La vraie souris reprend la main
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(50, 60)
	mm.relative = Vector2(12, 0)
	Input.parse_input_event(mm)
	await _frames(3)
	_check(not Pad.active and not Pad._cursor.visible, "bouger la souris rend la main à la souris")
	_check(kb.text == "Molette / + - : zoom" and Pad.txt("Échap : pause") == "Échap : pause", "... et les indications redeviennent celles du clavier (%s)" % kb.text)
	# --- Souris pendant une vague : le curseur se cache après 2 s sans y toucher, et revient
	var arena2 := Arena.new()
	add_child(arena2)
	await _frames(3)
	Pad._mouse_ms = Time.get_ticks_msec()
	await _frames(3)
	_check(not Pad.mouse_hidden, "vague, souris qui vient de bouger : curseur visible")
	Pad._mouse_ms = Time.get_ticks_msec() - Pad.IDLE_HIDE_MS - 50   # (comme si 2 s étaient passées)
	await _frames(3)
	_check(Pad.mouse_hidden, "vague, souris immobile depuis 2 s : curseur caché")
	var mm2 := InputEventMouseMotion.new()
	mm2.position = Vector2(80, 90)
	mm2.relative = Vector2(10, 0)
	Input.parse_input_event(mm2)
	await _frames(3)
	_check(not Pad.mouse_hidden, "... il revient dès qu'on bouge la souris")
	Pad._mouse_ms = Time.get_ticks_msec() - Pad.IDLE_HIDE_MS - 50
	get_tree().paused = true
	await _frames(3)
	_check(not Pad.mouse_hidden, "en pause : le curseur reste visible même immobile")
	get_tree().paused = false
	arena2.queue_free()
	await _frames(3)
	_check(not Pad.mouse_hidden, "hors vague : toujours visible")
	Run.active = false
	print("PADTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
