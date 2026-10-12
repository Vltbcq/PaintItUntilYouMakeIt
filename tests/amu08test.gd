extends Node
## Test : les 14 amulettes de la v0.8 (7 classiques, 7 qui changent le jeu) et leurs 12 nouveaux succès.
## Godot --headless --path . res://tests/amu08test.tscn

var fails := 0
var dot: Image


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _give(id: String) -> void:
	Run.set_amulet_art(id, dot, "")
	Run.add_amulet(id, dot, Vector2i(2, 2))


func _reset() -> void:
	Run.start(0, 1)
	Run.wave = 4
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(4, 4, 16, 16), Pal.SHADES[Pal.FEU][1])
	Run.set_character(img, "")
	for id in EnemyDB.TYPES:
		Run.set_enemy_art(id, img, "")
	Run.recompute()


func _arena() -> Arena:
	var a := Arena.new()
	add_child(a)
	for e in a.enemies.duplicate():
		a.kill_enemy(e)
	a.time_left = 999.0
	return a


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	Meta.data = Meta.data.duplicate(true)
	dot = Image.create_empty(6, 6, false, Image.FORMAT_RGBA8)
	dot.fill(Pal.INK)
	var ids := ["accord_parfait", "bache", "colle_forte", "grattoir", "monocle", "pigment_pur", "toile_tendue",
		"carnet_commandes", "de_pipe", "performance", "reflet", "salle_thematique", "speed_painting", "vernissage"]
	for id in ids:
		_check(not AmuletDB.get_def(id).is_empty() and ItemUnlockDB.CONDS.has("a:" + id), "%s : amulette + succès" % id)

	# --- Accord parfait : synergie à 2 armes
	_reset()
	var wimg := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	wimg.fill_rect(Rect2i(2, 8, 20, 6), Pal.SHADES[Pal.FEU][1])
	Run.set_weapon_art("epee", 0, wimg, "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	Run.add_weapon("epee", 0, 10, Vector2(2, 0))
	_check(Run.active_synergies().is_empty(), "2 armes Feu : pas de synergie normalement")
	_give("accord_parfait")
	_check(Run.active_synergies().has(Pal.FEU), "Accord parfait : synergie Feu dès 2 armes")

	# --- Toile tendue : +10 PV max par boss vaincu
	_reset()
	var hp0: float = Run.stats.max_hp
	_give("toile_tendue")
	Run.bosses = 2
	Run.recompute()
	var hp1: float = Run.stats.max_hp
	var hp_m := AmuletDB.get_def("toile_tendue")
	_check(hp1 >= hp0 + 19.0, "Toile tendue : 2 boss = +20 PV max (%d → %d)" % [hp0, hp1])

	# --- Bâche, Colle forte (boss)
	_reset()
	Run.wave = 5
	var a := _arena()
	await get_tree().process_frame
	seed(8)   # (la vitesse d'un ennemi est tirée au hasard : même tirage pour les deux boss comparés)
	var b0: Enemy = a.spawn_enemy_now("rature", Vector2(100, 100), false)
	var spd0 := b0.speed
	a.spawn_enemy_bullet(b0, Vector2(50, 50), Vector2.RIGHT)
	var d0: float = a.bullets[a.bullets.size() - 1].dmg
	a.queue_free()
	_give("bache")
	_give("colle_forte")
	a = _arena()
	await get_tree().process_frame
	seed(8)
	var b1: Enemy = a.spawn_enemy_now("rature", Vector2(100, 100), false)
	a.spawn_enemy_bullet(b1, Vector2(50, 50), Vector2.RIGHT)
	var d1: float = a.bullets[a.bullets.size() - 1].dmg
	_check(absf(d1 - d0 * 0.75) < 0.01, "Bâche : projectiles de boss -25 %% (%.1f → %.1f)" % [d0, d1])
	_check(absf(b1.speed - spd0 * 0.8) < 0.5, "Colle forte : boss plus lent (%.0f → %.0f)" % [spd0, b1.speed])
	a.queue_free()

	# --- Grattoir et Monocle (armure, esquive)
	_reset()
	a = _arena()
	await get_tree().process_frame
	Run.stats.crit = -100.0
	var e: Enemy = a.spawn_enemy_now("colosse", Vector2(300, 100), false)
	e.armor = 40.0
	e.dodge = 0.0
	var h := e.hp
	a.hit_enemy(e, 10.0, {}, Vector2.RIGHT, 0.0)
	var plain := h - e.hp
	e.dodge = 100.0
	h = e.hp
	a.hit_enemy(e, 10.0, {}, Vector2.RIGHT, 0.0)
	_check(is_equal_approx(e.hp, h), "un ennemi à 100 % d'esquive esquive tout")
	a.queue_free()
	_give("grattoir")
	_give("monocle")
	a = _arena()
	await get_tree().process_frame
	Run.stats.crit = -100.0
	e = a.spawn_enemy_now("colosse", Vector2(300, 100), false)
	e.armor = 40.0
	e.dodge = 100.0
	h = e.hp
	a.hit_enemy(e, 10.0, {}, Vector2.RIGHT, 0.0)
	var got := h - e.hp
	_check(got > plain * 1.1, "Monocle + Grattoir : touché malgré 100 %% d'esquive, l'armure compte 2× moins (%.1f → %.1f)" % [plain, got])
	a.queue_free()

	# --- Reflet, Salle thématique, Speed painting, Performance live
	_reset()
	Run.set_weapon_art("epee", 0, wimg, "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	a = Arena.new()
	add_child(a)
	await get_tree().process_frame
	var len0 := a.time_left
	a.queue_free()
	await get_tree().process_frame   # (l'ancienne arène remet la vitesse du jeu à 1 en partant)
	_reset()
	Run.set_weapon_art("epee", 0, wimg, "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	for id in ["reflet", "salle_thematique", "speed_painting", "performance"]:
		_give(id)
	Run.recompute()
	a = Arena.new()
	add_child(a)
	await get_tree().process_frame
	_check(a.ghost != null and a.ghost.weapons.size() == 1 and is_equal_approx(float(a.ghost.weapons[0].st.get("ghost", 0.0)), 0.4), "Reflet : un double avec tes armes à 40 %")
	a.player.position = Vector2(100, 200)
	a._process(1.0 / 60.0)
	_check(a.ghost.position.distance_to(Vector2(Arena.W - 100, 200)) < 1.0, "Reflet : en miroir de l'autre côté de la page")
	_check(a.theme in Arena.THEMES, "Salle thématique : règle de la vague = %s" % a.theme)
	_check(is_equal_approx(Engine.time_scale, 1.25), "Speed painting : jeu ×1,25")
	_check(a.time_left < len0 * 0.6, "Performance live : vague 2× plus courte (%.0f → %.0f s)" % [len0, a.time_left])
	a.queue_free()
	Engine.time_scale = 1.0

	# --- Carnet de commandes
	_reset()
	_give("carnet_commandes")
	Run.wave = 3
	Run.new_shop()
	_check(not Run.order.is_empty() and int(Run.order.reward) == 35, "Carnet : une commande (+● %d) : %s" % [int(Run.order.get("reward", 0)), Run.order.get("text", "")])
	Run.order = {"kind": "kills", "n": 3, "progress": 0.0, "reward": 35, "done": false, "text": "Tue 3 ennemis"}
	Run.wave = 4
	a = _arena()
	await get_tree().process_frame
	var g0 := Run.gold
	for k in 3:
		a.kill_enemy(a.spawn_enemy_now("tache", Vector2(300 + k * 20, 100), false))
	_check(Run.order.done and Run.gold >= g0 + 35, "Carnet : commande réussie = +35 or")
	a.queue_free()

	# --- Dé pipé, Vernissage
	_reset()
	Run.wave = 8
	_give("de_pipe")
	var odd := false
	for k in 20:
		Run.roll_shop()
		for o in Run.shop_offers:
			if o.type == "amulet" and o.price != roundi(AmuletDB.PRICE[o.rar] * Run.price_mult()):
				odd = true
	_check(odd, "Dé pipé : des prix tirés au hasard")
	_reset()
	Run.wave = 8
	_give("vernissage")
	var ok_v := true
	for k in 20:
		Run.roll_shop()
		var items := Run.shop_offers.filter(func(o): return o.type in ["weapon", "amulet", "familiar", "case"])
		ok_v = ok_v and items.size() == 2 and items.all(func(o): return int(o.rar) >= 1)
	_check(ok_v, "Vernissage : 2 œuvres, toutes au moins rares")

	# --- Les 12 nouveaux succès
	var C := ItemUnlockDB.CONDS
	_check(ItemUnlockDB.met(C["a:accord_parfait"], {"mono6": true}) and not ItemUnlockDB.met(C["a:accord_parfait"], {}), "succès : 6 armes de la même couleur")
	_check(ItemUnlockDB.met(C["a:bache"], {"boss_clean": true}), "succès : boss sans perdre de PV")
	_check(ItemUnlockDB.met(C["a:colle_forte"], {"counters": {"bosses": 10.0}}) and not ItemUnlockDB.met(C["a:colle_forte"], {"counters": {"bosses": 9.0}}), "succès : 10 boss au total")
	_check(ItemUnlockDB.met(C["a:grattoir"], {"counters": {"damage": 100000.0}}), "succès : 100 000 dégâts")
	_check(ItemUnlockDB.met(C["a:monocle"], {"boss_crit": true}), "succès : boss achevé d'un critique")
	_check(ItemUnlockDB.met(C["a:pigment_pur"], {"colors": 1, "cleared": 10}) and not ItemUnlockDB.met(C["a:pigment_pur"], {"colors": 2, "cleared": 10}), "succès : vague 10 avec une seule couleur")
	_check(ItemUnlockDB.met(C["a:toile_tendue"], {"bosses": {"photocopieuse": true}}), "succès : la Photocopieuse")
	_check(ItemUnlockDB.met(C["a:carnet_commandes"], {"counters": {"gold_spent": 1000.0}}), "succès : 1 000 or dépensés")
	_check(ItemUnlockDB.met(C["a:de_pipe"], {"counters": {"roulette_wins": 3.0}}), "succès : 3 victoires à la roulette")
	_check(ItemUnlockDB.met(C["a:performance"], {"wave_kills": 150}), "succès : 150 ennemis en une vague")
	_check(ItemUnlockDB.met(C["a:reflet"], {"bosses": {"encrier": true}}), "succès : l'Encrier")
	_check(ItemUnlockDB.met(C["a:salle_thematique"], {"maps": 3}) and not ItemUnlockDB.met(C["a:salle_thematique"], {"maps": 2}), "succès : les trois cartes")
	_check(ItemUnlockDB.met(C["a:speed_painting"], {"win": true, "play_time": 24 * 60.0}) and not ItemUnlockDB.met(C["a:speed_painting"], {"win": true, "play_time": 26 * 60.0}), "succès : victoire en moins de 25 min")
	_check(ItemUnlockDB.met(C["a:vernissage"], {"legend_buys": 3}), "succès : 3 légendaires achetées")
	# Compteurs réels : or dépensé
	var spent0 := float((Meta.data.get("counters", {}) as Dictionary).get("gold_spent", 0.0))
	Run.gold = 100
	Run.spend(30)
	_check(is_equal_approx(float(Meta.data.counters.gold_spent), spent0 + 30.0) and Run.gold == 70, "or dépensé compté")
	Run.refund(30)
	_check(is_equal_approx(float(Meta.data.counters.gold_spent), spent0), "achat annulé : plus compté")
	Run.active = false
	print("AMULETTES 0.8 : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)
