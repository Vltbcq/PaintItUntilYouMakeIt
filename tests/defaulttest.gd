extends Node
## Test : le dessin choisi / dessiné en partie devient toujours le dessin par défaut (sans question).
## Dossier TEMPORAIRE (jamais les vraies sauvegardes). Godot --headless --path . res://tests/defaulttest.tscn

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	var tmp := OS.get_temp_dir().path_join("paintit_defaulttest") + "/"
	DirAccess.make_dir_recursive_absolute(tmp)
	Meta.root = tmp
	Meta.no_save = false
	Meta.settings = {"tips": false}
	Meta.select_slot(3)
	Meta.load_data()
	var main: Node = load("res://scripts/main.gd").new()
	main.set_process(false)
	add_child(main)
	await get_tree().process_frame
	var old := _blob(24, 60, Pal.SHADES[1][1])
	var neu := _blob(24, 90, Pal.SHADES[2][1])
	for key in ["perso", "amulette_coeur"]:
		Meta.bestiary_set(key, old, "", false)
		var cfg: Dictionary = DrawCfg.character() if key == "perso" else DrawCfg.amulet(AmuletDB.get_def("coeur"))
		var run := func(): await main._obtain(key, cfg)
		run.call()
		var asked := false
		for i in 20:
			await get_tree().process_frame
			var cur: Node = main.current
			if cur is BestiaryPrompt:
				cur.done.emit({"a": "keep", "image": neu, "effect": "", "outline": false, "from_carnet": false})
			elif cur is ChoiceScreens._Screen:
				asked = true
		var now = Meta.bestiary_get(key)
		_check(not asked and now != null and (now.image as Image).get_data() == neu.get_data(),
			"%s : le dernier choisi devient le dessin par défaut, sans question" % key)
	Meta.no_save = true
	Meta.root = "user://"
	print("DEFAULT : %d échec(s)" % fails)
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
