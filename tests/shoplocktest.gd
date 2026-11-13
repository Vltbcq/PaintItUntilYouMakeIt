extends Node
## Test : cadenas de la boutique. Un objet verrouillé reste en vitrine quand on relance et à la
## boutique suivante (au prix de la nouvelle vague) ; un objet acheté ou devenu impossible ne l'est plus.
## Godot --headless --path . res://tests/shoplocktest.tscn

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _find(pred: Callable) -> Dictionary:
	for k in 200:
		for o in Run.shop_offers:
			if pred.call(o):
				return o
		Run.seed_v = randi()
		Run.roll_shop()
	return {}


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.data = Meta.data.duplicate(true)
	for k in ItemUnlockDB.CONDS:
		Meta.data.item_unlocks[k] = true
	Run.start(0, 1)
	Run.wave = 3
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(4, 4, 16, 16), Pal.SHADES[1][1])
	Run.set_character(img, "")
	Run.new_shop()

	var w := _find(func(o): return o.type == "weapon")
	var a := _find(func(o): return o.type == "amulet" and int(AmuletDB.get_def(o.id).get("limit", 1 if int(o.rar) == 3 else 0)) == 0)
	_check(not w.is_empty() and not a.is_empty(), "une arme et une amulette en vitrine")
	# (les deux doivent être dans la même vitrine : on verrouille la première, puis on cherche l'autre)
	w.locked = true
	Run.roll_shop()
	_check(Run.shop_offers.has(w), "relance : l'arme verrouillée reste en vitrine")
	var a2 := _find(func(o): return o.type == "amulet" and o != w and int(AmuletDB.get_def(o.id).get("limit", 1 if int(o.rar) == 3 else 0)) == 0)
	a2.locked = true
	Run.roll_shop()
	_check(Run.shop_offers.has(w) and Run.shop_offers.has(a2), "relance : les 2 objets verrouillés restent")

	# Boutique suivante (comme main.gd entre deux vagues) : toujours là, au prix de la nouvelle vague
	var p0 := int(w.price)
	Run.close_shop()
	_check(Run.shop_offers.size() == 2 and Run.shop_pending(), "fin de vague : seuls les 2 objets verrouillés attendent, la boutique reste à tirer")
	Run.wave = 9
	if Run.shop_pending():
		Run.new_shop()
	_check(not Run.shop_pending() and Run.shop_offers.size() > 2, "la nouvelle boutique est tirée autour d'eux")
	_check(Run.shop_offers.has(w) and int(w.price) == roundi(WeaponDB.PRICE[w.rar] * Run.price_mult()) and int(w.price) > p0,
		"vague suivante : l'arme verrouillée est là, au nouveau prix (%d → %d)" % [p0, int(w.price)])

	# Sauvegarde de la partie : le cadenas est gardé
	var sv := Run.to_save("shop")
	Run.shop_offers = []
	Run.from_save(sv)
	_check(Run.shop_offers.any(func(o): return o.get("locked", false)), "sauvegarde : le cadenas est gardé")
	_check(not Run.shop_pending(), "reprise en pleine boutique : elle n'est pas retirée")
	# Quitté juste après la vague (avant la boutique) : à la reprise, la boutique se tire autour des objets gardés
	var saved := Run.shop_offers.duplicate(true)
	Run.close_shop()
	sv = Run.to_save("after")
	Run.shop_offers = []
	Run.from_save(sv)
	_check(Run.shop_pending() and Run.shop_offers.size() == 2, "reprise après la vague : les objets verrouillés attendent toujours")
	Run.new_shop()
	_check(Run.shop_offers.filter(func(o): return o.get("locked", false)).size() == 2, "... et sont dans la nouvelle boutique")
	Run.shop_offers = saved

	# Acheté : il ne reste pas ; déverrouillé : il part à la relance
	for o in Run.shop_offers:
		if o.get("locked", false) and o.type == "weapon":
			o.sold = true
		elif o.get("locked", false):
			o.locked = false
	Run.roll_shop()
	_check(not Run.shop_offers.any(func(o): return o.get("locked", false)), "acheté ou déverrouillé : plus gardé")

	# Familier verrouillé puis acheté ailleurs entre-temps : il n'est plus proposé
	Run.shop_offers.append({"type": "familiar", "id": "perroquet", "rar": 1, "price": 30, "sold": false, "locked": true})
	Run.familiars.append("perroquet")
	Run.roll_shop()
	_check(not Run.shop_offers.any(func(o): return o.type == "familiar" and o.id == "perroquet"), "familier déjà possédé : le cadenas ne le garde pas")
	print("SHOPLOCK : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
