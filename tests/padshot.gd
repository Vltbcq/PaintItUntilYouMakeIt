extends Node
## Capture : le curseur et la ligne d'aide de la manette, sur l'écran-titre puis sur la toile.
## Godot --path . res://tests/padshot.tscn -- <dossier>


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.data = Meta.data.duplicate(true)
	var dir: String = OS.get_cmdline_user_args()[0]
	var t := TitleScreen.new()
	t.size = Vector2(640, 360)
	add_child(t)
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_LEFT_STICK
	ev.pressed = true
	Input.parse_input_event(ev)
	for k in 4:
		await get_tree().process_frame
	Pad._move_to(Vector2(330, 118))   # sur « Reprendre » / « Jouer » : le bouton est survolé
	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pad_titre.png")
	t.queue_free()
	Run.start(0, 1)
	var ds := DrawScreen.new(DrawCfg.character())
	ds.size = Vector2(640, 360)
	add_child(ds)
	for k in 4:
		await get_tree().process_frame
	Pad._move_to(ds.view.get_global_transform() * Vector2(60, 60))
	for k in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/pad_dessin.png")
	Run.active = false
	get_tree().quit()
