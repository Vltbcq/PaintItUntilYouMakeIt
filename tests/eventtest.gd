extends Node
## Test des événements de boutique : fréquences, grattage, enchère, restaurateur, mécène, étoile.
## Godot --path . res://tests/eventtest.tscn [-- <dossier de captures>]

var fails := 0
var shots := ""
var got_done = null


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _shot(name: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots + "/" + name + ".png")


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	await get_tree().process_frame
	_setup()

	# --- Fréquences : ~4 % des boutiques par événement (case 1 fois sur 2 × 8 %)
	var cnt := {}
	var n := 4000
	Run.wave = 6
	Run.set_amulet_art("sablier", _blob(16, 20), "")
	Run.add_amulet("sablier", Run.amulet_art["sablier"].image, Vector2i(20, 20))   # le Restaurateur a du travail
	for k in n:
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		for o in Run.shop_offers:
			if o.type in Run.EVENTS or o.type == "heal":
				cnt[o.type] = int(cnt.get(o.type, 0)) + 1
	var line := []
	var ok := true
	for ev in Run.EVENTS:
		var pct := 100.0 * int(cnt.get(ev, 0)) / n
		line.append("%s %.1f%%" % [ev, pct])
		ok = ok and pct > 5.5 and pct < 8.5
	print("     fréquences : ", ", ".join(line), ", potions %.1f%%" % (100.0 * int(cnt.get("heal", 0)) / n))
	var both := 0
	for k in 2000:
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		var types: Array = Run.shop_offers.map(func(o): return o.type)
		if "heal" in types and types.any(func(t): return t in Run.EVENTS):
			both += 1
	print("     potion ET événement dans la même boutique : %.1f%%" % (100.0 * both / 2000))
	_check(ok, "chaque événement dans ~7 % des boutiques")
	_check(both > 2000 * 0.12, "potion et événement peuvent tomber ensemble")
	# Un événement joué : plus d'événement dans cette boutique, même en relançant
	Run.seed_v = randi()
	Run.new_shop()
	Run.shop_offers.append(Run.make_event("patron"))
	Run.shop_offers[-1].sold = true
	var again := 0
	for k in 200:
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		again += Run.shop_offers.filter(func(o): return o.type in Run.EVENTS).size()
	_check(again == 0, "événement joué : plus d'autre événement en relançant (%d)" % again)
	Run.seed_v = randi()
	Run.new_shop()
	var back := 0
	for k in 200:
		Run.seed_v = randi()
		Run.new_shop()
		back += Run.shop_offers.filter(func(o): return o.type in Run.EVENTS).size()
	_check(back > 30, "boutique suivante : les événements reviennent")
	# Le Capital : prix moyen de la vague
	for w in [1, 8, 15]:
		Run.wave = w
		var s := 0.0
		var m := 0
		for k in 1500:
			Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
			Run.roll_shop()
			for o in Run.shop_offers:
				if o.type in ["weapon", "amulet"] and not (o.type == "amulet" and o.id == "capital"):
					s += o.price
					m += 1
		var avg := Run.avg_item_price()
		print("     Capital vague %d : prix moyen calculé %d, mesuré %.1f" % [w, avg, s / m])
		_check(absf(avg - s / m) <= maxf(3.0, s / m * 0.12), "Capital : prix moyen juste en vague %d" % w)
	Run.wave = 8
	Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
	Run.roll_shop()
	Run.shop_offers.append({"type": "amulet", "id": "capital", "rar": 2, "price": 999, "sold": false})
	Run.apply_capital()
	_check(int(Run.shop_offers[-1].price) == Run.avg_item_price(), "Capital : il coûte le prix moyen")
	Run.set_amulet_art("capital", _blob(16, 20), "")
	Run.add_amulet("capital", Run.amulet_art["capital"].image, Vector2i(22, 22))
	Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
	Run.roll_shop()
	var same := Run.shop_offers.filter(func(o): return o.type in ["weapon", "amulet"]).all(func(o): return int(o.price) == Run.avg_item_price())
	var capital_again := Run.shop_offers.any(func(o): return o.type == "amulet" and o.id == "capital")
	_check(same and not capital_again, "Capital possédé : tout au prix moyen (● %d), plus jamais reproposé" % Run.avg_item_price())
	Run.amulets = []
	Run.recompute()
	# Case opening : que des caisses, moins chères que leur contenu, et on peut laisser l'objet
	Run.set_amulet_art("case_opening", _blob(16, 20), "")
	Run.add_amulet("case_opening", Run.amulet_art["case_opening"].image, Vector2i(24, 24))
	Run.wave = 8
	Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
	Run.roll_shop()
	var only_cases := Run.shop_offers.filter(func(o): return o.type in ["weapon", "amulet"]).is_empty() 		and Run.shop_offers.any(func(o): return o.type == "case")
	_check(only_cases, "Case opening : la boutique ne vend que des caisses")
	for tier in 4:
		for kind in ["weapon", "amulet"]:
			var c := Run.make_case(tier, kind)
			var val := 0.0
			var rars := [0, 0, 0, 0]
			for k in 2000:
				var it := Run.roll_case_item(tier, kind)
				rars[int(it.rar)] += 1
				val += (WeaponDB.PRICE if kind == "weapon" else AmuletDB.PRICE)[int(it.rar)] * Run.price_mult()
			val /= 2000.0
			print("     %s %s : prix ● %d, valeur moyenne du contenu %.0f, raretés %s" % [Run.CASE_NAMES[tier], kind, c.price, val, rars])
			_check(c.price < val * 0.9, "Case opening : %s (%s) moins chère que son contenu" % [Run.CASE_NAMES[tier], kind])
	Run.gold = 500
	var cshop := _shop([Run.make_case(0, "weapon"), Run.make_case(1, "amulet"), Run.make_case(2, "weapon"), Run.make_case(2, "amulet"), Run.make_event("scratch")])
	await get_tree().process_frame
	await _shot("boutique_caisses")
	cshop.queue_free()
	var shop := _shop([Run.make_case(2, "amulet")])
	shop._open_case(0)
	await get_tree().create_timer(2.0).timeout
	await _shot("caisse_ouverture")
	await get_tree().create_timer(3.0).timeout
	await _shot("caisse_ouverte")
	var strip = shop.ev_layer.find_children("*", "", true, false).filter(func(c): return c.has_method("spin_to"))[0]
	var tip: String = strip._get_tooltip(strip.size / 2.0)
	print("     infobulle sous le curseur : ", tip.replace("
", " / "))
	_check(tip.length() > 10, "Case opening : survoler un objet de la bande montre ce qu'il fait")
	var leave: Array = shop.ev_layer.find_children("*", "Button", true, false).filter(func(b): return b.text == "Laisser")
	_check(leave.size() == 1 and not leave[0].disabled and Run.gold == 500 - int(Run.shop_offers[0].price), "Case opening : caisse payée, on peut laisser l'objet")
	if leave.size() == 1:
		leave[0].pressed.emit()
	await get_tree().process_frame
	_check(Run.shop_offers.size() == 1 and Run.shop_offers[0].sold, "Case opening : objet laissé, rien d'ajouté")
	shop.queue_free()
	Run.amulets = []
	Run.recompute()
	# Enchères : toujours épique ou légendaire
	var low := 0
	for k in 300:
		var a := Run.make_event("auction")
		if int(a.item.rar) < 2 or int(a.bid) >= int(a.value) or int(a.cap) < int(a.value * 0.7) - 1:
			low += 1
	_check(low == 0, "enchère : épique+, départ 60 %, plafond 70-140 %")

	# --- Grattage : ~1 chance sur 3
	shop = _shop([Run.make_event("scratch")])
	var wins := 0
	var tries := 60
	for k in tries:
		Run.gold = 100
		Run.star_buff = 0.0
		Run.shop_offers[0].sold = false
		shop._open_scratch(0)
		var card = shop.ev_layer.find_children("*", "", true, false).filter(func(c): return c.has_method("reveal_all"))[0]
		if k == 0:
			await get_tree().process_frame
			card._scratch(0, Vector2(40, 50))
			card._scratch(1, Vector2(30, 40))
			await _shot("grattage_en_cours")
		card.reveal_all()
		if k == 0:
			await _shot("grattage_fini")
		if Run.gold != 100 - Run.SCRATCH_PRICE or Run.star_buff > 0.0:
			wins += 1
		shop.ev_layer.queue_free()
		shop.ev_layer = null
	print("     grattage : %d gagnants sur %d" % [wins, tries])
	_check(wins >= 8 and wins <= 34, "grattage : gagne environ 1 fois sur 3")
	shop.queue_free()

	# --- Enchère : on relance jusqu'au bout
	Run.gold = 500
	var auc := Run.make_event("auction")
	auc.cap = int(auc.bid) + 30   # plafond connu pour le test (gagnable en 3 mises)
	shop = _shop([auc])
	shop._open_auction(0)
	await get_tree().process_frame
	await _shot("enchere")
	got_done = null
	shop.done.connect(func(r): got_done = r)
	var guard := 0
	while got_done == null and guard < 40:
		guard += 1
		var b20: Button = shop.ev_layer.find_children("*", "Button", true, false).filter(func(b): return b.text == "+20")[0] if shop.ev_layer else null
		if b20 and not b20.disabled:
			b20.pressed.emit()
		await get_tree().create_timer(0.8).timeout
	_check(got_done != null and got_done.a == "buy", "enchère : adjugée → achat lancé")
	if got_done != null:
		var won: Dictionary = Run.shop_offers[got_done.i]
		print("     enchère : %s %s adjugé ● %d (prix habituel %d, plafond %d)" % [won.type, won.get("wtype", won.get("id", "")), won.price, auc.value, auc.cap])
		_check(int(won.price) > int(auc.bid) and int(won.price) <= int(auc.cap) + 20 and int(won.rar) >= 2, "enchère : prix payé cohérent, objet épique+")
	shop.queue_free()

	# --- Enchère : 3 mises maximum, puis le collectionneur l'emporte
	Run.gold = 5000
	var auc2 := Run.make_event("auction")
	auc2.cap = 99999
	shop = _shop([auc2])
	shop._open_auction(0)
	await get_tree().process_frame
	got_done = null
	shop.done.connect(func(r): got_done = r)
	var presses := 0
	guard = 0
	while not auc2.sold and guard < 40:
		guard += 1
		var b5: Array = shop.ev_layer.find_children("*", "Button", true, false).filter(func(b): return b.text == "+5") if shop.ev_layer else []
		if not b5.is_empty() and not b5[0].disabled:
			presses += 1
			b5[0].pressed.emit()
		await get_tree().create_timer(0.8).timeout
	await get_tree().create_timer(1.5).timeout
	_check(auc2.sold and presses <= 3 and (got_done != null or Run.gold == 5000), "enchère : 3 mises max (%d), puis vendue ou perdue sans payer" % presses)
	shop.queue_free()

	# --- Restaurateur : amulette commune → rare, l'ancienne est remplacée
	_setup()
	Run.gold = 100
	Run.set_amulet_art("sablier", _blob(16, 20), "")
	Run.add_amulet("sablier", Run.amulet_art["sablier"].image, Vector2i(20, 20))
	shop = _shop([Run.make_event("restorer")])
	shop._open_restorer(0)
	await get_tree().process_frame
	await _shot("restaurateur")
	got_done = null
	shop.done.connect(func(r): got_done = r)
	# (les cases des amulettes : 52×62 ; leur fiche s'affiche au survol)
	var cells := shop.ev_layer.find_children("*", "Button", true, false).filter(func(b): return b.custom_minimum_size == Vector2(52, 62))
	_check(cells.size() == 1, "restaurateur : propose l'amulette possédée")
	if cells.size() == 1:
		cells[0].pressed.emit()
	await get_tree().process_frame
	if got_done != null:
		var ro: Dictionary = Run.shop_offers[got_done.i]
		_check(ro.type == "amulet" and int(ro.rar) == 1 and ro.replace.id == "sablier" and int(ro.price) > 0, "restaurateur : amulette rare, remplace le Sablier, payant (● %d)" % int(ro.price))
	else:
		_check(false, "restaurateur : achat lancé")
	shop.queue_free()
	# jamais d'objet « à l'achat » (Boîte de Pandore, Diplôme) dans ce qu'il rend
	var rp_ids := []
	for r in [1, 2, 3]:
		rp_ids.append_array(Run.restore_pool(r).map(func(d): return d.id))
	_check(not "pandore" in rp_ids and not "diplome" in rp_ids and not rp_ids.is_empty(), "restaurateur : ni Pandore ni Diplôme")

	# --- Mécène
	_setup()
	Run.gold = 10
	shop = _shop([Run.make_event("patron")])
	shop._open_patron(0)
	await get_tree().process_frame
	await _shot("mecene")
	var signs := shop.ev_layer.find_children("*", "Button", true, false).filter(func(b): return b.text == "Signer")
	signs[1].pressed.emit()
	_check(Run.gold == 10 + Run.patron_gold(1) and Run.patron == "elites", "mécène : +%d or (vague %d), contrat élites" % [Run.patron_gold(1), Run.wave])
	var w0 := Run.wave
	Run.wave = 10
	_check(Run.patron_gold(0) == 100 and Run.patron_gold(1) == 125, "mécène : 100 / 125 or en vague 10")
	Run.wave = w0
	shop.queue_free()
	await get_tree().process_frame
	# la vague suivante : 3 élites promises + étoile du grattage
	Run.star_buff = 15.0
	var base_dmg: float = Run.stats.dmg
	Run.wave = 4
	var arena := Arena.new()
	add_child(arena)
	_check(Run.patron == "" and arena.patron_elites.size() == 8, "mécène : 8 élites programmées pour la vague")
	_check(is_equal_approx(Run.stats.dmg - base_dmg, 15.0), "étoile : +15 %% dégâts pendant la vague (%+.0f)" % (Run.stats.dmg - base_dmg))
	var seen_el := {}
	for f in 60 * 50:
		arena.player.inv = 999.0
		arena._process(1.0 / 60.0)
		for e in arena.enemies:
			if e.elite:
				seen_el[e.get_instance_id()] = true
		if arena.ended:
			break
	print("     élites apparues pendant la vague : %d" % seen_el.size())
	_check(arena.patron_elites.is_empty() and seen_el.size() >= 8, "mécène : les 8 élites sont arrivées")
	_check(Run.wave_dmg == 0.0 and is_equal_approx(Run.stats.dmg, base_dmg), "étoile : fini après la vague")
	arena.queue_free()
	Run.active = false
	print("EVENTS : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _shop(offers: Array) -> ShopScreen:
	Run.shop_offers = offers
	var shop := ShopScreen.new()
	shop.size = Vector2(640, 360)
	add_child(shop)
	return shop


func _setup() -> void:
	Run.start(0, 1)
	Run.wave = 4
	Run.set_character(_blob(32, 180), "")
	Run.set_weapon_art("epee", 1, _blob(32, 90), "", null, "")
	Run.add_weapon("epee", 1, 0, Vector2(8, 0))
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3)), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()


func _blob(size: int, px: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, Pal.SHADES[1][1])
	return img
