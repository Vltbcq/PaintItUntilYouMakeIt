extends Node
## Partage de dessins : export .zip, import (doublons ignorés, jamais d'écrasement), fichier invalide,
## et plus aucune suppression automatique dans la galerie. Tout se passe dans un dossier TEMPORAIRE.
## Godot --headless --path . res://tests/sharetest.tscn [-- <dossier de captures>]

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Meta.no_save = true
	var tmp := OS.get_temp_dir().path_join("paintit_sharetest") + "/"
	_wipe(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	Meta.root = tmp
	Meta.no_save = false
	Meta.settings = {"tips": false}

	# --- Sauvegarde 2 : quelques dessins, puis export
	Meta.select_slot(2)
	var kinds := ["character", "enemy", "amulet", "melee", "boss", "familiar"]
	for i in kinds.size():
		Meta.add_to_gallery(kinds[i], _blob(24, 60 + i * 20, Pal.SHADES[(i % 6) + 1][1]), "pulse" if i == 0 else "")
	var mine := Meta.gallery("all")
	_check(mine.size() == 6, "6 dessins dans la sauvegarde 2")
	var zip := tmp + "partage.zip"
	_check(Meta.export_gallery(mine, zip) == 6 and FileAccess.file_exists(zip), "export : 6 dessins dans le .zip")
	if args.size() > 0:
		await _capture_export(args[0])

	# --- Plus aucune suppression automatique
	for i in 70:
		var e := _blob(24, 120, Pal.SHADES[1][1])
		e.set_pixel(i % 24, i / 24, Pal.INK)   # (chaque dessin un peu différent : pas de doublon)
		Meta.add_to_gallery("enemy", e, "")
	_check(Meta.gallery("enemy").size() >= 71, "plus de limite : %d ennemis gardés (aucun supprimé)" % Meta.gallery("enemy").size())

	# --- Sauvegarde 3 (vide) : import
	Meta.delete_slot(3)
	Meta.select_slot(3)
	Meta.add_to_gallery("character", _blob(24, 60, Pal.SHADES[1][1]), "pulse")   # le même perso que dans le .zip
	var own_file: String = Meta.gallery("character")[0].file
	var own_bytes := FileAccess.get_file_as_bytes(own_file)
	var r := Meta.read_share(zip)
	_check(r.ok and r.items.size() == 6, "lecture : 6 dessins trouvés")
	_check(r.items.filter(func(it): return it.dup).size() == 1, "le perso déjà présent est repéré comme doublon")
	_check(r.items.filter(func(it): return it.kind == "character")[0].effect == "pulse", "l'effet (Pulse) est conservé")
	if args.size() > 0:
		await _capture_import(r, args[0])
	var added := Meta.import_share(r.items)
	_check(added == 5 and Meta.gallery("all").size() == 6, "import : 5 ajoutés, le doublon ignoré")
	_check(FileAccess.get_file_as_bytes(own_file) == own_bytes, "ton dessin existant n'est pas écrasé")
	var again := Meta.read_share(zip)
	_check(again.items.filter(func(it): return not it.dup).is_empty() and Meta.import_share(again.items) == 0, "réimporter : tout est déjà là, rien d'ajouté")
	_check(int(Meta.data.get("pixels_painted", 0)) < 200, "les dessins importés ne comptent pas dans tes pixels peints")
	_check(Meta.own_gallery_size() == 1, "ni pour les succès de galerie (%d dessin à toi)" % Meta.own_gallery_size())

	# --- Fichiers invalides
	var bad := tmp + "pas_un_zip.zip"
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("coucou")
	f.close()
	_check(not Meta.read_share(bad).ok, "un faux .zip est refusé proprement")
	var other := tmp + "autre.zip"
	var zp := ZIPPacker.new()
	zp.open(other)
	zp.start_file("photo.png")
	zp.write_file(PackedByteArray([1, 2, 3]))
	zp.close_file()
	zp.close()
	_check(not Meta.read_share(other).ok, "un .zip sans fiche Paint It est refusé")
	# Fichier piégé : l'en-tête annonce une image de 30 000 × 30 000 px (refusée sans être décodée)
	var giant := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	giant.fill(Color.RED)
	var png := giant.save_png_to_buffer()
	for i in 2:
		png.encode_u32(16 + 4 * i, 0)
		png[16 + 4 * i + 2] = 0x75   # 0x00007530 = 30000, en gros-boutiste
		png[16 + 4 * i + 3] = 0x30
	var trap := tmp + "piege.zip"
	zp = ZIPPacker.new()
	zp.open(trap)
	zp.start_file(Meta.SHARE_MANIFEST)
	zp.write_file(JSON.stringify({"items": [{"kind": "amulet", "file": "a.png"}]}).to_utf8_buffer())
	zp.close_file()
	zp.start_file("a.png")
	zp.write_file(png)
	zp.close_file()
	zp.close()
	_check(not Meta.read_share(trap).ok, "partage piégé (image géante annoncée) : refusé sans la décoder")

	Meta.delete_slot(2)
	Meta.delete_slot(3)
	Meta.no_save = true
	print("PARTAGE : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


## Capture de l'export (sélection, un dessin décoché).
func _capture_export(dir: String) -> void:
	var g := GalleryScreen.new()
	g.size = Vector2(640, 360)
	add_child(g)
	await get_tree().process_frame
	var ex := GalleryShare.open_export(g)
	ex.picked[1] = false
	ex._build()
	for k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/partage_export.png")
	g.queue_free()
	await get_tree().process_frame


## Capture de l'aperçu d'import (le doublon grisé).
func _capture_import(r: Dictionary, dir: String) -> void:
	var g := GalleryScreen.new()
	g.size = Vector2(640, 360)
	add_child(g)
	await get_tree().process_frame
	var im := GalleryShare.new()
	im.mode = "import"
	im.items = r.items
	im.picked = r.items.map(func(it): return not it.dup)
	im.src_name = "PaintIt_dessins_2026-10-08.zip"
	g.add_child(im)
	for k in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/partage_import.png")
	im.queue_free()
	g.queue_free()
	await get_tree().process_frame


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var rr := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= rr:
				img.set_pixel(x, y, col)
	return img


func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_wipe(dir.path_join(sub))
	for file in d.get_files():
		d.remove(file)
	DirAccess.remove_absolute(dir)
