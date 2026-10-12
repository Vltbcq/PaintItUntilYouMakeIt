extends Node
## Les 19 amulettes communes de la v0.12 (petits effets à condition).
## Godot --headless --path . res://tests/v012amutest.tscn

const IDS := ["red_light", "green_light", "cigarette", "biere", "soda", "pinata", "avis_recherche", "sardines",
	"poil_gratter", "combo", "merchandising", "coupon", "regime", "perche_selfie", "lance_pierre", "paille",
	"airbag", "trophee", "pouce"]

var fails := 0
var arena: Arena


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _blob(size: int, px: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var side := int(ceil(sqrt(float(px))))
	@warning_ignore("integer_division")
	img.fill_rect(Rect2i((size - side) / 2, (size - side) / 2, side, side), Pal.SHADES[0][1])
	return img


func _setup() -> void:
	Run.start(0, 1)
	Run.wave = 3
	Run.set_character(_blob(32, 180), "")
	Run.set_weapon_art("epee", 0, _blob(32, 90), "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3)), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()


func _give(id: String, n := 1) -> void:
	for k in n:
		if not Run.amulet_art.has(id):
			Run.set_amulet_art(id, _blob(16, 20), "")
		Run.add_amulet(id, Run.amulet_art[id].image, Vector2i(30, 30))
	Run.recompute()


func _arena() -> void:
	if is_instance_valid(arena):
		arena.ended = true
		arena.queue_free()
		await get_tree().process_frame
	arena = Arena.new()
	add_child(arena)
	await get_tree().process_frame
	arena.spawn_acc = -9999.0
	for e in arena.enemies.duplicate():
		arena.enemies.erase(e)
		e.queue_free()


## Un ennemi très solide, sans esquive, pour mesurer un coup.
func _dummy(hp_frac := 1.0) -> Enemy:
	var e := arena.spawn_enemy_now("tache", arena.player.position + Vector2(200, 0), false)
	e.max_hp = 100000.0
	e.hp = e.max_hp * hp_frac
	e.dodge = 0.0
	e.speed = 0.0
	return e


func _mult(e: Enemy) -> float:
	return arena._amulet_dmg_mult(e, {"kind": "melee"})


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	await get_tree().process_frame

	# --- Catalogue : communes, avec un malus, une description et un nom dans les deux langues
	var n_ok := 0
	for id in IDS:
		var d := AmuletDB.get_def(id)
		if not d.is_empty() and int(d.rar) == 0 and d.has("malus") and not AmuletDB.describe(d).contains("{"):
			n_ok += 1
		else:
			print("   catalogue : ", id)
	_check(n_ok == IDS.size(), "les %d amulettes existent, communes, avec un malus (%d)" % [IDS.size(), n_ok])
	var fr_names := IDS.map(func(id): return String(AmuletDB.get_def(id).name))
	Loc.ignore_env = true
	Loc.apply("en")
	var en_bad := []
	for k in IDS.size():
		var d := AmuletDB.get_def(IDS[k])
		if not LangEn.D.has(fr_names[k]) and not fr_names[k] in ["Red light", "Green light", "Cigarette", "Soda", "Piñata", "Sardines", "Combo", "Merchandising", "Coupon", "Airbag"]:
			en_bad.append(fr_names[k])
		if AmuletDB.describe(d).contains("dégâts") or AmuletDB.describe(d).contains("vague") or AmuletDB.describe(d).contains(" tu "):
			en_bad.append(String(d.id) + " (description)")
	_check(en_bad.is_empty(), "traduction anglaise : noms et descriptions (%s)" % str(en_bad))
	_check(String(AmuletDB.get_def("pouce").name) == "Time Out" and AmuletDB.describe(AmuletDB.get_def("airbag")).ends_with("UNIQUE"), "anglais : Pouce = Time Out, les uniques l'annoncent")
	Loc.apply("fr")
	_check(int(AmuletDB.get_def("coupon").limit) == 3 and int(AmuletDB.get_def("paille").limit) == 2 and int(AmuletDB.get_def("pouce").limit) == 1 and not AmuletDB.get_def("soda").has("limit"), "limites : 3, 2, unique, ou sans limite")

	# --- Red light / Green light
	_setup()
	_give("red_light", 2)
	_give("green_light")
	await _arena()
	var e := _dummy(0.6)
	arena.player.moving = false
	var still := _mult(e)
	arena.player.moving = true
	var move := _mult(e)
	_check(absf(still - 1.2) < 0.001 and absf(move - 1.08) < 0.001, "Red light ×2 immobile : ×%.2f ; Green light en mouvement : ×%.2f" % [still, move])

	# --- Cigarette / Bière
	_setup()
	_give("cigarette")
	_give("biere", 2)
	await _arena()
	arena.player.moving = false
	var full := _mult(_dummy(1.0))
	var mid := _mult(_dummy(0.6))
	var low := _mult(_dummy(0.2))
	_check(absf(full - 1.25) < 0.001 and absf(mid - 1.0) < 0.001 and absf(low - 1.5) < 0.001, "Cigarette à pleine vie ×%.2f, rien à 60 %% (×%.2f), Bière ×2 sous 30 %% : ×%.2f" % [full, mid, low])

	# --- Soda, Pouce, Régime : au début de la vague
	_setup()
	Run.hp = 5.0
	await _arena()
	var r0 := arena.player.radius
	var hp0 := arena.player.hp
	_give("soda", 2)
	_give("pouce")
	_give("regime", 3)
	Run.hp = 5.0
	await _arena()
	var p := arena.player
	# (le Régime retire des PV max : le soin s'arrête au maximum)
	_check(absf(p.hp - minf(p.max_hp, hp0 + 6.0)) < 0.01 and p.hp > hp0, "Soda ×2 : +6 PV au début de la vague, sans dépasser le max (%.0f → %.0f / %.0f)" % [hp0, p.hp, p.max_hp])
	_check(absf(p.radius / r0 - pow(0.92, 3)) < 0.001, "Régime ×3 : zone de touche ×%.2f" % (p.radius / r0))
	var before := p.hp
	p.take_hit(3.0, 0, null)
	_check(p.hp == before and p.inv > 4.0, "Pouce : pas de dégâts au début de la vague")
	p.inv = 0.0
	p.st = p.st.duplicate()
	p.st.dodge = 0.0
	p.take_hit(1.0, 0, null)
	_check(p.hp < before, "Pouce : après les 5 secondes, on reprend des dégâts")

	# --- Piñata, Poil à gratter, Sardines
	_setup()
	_give("pinata", 2)
	_give("poil_gratter")
	_give("sardines")
	await _arena()
	p = arena.player
	p.st = p.st.duplicate()
	p.st.dodge = 0.0
	p.max_hp = 500.0
	p.hp = 500.0
	var g0 := Run.gold
	for k in 4:
		p.inv = 0.0
		p.take_hit(2.0, 0, null)
	_check(Run.gold - g0 == 4, "Piñata ×2 : 4 coups reçus = +4 or (%d)" % (Run.gold - g0))
	_check(p.itch_t > 1.5, "Poil à gratter : 2 s de vitesse après un coup")
	arena.crowd = 0
	p.inv = 0.0
	var h := p.hp
	p.take_hit(30.0, 0, null)
	var alone := h - p.hp
	arena.crowd = 5
	p.inv = 0.0
	h = p.hp
	p.take_hit(30.0, 0, null)
	var packed := h - p.hp
	_check(packed < alone, "Sardines : entouré de 5 ennemis, le même coup fait moins mal (%.0f contre %.0f)" % [packed, alone])

	# --- Airbag : une fois par vague
	_setup()
	_give("airbag")
	await _arena()
	p = arena.player
	p.st = p.st.duplicate()
	p.st.dodge = 0.0
	p.max_hp = 100.0
	p.hp = 100.0
	var near_e := arena.spawn_enemy_now("tache", p.position + Vector2(30, 0), false)
	near_e.speed = 0.0
	p.god = true
	arena._process(1.0 / 60.0)   # (la grille des ennemis proches est refaite à chaque image)
	p.god = false
	p.inv = 0.0
	p.take_hit(20.0, 0, null)
	_check(not p.airbag_used and near_e.knock.length() < 1.0, "Airbag : rien au-dessus de 30 % des PV")
	p.inv = 0.0
	p.hp = 35.0
	p.take_hit(20.0, 0, null)
	_check(p.airbag_used and near_e.knock.x > 100.0, "Airbag : sous 30 %%, les ennemis proches sont repoussés (%.0f)" % near_e.knock.x)

	# --- Avis de recherche, Trophée, Combo
	_setup()
	_give("avis_recherche", 2)
	_give("trophee")
	_give("combo")
	await _arena()
	var elite := arena.spawn_enemy_now("tache", arena.player.position + Vector2(150, 0), false)
	elite.elite = true
	elite.loot = 0.0
	g0 = Run.gold
	arena.kill_enemy(elite)
	_check(Run.gold - g0 == 4, "Avis de recherche ×2 : +4 or pour une élite (%d)" % (Run.gold - g0))
	var normal := arena.spawn_enemy_now("tache", arena.player.position + Vector2(150, 0), false)
	normal.loot = 0.0
	g0 = Run.gold
	arena.kill_enemy(normal)
	_check(Run.gold == g0, "... rien pour un ennemi normal")
	_check(absf(arena.combo_bonus() - 0.02) < 0.001, "Combo : 2 éliminations = +2 %% de vitesse d'attaque (%.2f)" % arena.combo_bonus())
	for k in 15:
		arena.kill_log.append(arena.elapsed)
	_check(absf(arena.combo_bonus() - 0.10) < 0.001, "Combo : plafonné à +10 %")
	arena.elapsed += 4.0
	arena.hitstop_t = 0.0   # (la mort d'une élite fige le monde un instant)
	arena._process(0.01)
	_check(arena.combo_bonus() == 0.0, "Combo : retombe à 0 après 3 secondes sans tuer")
	var boss := arena.spawn_enemy_now("rature", arena.player.position + Vector2(150, 0), false)
	boss.loot = 0.0
	g0 = Run.gold
	arena.kill_enemy(boss)
	_check(Run.gold - g0 == 15, "Trophée : +15 or pour un boss (%d)" % (Run.gold - g0))

	# --- Lance-pierre : projectiles plus rapides, même portée
	_setup()
	await _arena()
	var b := {"radius": 3.0, "damage": 1.0, "pierce": 0}
	var slow := arena.spawn_bullet(Vector2.ZERO, Vector2(100, 0), b, {}, null, "", 2.0)
	_give("lance_pierre", 2)
	var fast := arena.spawn_bullet(Vector2.ZERO, Vector2(100, 0), b, {}, null, "", 2.0)
	_check(absf(fast.vel.x - 130.0) < 0.01 and absf(fast.vel.x * fast.life - slow.vel.x * slow.life) < 0.01, "Lance-pierre ×2 : vitesse ×1,3 (%.0f), même portée" % fast.vel.x)

	# --- Perche à selfie : allonge des armes de mêlée
	_setup()
	await _arena()
	var wn: WeaponNode = arena.player.find_children("*", "WeaponNode", true, false)[0]
	var reach0 := wn._range_mult()
	_give("perche_selfie", 3)
	_check(absf(wn._range_mult() - reach0 - 0.3) < 0.001, "Perche à selfie ×3 : +30 %% d'allonge (%.2f → %.2f)" % [reach0, wn._range_mult()])

	# --- Boutique : Coupon, Merchandising, Paille
	_setup()
	Run.rerolls = 2
	var rp0 := Run.reroll_price()
	_give("coupon", 3)
	_check(Run.reroll_price() == maxi(1, roundi(rp0 * pow(0.9, 3))) and Run.reroll_price() < rp0, "Coupon ×3 : relance %d → %d" % [rp0, Run.reroll_price()])
	var shop := ShopScreen.new()
	shop.size = Vector2(640, 360)
	add_child(shop)
	await get_tree().process_frame
	var w := {"price": 100}
	var ref0: int = shop._refund(w)
	_give("merchandising", 2)
	_check(ref0 == 40 and shop._refund(w) == 52, "Merchandising ×2 : revente %d → %d" % [ref0, shop._refund(w)])
	shop.queue_free()
	await get_tree().process_frame

	arena.ended = true
	Run.active = false
	print("V012AMU : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
