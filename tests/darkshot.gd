extends Node
## Capture : le noir de la Lampe torche, troué par la Luciole.
## Godot --path . res://tests/darkshot.tscn -- <dossier>


func _blob(size: int, px: int, el := 1) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var side := int(ceil(sqrt(float(px))))
	@warning_ignore("integer_division")
	img.fill_rect(Rect2i((size - side) / 2, (size - side) / 2, side, side), Pal.SHADES[el][1])
	return img


func _shot(ids: Array, path: String) -> void:
	Run.start(0, 1)
	Run.wave = 3
	Run.set_character(_blob(32, 180), "")
	Run.set_weapon_art("epee", 0, _blob(32, 90, 3), "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), 4), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	var k := 0
	for id in ids:
		k += 1
		Run.set_amulet_art(id, _blob(16, 40, 1 + k % 6), "")
		Run.add_amulet(id, Run.amulet_art[id].image, Vector2i(30, 30))
	Run.set_familiar_art("luciole", _blob(24, 60, 2), "")
	Run.add_familiar("luciole")
	Run.recompute()
	var arena := Arena.new()
	add_child(arena)
	await get_tree().process_frame
	arena.player.god = true
	for f in 90:
		arena.player.position += Vector2(1.2, 0.4)
		arena.player.moving = true
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var dir: String = OS.get_cmdline_user_args()[0]
	await _shot(["lampe"], dir + "/dark_luciole.png")
	Run.active = false
	get_tree().quit()
