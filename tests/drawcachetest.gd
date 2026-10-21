extends Node
## Dessins : infos gardées dans la fiche, cache d'images, lecture en arrière-plan (Meta.prefetch),
## fichiers réécrits / supprimés / introuvables pendant la lecture, changement de sauvegarde, et grille
## qui ne crée que les lignes visibles. Tout se passe dans un dossier TEMPORAIRE.

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _blob(s: int, n: int, col: Color) -> Image:
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	for i in n:
		img.set_pixel(2 + i % (s - 4), 2 + i / (s - 4), col)
	return img


func _ready() -> void:
	Meta.no_save = true
	var tmp := OS.get_temp_dir().path_join("paintit_drawcachetest") + "/"
	_wipe(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	Meta.root = tmp
	Meta.no_save = false
	Meta.settings = {"tips": false}
	Meta.select_slot(2)
	Meta.data.unlocks["pack_primaires"] = 1

	# 1. un dessin ajouté a ses infos tout de suite, identiques à un calcul sur l'image
	for i in 30:
		var img := _blob(24, 40 + i, Pal.SHADES[1 + i % 3][1])
		img.set_pixel(20, 20 - i % 10, Pal.INK)
		Meta.add_to_gallery("enemy", img, "")
	var e: Dictionary = Meta.gallery("enemy")[0]
	var img0 := Meta.gallery_image(e)
	_check(int(e.iv) == Meta.INFO_V and int(e.ink) == Analyzer.ink_cost(img0) and int(e.px) == Analyzer.count_pixels(img0),
		"infos d'un nouveau dessin : encre et pixels comme sur l'image")
	_check(Analyzer.dominant_of(e.el) == int(Analyzer.analyze(img0).dominant), "couleur dominante d'après la fiche = celle de l'analyse")
	var cfg := {"size": Vector2i(16, 16), "need_el": 2}
	_check(DrawCfg.entry_block(cfg, e) == DrawCfg.gallery_block(cfg, img0) and DrawCfg.entry_color_issue(cfg, e) == DrawCfg.color_issue(cfg, img0),
		"blocages d'après la fiche = blocages d'après l'image")

	# 2. l'image rendue est une copie : la modifier ne touche pas au cache
	img0.fill(Color.RED)
	_check(Meta.gallery_image(e).get_pixel(0, 0).a == 0.0, "image rendue = copie (le cache reste intact)")

	# 3. anciennes fiches sans infos : recalculées en arrière-plan
	var ref_ink := int(e.ink)
	for g in Meta.data.gallery:
		for k in ["iv", "rect", "ink", "el"]:
			g.erase(k)
	Meta.save()
	Meta.load_data()   # (cache vidé, comme au lancement)
	Meta.prefetch()
	await Meta.infos_done
	var g0: Dictionary = Meta.gallery("enemy")[0]
	_check(Meta.data.gallery.all(func(g): return int(g.get("iv", 0)) == Meta.INFO_V) and int(g0.ink) == ref_ink,
		"prefetch : les infos manquantes sont recalculées en arrière-plan")
	_check(Meta._cache.size() >= 30, "prefetch : les images sont en mémoire (%d)" % Meta._cache.size())

	# 4. vignette : rappel immédiat quand l'image est prête
	var got := []
	Meta.texture_async(g0.file, func(tex, r): got.append([tex, r]))
	_check(got.size() == 1 and got[0][0] is Texture2D and (got[0][1] as Rect2i).size.x > 0, "vignette prête : rappel immédiat avec la zone dessinée")

	# 4b. vignette demandée, puis la même image lue directement (le panneau du Codex) : la vignette la reçoit
	Meta.load_data()
	var got2 := []
	Meta.texture_async(g0.file, func(tex, _r): got2.append(tex))
	Meta.gallery_image(g0)
	_check(got2.size() == 1, "vignette en attente servie quand l'image est lue directement")

	# 5. dessin par défaut réécrit : on relit le nouveau, pas l'ancien du cache
	Meta.bestiary_set("blob", _blob(16, 10, Pal.SHADES[1][1]), "", false)
	Meta.bestiary_get("blob")
	Meta.bestiary_set("blob", _blob(16, 60, Pal.SHADES[2][1]), "", false)
	_check(Analyzer.count_pixels(Meta.bestiary_get("blob").image) == 60, "dessin du Codex réécrit : la nouvelle version est lue")
	Meta.bestiary_remove("blob")
	_check(Meta.bestiary_get("blob") == null and Meta.bestiary_file("blob") == "", "dessin du Codex retiré : plus rien")

	# 6. fichier supprimé à la main : la fiche disparaît de la galerie, sans planter
	var gone: String = Meta.gallery("enemy")[1].file
	DirAccess.remove_absolute(gone)
	Meta.load_data()
	var called := [false]
	Meta.texture_async(gone, func(_t, _r): called[0] = true)
	Meta.prefetch()
	await Meta.infos_done
	await get_tree().process_frame
	_check(not called[0] and Meta.gallery("enemy").all(func(g): return g.file != gone), "fichier introuvable : ni vignette ni fiche affichée")

	# 7. dessin supprimé pendant la lecture, puis sauvegarde changée pendant la lecture
	Meta.load_data()
	Meta.prefetch()
	await get_tree().process_frame   # (un paquet est en cours de lecture)
	var del: Dictionary = Meta.gallery("enemy")[0]
	Meta.remove_from_gallery(del)
	await Meta.infos_done
	_check(not Meta._cache.has(del.file) and Meta.gallery("enemy").all(func(g): return g.file != del.file), "supprimé pendant la lecture : pas remis en mémoire")
	Meta.prefetch()
	await get_tree().process_frame
	Meta.select_slot(3)
	Meta.prefetch()
	await Meta.infos_done
	await get_tree().process_frame
	_check(Meta._cache.keys().all(func(k): return not String(k).begins_with(Meta.slot_dir(2))), "sauvegarde changée pendant la lecture : rien de l'ancienne en mémoire")

	# 8. grille : seules les lignes visibles (plus une de marge) sont créées
	var items := range(600)
	var made := [0]
	var grid := DrawingGrid.new(items, 10, Vector2(52, 52), func(_i):
		made[0] += 1
		return Control.new())
	grid.size = Vector2(580, 280)
	add_child(grid)
	await get_tree().process_frame
	_check(made[0] > 0 and made[0] <= 80, "grille de 600 : %d cases créées à l'ouverture" % made[0])
	grid.scroll_vertical = int(grid._box.custom_minimum_size.y)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(grid._built.has(59), "grille : la dernière ligne est créée en descendant (%d cases en tout)" % made[0])

	Meta.no_save = true
	_wipe(tmp)
	print("DRAWCACHE : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for s in d.get_directories():
		_wipe(dir.path_join(s))
	DirAccess.remove_absolute(dir)
