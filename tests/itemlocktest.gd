extends Node
## Test des objets verrouillés par succès : boutique filtrée, déblocage en fin de partie, récap.
## Godot --path . res://tests/itemlocktest.tscn [-- <capture.png>]

var fails := 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL " + what)
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	Meta.data = Meta.data.duplicate(true)
	Meta.data.item_unlocks = {}
	Meta.data.pending_unlocks = []
	await get_tree().process_frame
	var nw := 0
	var na := 0
	for k in ItemUnlockDB.CONDS:
		if k.begins_with("w:"):
			nw += 1
			_check(WeaponDB.TYPES.has(k.substr(2)), "arme existe : " + k)
		elif k.begins_with("f:"):
			_check(not FamiliarDB.get_def(k.substr(2)).is_empty(), "familier existe : " + k)
		else:
			na += 1
			_check(not AmuletDB.get_def(k.substr(2)).is_empty(), "amulette existe : " + k)
		_check(ItemUnlockDB.text(ItemUnlockDB.CONDS[k]) != "?", "condition lisible : " + k)
	print("verrouillés : %d armes / %d amulettes" % [nw, na])

	# Chaque condition est unique (objets ET défis de l'Atelier), et les 3 cartes ont leur part
	var seen := {}
	var per_map := {1: 0, 2: 0, 3: 0}
	for k in ItemUnlockDB.CONDS:
		var c: Dictionary = ItemUnlockDB.CONDS[k]
		var t := ItemUnlockDB.text(c)
		_check(not seen.has(t), "condition unique : %s et %s (%s)" % [k, seen.get(t, ""), t])
		seen[t] = k
		var m := int(c.get("map", 0))
		if String(c.kind) == "boss":
			var bd := EnemyDB.get_def(c.boss)
			_check(not bd.is_empty(), "boss existe : " + String(c.boss))
			m = int(bd.get("map", 1))
			_check((MapDB.MAPS[m].bosses as Dictionary).values().any(func(l): return c.boss in l), "le boss %s est bien sur la carte %d" % [c.boss, m])
		if m > 0:
			per_map[m] += 1
	for a in AchievementDB.LIST:
		_check(not seen.has(a.desc), "défi d'Atelier unique : %s et %s" % [a.id, seen.get(a.desc, "")])
		seen[a.desc] = a.id
	print("par carte : ", per_map)
	for m in per_map:
		_check(per_map[m] >= 8, "carte %d : au moins 8 objets à y débloquer (%d)" % [m, per_map[m]])
	for b in ["virus", "bug", "tableur", "curseur_boss", "geometre"]:
		_check(ItemUnlockDB.CONDS.values().any(func(c): return c.get("boss", "") == b), "un objet pour le boss " + b)
	# conditions liées à une carte : pas ailleurs
	var C := ItemUnlockDB.CONDS
	_check(ItemUnlockDB.met(C["w:avion"], {"cleared": 10, "map": 1}) and not ItemUnlockDB.met(C["w:avion"], {"cleared": 10, "map": 2}), "vague 10 sur La Feuille seulement")
	_check(ItemUnlockDB.met(C["a:nuit_etoilee"], {"win": true, "map": 3, "diff": 1}) and not ItemUnlockDB.met(C["a:nuit_etoilee"], {"win": true, "map": 1}), "victoire sur L'Écran seulement")
	_check(ItemUnlockDB.met(C["f:pavel"], {"win": true, "map": 2, "diff": 1}) and not ItemUnlockDB.met(C["f:pavel"], {"win": true, "map": 2, "diff": 0}), "victoire Tableau noir en Croquis")
	_check(not ItemUnlockDB.met(C["w:avion"], {"cleared": 15}), "sans carte dans le contexte (anciennes sauvegardes) : pas rempli")
	_check(ItemUnlockDB.met(C["a:spatule"], {"cleared": 4, "weapons": 2, "melee": 2}) and not ItemUnlockDB.met(C["a:spatule"], {"cleared": 4, "weapons": 2, "melee": 1, "ranged": 1}), "Spatule : que de la mêlée")
	_check(ItemUnlockDB.met(C["a:viseur"], {"cleared": 4, "weapons": 3, "ranged": 3}) and not ItemUnlockDB.met(C["a:viseur"], {"cleared": 3, "weapons": 3, "ranged": 3}), "Viseur : que de la distance, vague 4")
	_check(ItemUnlockDB.met(C["a:pierre_aiguiser"], {"legends": 2}) and not ItemUnlockDB.met(C["a:pierre_aiguiser"], {"legends": 1, "legend": true}), "Pierre à aiguiser : 2 légendaires")
	# v0.12 : posséder 25 amulettes (Satellite), finir une vague sans armure (Slip)
	_check(ItemUnlockDB.met(C["a:satellite"], {"amulets": 25}) and not ItemUnlockDB.met(C["a:satellite"], {"amulets": 24}), "Satellite : 25 amulettes en même temps")
	_check(ItemUnlockDB.met(C["a:canon_verre"], {"cleared": 8, "stats": {"armor": 0.0}}) and not ItemUnlockDB.met(C["a:canon_verre"], {"cleared": 8, "stats": {"armor": 2.0}})
		and not ItemUnlockDB.met(C["a:canon_verre"], {"cleared": 7, "stats": {"armor": -1.0}}) and not ItemUnlockDB.met(C["a:canon_verre"], {"cleared": 9}), "Slip : vague 8 avec 0 d'armure ou moins")
	_check(ItemUnlockDB.met(C["a:ceinture"], {"clean": true, "cleared": 12, "map": 2}) and not ItemUnlockDB.met(C["a:ceinture"], {"clean": true, "cleared": 12, "map": 1}), "Ceinture de sécurité : vague 12 sans dégât sur Le Tableau noir")
	_check(ItemUnlockDB.text(C["a:punching_ball"]) == "Atteins 150 PV max dans une partie.", "texte : " + ItemUnlockDB.text(C["a:punching_ball"]))
	for free in ["red_light", "green_light", "cigarette", "biere", "soda", "pinata", "poil_gratter", "merchandising", "regime", "lance_pierre", "paille"]:
		_check(Meta.item_open("a:" + free), "commune libre dès le début : " + free)
	var boss10 := AchievementDB.get_def("boss10")
	_check(AchievementDB.met(boss10, {"cleared": 10, "map": 2}) and not AchievementDB.met(boss10, {"cleared": 10, "map": 1}), "défi boss 10 : Tableau noir")
	var maitre := AchievementDB.get_def("maitre")
	_check(AchievementDB.met(maitre, {"win": true, "map": 3}) and not AchievementDB.met(maitre, {"win": true, "map": 1, "diff": 4}), "défi Maître peintre : L'Écran")
	# le contexte d'une vraie partie compte la mêlée et les légendaires
	Run.start(0, 1)
	Run.weapons.clear()
	var wimg := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	wimg.fill_rect(Rect2i(2, 8, 20, 6), Pal.INK)
	Run.set_weapon_art("epee", 3, wimg, "", null, "")
	Run.add_weapon("epee", 3, 0, Vector2.ZERO)
	Run.add_weapon("epee", 3, 0, Vector2.ZERO)
	var rc := Run.achievement_ctx(4)
	_check(int(rc.melee) == 2 and int(rc.ranged) == 0 and int(rc.legends) == 2 and int(rc.map) == 1, "contexte : 2 armes de mêlée légendaires")
	# déjà débloqué = gardé, même si la condition a changé
	Meta.data.item_unlocks = {"w:eventail": true}
	_check(Meta.item_open("w:eventail"), "un objet déjà débloqué le reste")
	Meta.data.item_unlocks = {}

	# Boutique : jamais d'objet verrouillé
	Run.start(0, 1)
	var bad := 0
	for n in 400:
		Run.wave = 1 + n % 20
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		for o in Run.shop_offers:
			var key := ""
			if o.type == "weapon":
				key = ItemUnlockDB.key_weapon(o.wtype)
			elif o.type == "amulet":
				key = ItemUnlockDB.key_amulet(o.id)
			if key != "" and not Meta.item_open(key):
				bad += 1
	_check(bad == 0, "boutique sans objet verrouillé (%d fautifs)" % bad)

	# Pendant la partie : en attente, pas encore dispo
	Run.gold = 200
	Run.stats.lifesteal = 30.0
	Meta.check_achievements(Run.achievement_ctx(3))
	var pend: Array = Meta.data.pending_unlocks
	_check("w:pinceau_dore" in pend and "a:calice" in pend, "succès obtenus en partie -> en attente")
	_check(not Meta.item_open("w:pinceau_dore"), "pas dispo avant la fin de la partie")
	var got := Meta.apply_pending_unlocks()
	_check(Meta.item_open("w:pinceau_dore") and Meta.item_open("a:calice"), "dispo après la fin de la partie")
	_check(Meta.item_open("w:epee"), "arme classique toujours dispo")

	# Récap : liste qui défile quand il y a beaucoup de lignes
	var many := got.duplicate()
	for k in ItemUnlockDB.CONDS.keys().slice(0, 20):
		many.append(k)
	var scr := ChoiceScreens.end_run(false, 42, many)
	scr.size = Vector2(640, 360)
	add_child(scr)
	for f in 3:
		await get_tree().process_frame
	var scs := scr.find_children("*", "ScrollContainer", true, false)
	_check(scs.size() == 1, "récap avec défilement")
	if scs.size() == 1:
		var sc: ScrollContainer = scs[0]
		_check(sc.get_v_scroll_bar().max_value > sc.size.y, "la liste dépasse et défile")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[0])
	scr.queue_free()

	# « ! » : jamais vu -> nouveau une seule fois
	Meta.data.seen_items = {}
	Run.wave = 3
	Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
	Run.roll_shop()
	var first_new := true
	for o in Run.shop_offers:
		if o.type in ["weapon", "amulet"]:
			first_new = first_new and o.get("new", false)
	_check(first_new, "première boutique : tout est nouveau")
	var again := 0
	var seen_before := (Meta.data.seen_items as Dictionary).duplicate()
	for n in 30:
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		var here := {}
		for o in Run.shop_offers:
			if not o.type in ["weapon", "amulet"]:
				continue
			var key := ItemUnlockDB.key_weapon(o.wtype) if o.type == "weapon" else ItemUnlockDB.key_amulet(o.id)
			if o.new and seen_before.has(key):
				again += 1
			here[key] = true
		seen_before.merge(here)
	_check(again == 0, "un objet déjà vu n'a plus de « ! » (%d fautifs)" % again)
	Meta.data.seen_items = {}
	Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
	Run.roll_shop()
	Run.set_character(Image.create(32, 32, false, Image.FORMAT_RGBA8), "")
	var shop := ShopScreen.new()
	shop.size = Vector2(640, 360)
	add_child(shop)
	for f in 3:
		await get_tree().process_frame
	if args.size() > 1:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[1])
	shop.queue_free()
	var cx := CodexScreen.new("armes", "retouche")
	cx.size = Vector2(640, 360)
	add_child(cx)
	for f in 3:
		await get_tree().process_frame
	if args.size() > 2:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[2])
	Run.active = false
	print("ITEMLOCK : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)
