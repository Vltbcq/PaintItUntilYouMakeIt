extends Node
## Test automatique (dev) : simule une partie complète sans rien sauvegarder.
## Godot --headless --path . res://tests/selftest.tscn


func _ready() -> void:
	Meta.no_save = true   # ne jamais toucher la vraie sauvegarde
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	await get_tree().process_frame
	print("--- SELFTEST ---")
	# Tout débloqué, en mémoire uniquement
	for d in UnlockDB.LIST:
		Meta.data.unlocks[d.id] = d.cost.size()

	# Écran de dessin : chaque type
	var cfgs := [DrawCfg.character(), DrawCfg.enemy("tache"), DrawCfg.enemy("toile"), DrawCfg.eproj("crachoir"),
		DrawCfg.amulet(AmuletDB.get_def("palette")), DrawCfg.amulet(AmuletDB.get_def("chef_oeuvre"))]
	for t in WeaponDB.TYPES:
		cfgs.append(DrawCfg.weapon(t, randi() % 4))
		if WeaponDB.TYPES[t].kind == "ranged":
			cfgs.append(DrawCfg.bullet(t, Analyzer.analyze(_blob(32, 60, [1, 2])), "pulse"))
	for cfg in cfgs:
		var ds := DrawScreen.new(cfg)
		add_child(ds)
		for t in ["brush", "line", "rect", "ellipse", "fill", "eraser"]:
			ds._set_tool(t)
			ds.mirror = t == "line"
			ds.gradient = t == "brush"
			ds.begin_stroke(Vector2i(2, 2), false)
			ds.continue_stroke(Vector2i(6, 8))
			ds.continue_stroke(Vector2i(9, 3))
			ds.end_stroke()
		ds._set_effect("rainbow")
		ds._undo()
		ds._random_monster()
		await get_tree().process_frame
		print("draw %s %s : %d/%d px | %s" % [cfg.kind, cfg.get("wtype", ""), ds.used, cfg.ink, Stats.preview(cfg, ds.img, ds.effect).replace("\n", " | ")])
		ds.queue_free()

	# Partie simulée
	Run.start(0)
	Run.set_character(_blob(32, 180, [0, 1, 2, 3]), "shimmer")
	print("perso : PV %d/%d" % [Run.hp, Run.stats.max_hp])
	var bullets := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for i in 3:
		bullets.set_pixel(2 + i * 4, 5, Pal.SHADES[5][1])
		bullets.set_pixel(2 + i * 4, 6, Pal.SHADES[4][1])
	for t in WeaponDB.TYPES:
		var def: Dictionary = WeaponDB.TYPES[t]
		for r in 4:
			Run.set_weapon_art(t, r, _blob(def.canvas, int(def.ink * 0.7), [1, 3]), "", bullets if def.kind == "ranged" else null, "")
	for t in ["dague", "marteau", "faux", "tromblon", "baguette", "mortier"]:
		Run.add_weapon(t, 1, 20, Vector2(randf_range(-14, 14), randf_range(-14, 14)))
	for w in Run.weapons:
		var st: Dictionary = w.st
		print("arme %s : cd %.2f, %s" % [w.type, st.cooldown, ("dmg %.1f reach %d" % [st.damage, st.reach]) if st.kind == "melee" else ("%d balles x%d, range %d" % [st.bullets.size(), st.pellets, st.range])])
	# Retouche d'un type : toutes les copies suivent
	Run.set_weapon_art("dague", 1, _blob(24, 60, [2]), "pulse", null, "")
	for id in ["rature", "miroir", "double_trait", "arc_en_ciel", "coeur", "poids", "sangsue"]:
		Run.set_amulet_art(id, _blob(AmuletDB.canvas(AmuletDB.get_def(id)), 20, [1]), "")
		var img: Image = Run.amulet_art[id].image.duplicate()
		img.rotate_90(CLOCKWISE)
		img.flip_x()
		Run.add_amulet(id, img, Vector2i(randi_range(0, 30), randi_range(0, 30)))
	for d in AmuletDB.LIST:
		print("  amulette %s : %s" % [d.id, AmuletDB.describe(d)])
	print("amulettes : ", Run.amulets.map(func(a): return "%s@%s" % [a.id, a.zone]))
	for id in EnemyDB.TYPES:
		var c: int = EnemyDB.TYPES[id].canvas
		Run.set_enemy_art(id, _blob(c, int(EnemyDB.TYPES[id].ink * 0.5), [randi_range(0, 6)]), ["", "pulse"].pick_random())
		if EnemyDB.TYPES[id].get("shoots", false):
			Run.auto_eproj(id)
	# Élites (difficulté haute) : on teste l'écran puis on en crée pour tous les types
	Run.difficulty = 3
	var eds := DrawScreen.new(DrawCfg.elite("tache"))
	add_child(eds)
	await get_tree().process_frame
	print("élite : base %d encre, min %d, max %d" % [eds.used, DrawCfg.elite("tache").min_ink, eds.budget])
	eds.queue_free()
	for id in EnemyDB.pool(20):
		Run.set_elite_art(id, _blob(EnemyDB.TYPES[id].canvas + 8, int(EnemyDB.TYPES[id].ink * 0.7), [3]), "")
	# Synergie : 3 armes à dominante rouge
	var red := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for x in range(4, 28):
		for y in range(12, 18):
			red.set_pixel(x, y, Pal.SHADES[1][1])
	for r in 4:
		Run.set_weapon_art("epee", r, red, "", null, "")
	for k in 3:
		Run.add_weapon("epee", 0, 10, Vector2(k * 6 - 6, 10))
	print("synergies : ", Run.synergy_counts(), " actives ", Run.active_synergies())
	# Fusion (logique Run) : 2 épées communes -> 1 rare
	var before := Run.weapons.size()
	var idx := []
	for i in Run.weapons.size():
		if Run.weapons[i].type == "epee" and Run.weapons[i].rar == 0:
			idx.append(i)
	Run.weapons[idx[0]].rar = 1
	Run.weapons.remove_at(idx[1])
	Run.rebuild_weapon(Run.weapons[idx[0]])
	print("fusion : %d -> %d armes, épée rare dmg %.1f" % [before, Run.weapons.size(), Run.weapons[idx[0]].st.damage])
	Run.recompute()
	# Montée de niveau : bonus + marque (ne doit pas changer la taille ni la vitesse)
	var move_before: float = Run.stats.move
	var radius_before: float = Run.stats.radius
	Run.pending_levels = 3
	while Run.pending_levels > 0:
		var lu := LevelUpScreen.new()
		add_child(lu)
		await get_tree().process_frame
		var u: Dictionary = lu.choices[0]
		lu.queue_free()
		Run.pending_levels -= 1
		Run.apply_upgrade(u)
		var md := DrawScreen.new(DrawCfg.mark(u))
		add_child(md)
		md._random_monster()
		await get_tree().process_frame
		var mimg: Image = md.img.duplicate()
		md.queue_free()
		var pm := PlaceScreen.new("mark", mimg, {"name": "Marque", "desc": u.text})
		add_child(pm)
		await get_tree().process_frame
		pm._rotate()
		pm.queue_free()
		Run.add_mark(pm.item, Vector2i(12, 14), true)
		print("niveau : %s -> bonus total %s" % [u.text, Run.bonus])
	print("marques : %d, vitesse %.0f -> %.0f, taille %.1f -> %.1f" % [Run.marks.size(), move_before, Run.stats.move, radius_before, Run.stats.radius])
	# Aperçu sur le perso + boss à 95% via "au hasard"
	for cfg in [DrawCfg.weapon("lance"), DrawCfg.bullet("arc", Run.closest_art("arc", 0).a, ""), DrawCfg.amulet(AmuletDB.get_def("oeil")),
			DrawCfg.enemy("rature"), DrawCfg.enemy("critique"), DrawCfg.enemy("muse"), DrawCfg.enemy("toile")]:
		var ds := DrawScreen.new(cfg)
		add_child(ds)
		ds._random_monster()
		if ds.body_view:
			ds._toggle_body_view()
			ds._toggle_body_view()
		await get_tree().process_frame
		print("preview %s : aperçu perso=%s, encre %d/%d (min %d)" % [cfg.kind, ds.body_view != null, ds.used, cfg.ink, cfg.get("min_ink", 0)])
		ds.queue_free()

	for w in [1, 3, 5, 7, 10, 12, 13, 15]:
		Run.wave = w
		var arena := Arena.new()
		add_child(arena)
		var frames := 0
		var max_enemies := 0
		var max_bullets := 0
		var t0 := Time.get_ticks_msec()
		while not arena.ended and frames < 3600:
			arena.player.hp = 1e6
			arena.player.inv = 999.0
			arena._process(1.0 / 60.0)
			frames += 1
			max_enemies = maxi(max_enemies, arena.enemies.size())
			max_bullets = maxi(max_bullets, arena.bullets.size())
			if frames % 60 == 0:
				await get_tree().process_frame
		var ms := Time.get_ticks_msec() - t0
		var elites := 0
		for e in arena.enemies:
			if e.elite:
				elites += 1
		print("   effets : flaques=%d cloches=%d règles=%d gommes=%d nuages=%d élites vivantes=%d gommage=%.2f" % [
			arena.hazards.size(), arena.lobs.size(), arena.rulers.size(), arena.erasers.size(), arena.clouds.size(), elites, arena.player.erase_mult])
		if arena.boss_id != "" and arena.boss and is_instance_valid(arena.boss):
			print("   boss %s restant : %d / %d PV" % [arena.boss_id, arena.boss.hp, arena.boss.max_hp])
		print("vague %d : %d frames (%.1f ms/frame), fin=%s, ennemis max=%d, balles max=%d, kills=%d, PV=%d" % [
			w, frames, float(ms) / frames, arena.ended, max_enemies, max_bullets, Run.kills, Run.hp])
		arena.hud.toggle_pause()
		arena.hud.toggle_pause()
		arena.queue_free()
		await get_tree().process_frame

	# Boutique & autres écrans
	Run.recompute()
	Run.hp = 3
	Run.gold = 500
	Run.new_shop()
	Run.shop_offers.append({"type": "heal", "id": "potion", "rar": 0, "price": 5, "sold": false})
	for scr in [ShopScreen.new(), AtelierScreen.new(), GalleryScreen.new(), TitleScreen.new(),
			ChoiceScreens.difficulty(), ChoiceScreens.weapon_kind(), ChoiceScreens.end_run(true, 42),
			PlaceScreen.new("amulet", Run.amulet_art["coeur"].image, AmuletDB.get_def("coeur")),
			PlaceScreen.new("weapon", Run.closest_art("arc", 0).image, WeaponDB.get_def("arc")), OptionsPanel.new(), ArrangeScreen.new("arc", 1), ArrangeScreen.new("", 0),
			BestiaryPrompt.new(DrawCfg.enemy("tache"), null, 2),
			CodexScreen.new("armes"), CodexScreen.new("amulettes"), CodexScreen.new("ennemis"),
			BestiaryPrompt.new(DrawCfg.enemy("critique"), {"image": _blob(80, 300, [2]), "effect": "", "outline": true}, 5)]:
		add_child(scr)
		await get_tree().process_frame
		if scr is ShopScreen:
			scr._buy(Run.shop_offers.size() - 1)
			print("après potion : PV %d / %d" % [Run.hp, Run.stats.max_hp])
			scr._reroll()
			scr._sell(0)
			await get_tree().process_frame
		if scr is GalleryScreen:
			# Sélection + fenêtre de confirmation, SANS supprimer (galerie réelle du joueur)
			var ge := Meta.gallery(scr.kind)
			if not ge.is_empty():
				scr.selected = ge[0]
				scr._build()
				scr._ask_delete()
				print("galerie : confirmation ouverte = %s" % (scr.confirm != null))
		if scr is CodexScreen:
			print("codex %s : %d objets, texte : %s" % [scr.tab, scr._items().size(), scr._stats_text(scr.sel).substr(0, 60)])
		if scr is BestiaryPrompt:
			if not scr.gallery_btns.is_empty():
				scr.gallery_btns[0].pressed.emit()
				print("sélection galerie -> cadre rempli : %s, bord : %s" % [scr.sel_img != null, scr.outline])
				scr._toggle_outline()
			scr.done.connect(func(r): print("carnet : choix = %s" % r.a))
			print("carnet %s : existant=%s, dessins compatibles=%d" % [scr.cfg.title, scr.existing != null, scr._fitting().size()])
			if scr.existing != null:
				scr.done.emit({"a": "keep"})
		if scr is ArrangeScreen:
			scr.done.connect(func(r): print("rangement : nouvelle=%s, %d armes déplacées" % [r.new != null, r.moves.size()]))
			if scr.held >= 0:
				scr._rotate()
				scr.entries[scr.held].tl = Vector2i(4, 4)
				scr.entries[scr.held].placed = true
				scr.held = -1
			scr.sel = 0
			scr._mirror()
			scr._update()
			scr._validate()
		if scr is OptionsPanel:
			Meta.set_setting("zoom", 2.0, false)
			scr._refresh()
			Meta.set_setting("zoom", 1.5, false)
		if scr is PlaceScreen:
			scr._rotate()
			scr._mirror()
			scr.cell = Vector2i(3, 3)
			scr.placed = true
			scr._update()
		scr.queue_free()
	print("pigments si défaite vague 1 : ", Run.pigments_earned(false) if true else 0)
	print("--- SELFTEST FIN ---")
	get_tree().quit()


## Tache aléatoire de `px` pixels dans une toile `size`, couleurs parmi les éléments donnés.
func _blob(size: int, px: int, els: Array) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	@warning_ignore("integer_division")
	var p := Vector2i(size / 2, size / 2)
	var n := 0
	var guard := 0
	while n < px and guard < 20000:
		guard += 1
		if img.get_pixelv(p).a < 0.5:
			img.set_pixelv(p, Pal.SHADES[els.pick_random()][randi() % 3])
			n += 1
		p += [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].pick_random()
		p = p.clamp(Vector2i.ZERO, Vector2i(size - 1, size - 1))
	return img
