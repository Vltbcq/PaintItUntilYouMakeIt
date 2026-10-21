extends Node
## Test des 3 sauvegardes et de la reprise de partie, dans un dossier TEMPORAIRE
## (jamais dans les vraies sauvegardes). Godot --headless --path . res://tests/savetest.tscn


func _ready() -> void:
	Meta.no_save = true
	var tmp := OS.get_temp_dir().path_join("paintit_savetest") + "/"
	_wipe(tmp)
	DirAccess.make_dir_recursive_absolute(tmp)
	Meta.root = tmp
	Meta.no_save = false
	Meta.settings = {"tips": false}
	var main: Node = load("res://scripts/main.gd").new()
	main.set_process(false)
	# --- Sauvegarde 2 : une partie avec de tout
	Meta.select_slot(2)
	Meta.add_pigments(42)
	Run.start(1)
	Run.set_character(_blob(32, 180, Pal.SHADES[1][1]), "pulse")
	Run.set_weapon_art("epee", 0, _blob(32, 120, Pal.INK), "", null, "")
	Run.set_weapon_art("epee", 1, _blob(32, 150, Pal.SHADES[2][1]), "shimmer", null, "", false)
	Run.set_weapon_art("arc", 0, _blob(32, 100, Pal.INK), "", _blob(16, 20, Pal.SHADES[3][1]), "pulse")
	Run.add_weapon("epee", 0, 12, Vector2(-5, 3), 1, true)
	Run.add_weapon("epee", 1, 30, Vector2(6, -2))
	Run.add_weapon("arc", 0, 14, Vector2(0, 8), 2, false)
	Run.set_amulet_art("coeur", _blob(16, 30, Pal.SHADES[1][1]), "")
	Run.add_amulet("coeur", Run.amulet_art["coeur"].image, Vector2i(30, 30))
	Run.add_mark(_blob(12, 20, Pal.SHADES[4][1]), Vector2i(26, 40))
	Run.set_enemy_art("tache", _blob(24, 150, Pal.SHADES[1][1]), "")
	Run.auto_eproj("tache")
	Run.set_elite_art("tache", _blob(24, 200, Pal.SHADES[5][1]), "")
	Run.wave = 4
	Run.gold = 77
	Run.level = 3
	Run.xp = 5
	Run.bonus = {"dmg": 6.0}
	Run.pending_levels = 0
	Run.recompute()
	Run.hp = 9.0
	Run.new_shop()
	var before := _snap()
	Meta.save_run(Run.to_save("after"))
	Meta.save()
	print("SAVE : fichier partie=%s, résumé 2=%s, résumé 3 vide=%s" % [Meta.has_run(), Meta.slot_summary(2), Meta.slot_summary(3).is_empty()])
	# --- Relecture
	Run.start(0)
	var ok := Run.from_save(Meta.read_run())
	var after := _snap()
	var diffs := []
	for k in before:
		if str(before[k]) != str(after[k]):
			diffs.append("%s: %s != %s" % [k, before[k], after[k]])
	print("RELOAD : ok=%s, différences=%s" % [ok, diffs if not diffs.is_empty() else "aucune"])
	# --- Reprise via le vrai flux : boutique, puis « Sauvegarder et quitter »
	add_child(main)
	await get_tree().process_frame
	main._resume()
	var seen := []
	for i in 10:
		await get_tree().process_frame
		var cur: Node = main.current
		if cur is RunLogScreen:
			seen.append("reprise")
			cur.done.emit(true)
		elif cur is ShopScreen and not seen.has("boutique"):
			seen.append("boutique")
			cur.done.emit({"a": "suspend"})
		elif cur is TitleScreen:
			seen.append("titre")
			break
	print("REPRISE : écrans=%s, offres gardées=%s, partie toujours sauvegardée=%s" % [seen, str(Run.shop_offers) == str(before.offers), Meta.has_run()])
	# --- Reprise au début d'une vague, puis « Sauvegarder et quitter » depuis la pause
	Meta.save_run(Run.to_save("wave"))
	main._resume()
	var got := []
	for i in 30:
		await get_tree().process_frame
		var cur: Node = main.current
		if cur is RunLogScreen:
			cur.done.emit(true)
		elif cur is BestiaryPrompt:
			cur._keep()
		elif cur is DrawScreen:
			cur._validate()
		elif cur is Arena and not got.has("vague"):
			got.append("vague %d" % Run.wave)
			got.append("vague")
			cur.done.emit("suspend")
		elif cur is TitleScreen:
			got.append("titre")
			break
	print("PAUSE : écrans=%s, partie gardée=%s, étape=%s" % [got, Meta.has_run(), Meta.read_run().get("stage", "")])
	# --- Succès sur une sauvegarde neuve (3) : les outils ne s'achètent plus, ils se gagnent
	Meta.select_slot(3)
	Meta.add_pigments(500)
	var bought_tool := Meta.buy("tool_line")
	var bought_ink := Meta.buy("ink")
	# Pendant une partie : succès marqués, mais améliorations en attente jusqu'à la fin
	Run.start(0)
	Meta.check_achievements({"cleared": 5, "level": 10, "kills": 20})
	var during := [Meta.has("pack_primaires"), Meta.has("tool_mirror")]
	var got_unlocks := Meta.apply_pending_unlocks()
	Run.active = false
	print("SUCCÈS : outil acheté=%s, encre achetée=%s, pendant la partie : primaire=%s symétrie=%s, en fin de partie : %s -> primaire=%s secondaire=%s symétrie=%s rectangle=%s" % [
		bought_tool, bought_ink, during[0], during[1], got_unlocks, Meta.has("pack_primaires"), Meta.has("pack_secondaires"), Meta.has("tool_mirror"), Meta.has("tool_rect")])
	# Hors partie (ex. galerie remplie dans le Codex) : tout de suite
	Meta.check_achievements({"cleared": 8})
	print("SUCCÈS hors partie : rectangle=%s, en attente=%s" % [Meta.has("tool_rect"), Meta.data.pending_unlocks])
	# Abandon : succès obtenu pendant la partie -> en attente (même après rechargement) -> appliqué à l'abandon
	Meta.delete_slot(3)
	Meta.select_slot(3)
	Run.start(0)
	Run.set_character(_blob(32, 180, Pal.SHADES[0][0]), "")
	Run.set_weapon_art("epee", 0, _blob(32, 120, Pal.INK), "", null, "")
	Run.add_weapon("epee", 0, 12, Vector2.ZERO)
	Run.set_enemy_art("tache", _blob(24, 150, Pal.INK), "")
	Run.wave = 4
	Meta.check_achievements({"cleared": 5})
	Meta.save_run(Run.to_save("wave"))
	Meta.load_data()   # comme si on relançait le jeu
	var kept := [Meta.pending("rature"), Meta.has("tool_triangle")]
	main._resume()
	var screens2 := []
	var recap := []
	for i in 30:
		await get_tree().process_frame
		var cur: Node = main.current
		if cur is RunLogScreen:
			cur.done.emit(true)
		elif cur is Arena and not screens2.has("vague"):
			screens2.append("vague")
			cur.done.emit("quit")   # Abandonner la partie
		elif cur is ChoiceScreens._Screen and not screens2.has("fin"):
			await get_tree().process_frame
			screens2.append("fin")
			for l in cur.find_children("*", "Label", true, false):
				if String(l.text).begins_with("★"):
					recap.append(l.text)
			cur.done.emit(true)
		elif cur is TitleScreen:
			screens2.append("titre")
			break
	print("ABANDON : en attente après rechargement=%s, triangle avant la fin=%s, écrans=%s, récap=%s, triangle après=%s, partie effacée=%s" % [
		kept[0], kept[1], screens2, recap, Meta.has("tool_triangle"), not Meta.has_run()])
	Meta.delete_slot(3)
	# --- Suppression de la sauvegarde 2 (la 1 n'est pas touchée)
	Meta.select_slot(1)
	Meta.add_pigments(5)
	Meta.delete_slot(2)
	var pngs := DirAccess.get_files_at(Meta.gallery_dir(2)).size() + DirAccess.get_files_at(Meta.bestiary_dir(2)).size()
	print("SUPPRESSION : sauvegarde 2 existe=%s, partie 2=%s, images restantes=%d, sauvegarde 1 intacte=%s" % [
		Meta.slot_exists(2), Meta.read_run(2).is_empty() == false, pngs, Meta.slot_exists(1) and Meta.pigments() == 5])
	# --- Retour à la normale
	main.queue_free()
	Meta.no_save = true
	Meta.root = "user://"
	_wipe(tmp)
	get_tree().quit()


func _snap() -> Dictionary:
	var ws := Run.weapons.map(func(w): return [w.type, w.rar, w.anchor, w.rot, w.flip, snappedf(w.st.get("damage", w.st.get("dmg_mult", 0.0)), 0.001), snappedf(w.st.cooldown, 0.001)])
	return {"wave": Run.wave, "diff": Run.difficulty, "gold": Run.gold, "level": Run.level, "xp": Run.xp, "hp": Run.hp,
		"max_hp": Run.stats.max_hp, "dmg": Run.stats.dmg, "atk": Run.stats.atk_speed, "weapons": ws,
		"amulets": Run.amulets.map(func(a): return [a.id, a.zone, a.pos]), "marks": Run.marks.size(),
		"enemy": Run.enemy_art.tache.mods, "elite": Run.elite_art.tache.mods, "eproj": Run.eproj_art.keys(),
		"boss_plan": Run.boss_plan, "offers": Run.shop_offers, "char_fx": Run.char_effect, "outline_rare": Run.weapon_art["epee#1"].outline}


func _wipe(dir: String) -> void:
	# Ne nettoie QUE le dossier de test temporaire
	if not dir.contains("paintit_savetest"):
		return
	var da := DirAccess.open(dir)
	if da == null:
		return
	for d in da.get_directories():
		_wipe(dir + d + "/")
	for f in da.get_files():
		DirAccess.remove_absolute(dir + f)
	DirAccess.remove_absolute(dir)


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)
	return img
