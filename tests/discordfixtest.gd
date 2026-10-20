extends Node
## Retours Discord du 20/10 : bonus de niveau constants, Le Capital + Dé pipé, combos du Surligneur.

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _blob(size: int, px: int, el := 1) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var side := int(ceil(sqrt(float(px))))
	@warning_ignore("integer_division")
	img.fill_rect(Rect2i((size - side) / 2, (size - side) / 2, side, side), Pal.SHADES[el][1])
	return img


func _dmg_common(level: int) -> float:
	Run.level = level
	for n in 300:
		Run.pending_levels = n
		for u in Run.roll_upgrades():
			if u.stat == "dmg" and int(u.rar) == 0 and not u.get("pact", false):
				return float(u.v)
	return -1.0


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	Run.start(0, 1)
	# --- Bonus de niveau : ×0,85 partout, plus de baisse après le niveau 10
	var v1 := _dmg_common(2)
	var v30 := _dmg_common(30)
	_check(is_equal_approx(v1, 4.5) and is_equal_approx(v30, 4.5), "bonus de niveau : +%s %% de dégâts au niveau 2, +%s %% au niveau 30 (×0,85, sans baisse)" % [v1, v30])
	Run.pending_levels = 0

	# --- Le Capital + Dé pipé : les prix sont tirés au dé autour du prix moyen
	Run.start(0, 1)
	Run.wave = 5
	Run.set_character(_blob(32, 160), "")
	for id in ["capital", "de_pipe"]:
		Run.set_amulet_art(id, _blob(16, 30), "")
		Run.add_amulet(id, Run.amulet_art[id].image, Vector2i(20, 20))
	Run.recompute()
	seed(3)
	Run.new_shop()
	var prices := {}
	for o in Run.shop_offers:
		if o.type in ["weapon", "amulet"]:
			prices[o.price] = true
	_check(prices.size() >= 2, "Capital + Dé pipé : les prix sont tirés au dé (%d prix différents)" % prices.size())

	# --- Surligneur : 5 s, Polygunnus (trait épais), Élastique (2e passage), Mise en abyme (éclats)
	Run.start(0, 1)
	Run.wave = 3
	Run.set_character(_blob(32, 160), "")
	Run.set_weapon_art("grande_signature", 3, _blob(32, 120, 2), "", WeaponDB.orb(), "")
	Run.add_weapon("grande_signature", 3, 10, Vector2.ZERO)
	for id in ["polygunnus", "elastique", "mise_abyme"]:
		Run.set_amulet_art(id, _blob(16, 30), "")
		Run.add_amulet(id, Run.amulet_art[id].image, Vector2i(20, 20))
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), 4), "")
	Run.recompute()
	var arena := Arena.new()
	add_child(arena)
	await get_tree().process_frame
	arena.player.god = true
	for e in arena.enemies.duplicate():
		e.loot = 0.0
		arena.enemies.erase(e)
		e.queue_free()
	var e := arena.spawn_enemy_now("tache", Vector2(300, 160), false)
	e.max_hp = 1e9
	e.hp = 1e9
	e.speed = 0.0
	var hp0: float = e.hp
	var nb0 := arena.bullets.size()
	arena.signature(160.0, 50.0, Run.weapons[0].st, ImageTexture.create_from_image(WeaponDB.orb()))
	var after1: float = hp0 - e.hp
	_check(after1 > 0.0 and arena.bullets.size() >= nb0 + 2, "Surligneur + Mise en abyme : l'ennemi touché lâche des éclats (%d)" % (arena.bullets.size() - nb0))
	for k in 30:
		await get_tree().process_frame
	_check(hp0 - e.hp > after1 * 1.5, "Surligneur + Élastique : le trait repasse (2 coups)")
	# Polygunnus : un ennemi à 20 px de la ligne est touché (rayon de touche ×2)
	var e2 := arena.spawn_enemy_now("tache", Vector2(450, 160), false)
	e2.max_hp = 1e9
	e2.hp = 1e9
	e2.speed = 0.0
	var line := PackedVector2Array([Vector2(-10, 160 - e2.radius - 22), Vector2(Arena.W + 10, 160 - e2.radius - 22)])
	var h2: float = e2.hp
	arena.signature(0.0, 50.0, Run.weapons[0].st, null, 9, line)
	_check(e2.hp < h2, "Surligneur + Polygunnus : le trait est 2× plus large")
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame
	print("DISCORDFIX : %d échec(s)" % fails)
	Run.active = false
	get_tree().quit()
