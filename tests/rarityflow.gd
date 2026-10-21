extends Node
## Test : chaque rareté garde son dessin ; achat avec 6 armes = fusion directe.


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var main: Node = load("res://scripts/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	Meta.data["bestiary"] = {}   # en mémoire seulement (no_save) : pas de dessin par défaut
	Run.start(0)
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for x in range(4, 28):
		img.set_pixel(x, 15, Pal.SHADES[0][0])
	Run.set_character(img, "")
	Run.set_weapon_art("epee", 0, img, "", null, "")
	for k in 6:
		Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	var art0 = Run.weapon_art["epee#0"].image
	# Achat d'une épée commune avec 6 armes : doit fusionner directement
	Run.gold = 999
	Run.shop_offers = [{"type": "weapon", "wtype": "epee", "rar": 0, "price": 10, "sold": false}]
	var done_flag := [false]
	var run := func():
		await main._buy(0)
		done_flag[0] = true
	run.call()
	for i in 10:
		await get_tree().process_frame
		if done_flag[0]:
			break
		var cur: Node = main.current
		if cur is DrawScreen:
			# on agrandit le dessin de la version rare
			for x in range(4, 28):
				cur.img.set_pixel(x, 16, Pal.SHADES[1][1])
			cur._recount()
			cur._validate()
	var rares := 0
	for w in Run.weapons:
		if w.rar == 1:
			rares += 1
	print("RARITY : armes=%d, rares=%d, dessin commun inchangé=%s, dessin rare différent=%s, offre vendue=%s" % [
		Run.weapons.size(), rares, Run.weapon_art["epee#0"].image == art0,
		Run.has_art("epee", 1) and Run.weapon_art["epee#1"].image.get_data() != art0.get_data(), Run.shop_offers[0].sold])
	# Dessin par défaut de la rareté ÉPIQUE dans le Codex : il est proposé à l'achat de l'épique
	var tmp := OS.get_temp_dir().path_join("paintit_test_default.png")
	var epic := img.duplicate()
	epic.fill_rect(Rect2i(2, 2, 6, 6), Pal.SHADES[2][1])
	epic.save_png(tmp)
	Meta.data.bestiary["arme_lance_r2"] = {"file": tmp, "effect": "", "outline": true}
	Run.set_weapon_art("lance", 0, img, "", null, "")
	Run.shop_offers = [{"type": "weapon", "wtype": "lance", "rar": 2, "price": 10, "sold": false}]
	Run.weapons.resize(3)
	var screens := await _drive(main, func(): await main._buy(0))
	print("DÉFAUT : écrans=%s, lance épique = dessin épique du Codex : %s, commune inchangée : %s" % [screens,
		Run.has_art("lance", 2) and Analyzer.trim(Run.weapon_art["lance#2"].image).get_data() == Analyzer.trim(epic).get_data(),
		Run.weapon_art["lance#0"].image.get_data() == img.get_data()])
	# Fusion vers une rareté sans dessin (légendaire) : écran de dessin obligatoire (pas de « Garder »)
	Run.add_weapon("lance", 2, 10, Vector2.ZERO)
	var n2 := 0
	for w in Run.weapons:
		if w.type == "lance" and w.rar == 2:
			n2 += 1
	screens = await _drive(main, func(): await main._fuse("lance", 2))
	print("FUSION : épiques=%d, écrans=%s, légendaire dessinée=%s" % [n2, screens, Run.has_art("lance", 3)])
	DirAccess.remove_absolute(tmp)
	get_tree().quit()


## Lance une action de main.gd et répond aux écrans qu'elle ouvre. Retourne la liste des écrans.
func _drive(main: Node, action: Callable) -> Array:
	var screens := []
	var fin := [false]
	var run := func():
		await action.call()
		fin[0] = true
	run.call()
	for i in 20:
		await get_tree().process_frame
		if fin[0]:
			break
		var cur: Node = main.current
		if cur == null or (not screens.is_empty() and screens[-1][1] == cur):
			continue
		if cur is ArrangeScreen:
			screens.append(["pose", cur])
			cur.done.emit({"moves": [], "new": {"anchor": Vector2.ZERO, "rot": 0, "flip": false}})
		elif cur is BestiaryPrompt:
			screens.append(["choix (défaut)", cur])
			cur._keep()
		elif cur is DrawScreen:
			screens.append(["dessin (retour : %s)" % ("oui" if cur.cfg.get("cancel", false) else "non"), cur])
			for x in range(4, 28):
				cur.img.set_pixel(x, 20, Pal.SHADES[3][1])
			cur._recount()
			cur._validate()
	return screens.map(func(e): return e[0])
