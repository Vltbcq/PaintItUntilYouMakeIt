extends Node
## Test du journal de partie : entrées, stats de vague, sauvegarde / reprise, fichier texte écrasé
## à chaque nouvelle partie, écrans. Dossier TEMPORAIRE (jamais les vraies sauvegardes).
## Godot --path . res://tests/journaltest.tscn [-- <dossier de captures>]

var fails := 0
var got = null


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	var tmp := OS.get_temp_dir().path_join("paintit_journaltest") + "/"
	DirAccess.make_dir_recursive_absolute(tmp)
	Meta.root = tmp
	Meta.no_save = false
	Meta.settings = {"tips": false}
	var args := OS.get_cmdline_user_args()
	await get_tree().process_frame
	Run.start(1, 1)
	Run.set_character(_blob(32, 180), "")
	Run.set_weapon_art("epee", 1, _blob(32, 90), "", null, "")
	Run.add_weapon("epee", 1, 28, Vector2(8, 0))
	Run.set_amulet_art("coeur", _blob(16, 30), "")
	Run.add_amulet("coeur", Run.amulet_art["coeur"].image, Vector2i(30, 30))
	Run.wave = 3
	Run.recompute()
	Run.snapshot_wave_stats()
	Run.log_event("buy", "Achat : Épée rare (● 28)")
	Run.level = 2
	Run.pending_levels = 1
	Run.pending_levels -= 1
	Run.apply_upgrade({"stat": "dmg", "v": 5.0, "text": "+5% dégâts"})
	Run.log_event("event", "Roulette : ● 10 sur rouge → noir, perdu")
	_check(Run.journal.size() == 3, "3 entrées dans le journal")
	_check(String(Run.journal[1].t) == "Niveau 2 : +5% dégâts", "bonus de niveau noté (%s)" % Run.journal[1].t)
	_check(int(Run.wave_stats.wave) == 3 and String(Run.wave_stats.text).contains("Dégâts"), "stats au début de la vague 3")
	# fichier texte
	var path := Meta.slot_dir() + "journal_derniere_partie.txt"
	var txt := FileAccess.get_file_as_string(path)
	_check(txt.contains("Difficulté : Croquis") and txt.contains("Achat : Épée rare") and txt.contains("Niveau 2"), "fichier texte écrit")
	# sauvegarde / reprise
	var d := Run.to_save("after")
	Run.start(0, 1)
	_check(Run.journal.is_empty(), "nouvelle partie : journal vidé")
	Run.log_event("buy", "Arme de départ : Arc commune")
	var txt2 := FileAccess.get_file_as_string(path)
	_check(not txt2.contains("Épée rare") and txt2.contains("Esquisse"), "fichier écrasé à la nouvelle partie")
	Run.from_save(d)
	_check(Run.journal.size() == 3 and int(Run.wave_stats.wave) == 3, "reprise : journal et stats retrouvés")
	# écrans
	var scr := RunLogScreen.new("resume")
	scr.size = Vector2(640, 360)
	add_child(scr)
	await get_tree().process_frame
	if args.size() > 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0] + "/reprise.png")
	scr.done.connect(func(r): got = r)
	var btn: Array = scr.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("REPRENDRE"))
	btn[0].pressed.emit()
	_check(got == true, "écran de reprise : Reprendre")
	scr.queue_free()
	var end := ChoiceScreens.end_run(false, 12)
	end.size = Vector2(640, 360)
	add_child(end)
	await get_tree().process_frame
	var jb: Array = end.find_children("*", "Button", true, false).filter(func(b): return b.text == "Journal")
	_check(jb.size() == 1, "fin de partie : bouton Journal")
	if jb.size() == 1:
		jb[0].pressed.emit()
		await get_tree().process_frame
		_check(end.find_children("*", "RunLogScreen", true, false).size() == 1, "le journal s'ouvre")
		if args.size() > 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[0] + "/journal_fin.png")
	Meta.no_save = true
	Meta.root = "user://"
	Run.active = false
	print("JOURNAL : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _blob(size: int, px: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, Pal.SHADES[1][1])
	return img
