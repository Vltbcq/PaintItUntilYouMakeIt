extends Node
## Capture : la fiche au survol des objets possédés en boutique (arme à distance, amulette, familier).
## Godot --path . res://tests/shophovershot.tscn -- <dossier>


func _blob(size: int, px: int, el := 1) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var side := int(ceil(sqrt(float(px))))
	@warning_ignore("integer_division")
	img.fill_rect(Rect2i((size - side) / 2, (size - side) / 2, side, side), Pal.SHADES[el][1])
	return img


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var dir: String = OS.get_cmdline_user_args()[0]
	Run.start(0, 1)
	Run.wave = 2
	Run.set_character(_blob(32, 200, 3), "")
	Run.set_weapon_art("pistolet", 1, _blob(24, 60, 2), "", _blob(8, 9, 2), "")
	Run.add_weapon("pistolet", 1, 10, Vector2(8, 0))
	Run.set_weapon_art("epee", 0, _blob(24, 40, 1), "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2(-8, 0))
	for id in ["plume", "plume", "satellite"]:
		Run.set_amulet_art(id, _blob(16, 40, 4), "")
		Run.add_amulet(id, Run.amulet_art[id].image, Vector2i(30, 30))
	Run.set_familiar_art("luciole", _blob(24, 60, 2), "")
	Run.add_familiar("luciole")
	Run.recompute()
	Run.gold = 250
	Run.new_shop()
	var shop := ShopScreen.new()
	shop.size = Vector2(640, 360)
	add_child(shop)
	await get_tree().process_frame
	var k := 0
	for info in [shop._owned_weapon_card(Run.weapons[0]), {"name": "Plume ×2", "kind": "Commune", "lines": [], "desc": AmuletDB.describe(AmuletDB.get_def("plume")), "bullet": false},
			{"name": AmuletDB.get_def("satellite").name, "kind": "Légendaire", "lines": [], "desc": AmuletDB.describe(AmuletDB.get_def("satellite")), "bullet": false}]:
		var t := Control.new()
		shop.add_child(t)
		t.position = [Vector2(12, 230), Vector2(15, 309), Vector2(300, 309)][k]
		t.size = Vector2(46, 20)
		shop._show_card(info, t)
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "/hover_%d.png" % k)
		k += 1
	Run.active = false
	get_tree().quit()
