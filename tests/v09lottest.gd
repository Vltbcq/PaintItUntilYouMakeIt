extends Node
## Lot v0.9 : seeds, mode infini, Le Paon (charme), Chimère, familiers à débloquer, couleur imposée
## des ennemis, pack secondaire après une victoire, Triangle et symétrie haut / bas, historique.
## Godot --headless --path . res://tests/v09lottest.tscn

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	await get_tree().process_frame

	# --- Seeds : code lisible, et mêmes tirages avec la même seed
	Run.start(2, 1, 123456)
	var code := Run.seed_code()
	var p := Run.parse_seed(code)
	_check(p.get("map", 0) == 1 and p.get("diff", -1) == 2 and p.get("seed", -1) == 123456, "seed : %s se relit (carte, difficulté, seed)" % code)
	_check(Run.parse_seed("n'importe quoi").is_empty() and Run.parse_seed("19-ABCDE").is_empty(), "seed : un code mal écrit est refusé")
	_setup(2, 123456)
	var plan_a: Dictionary = Run.boss_plan.duplicate()
	Run.wave = 3
	Run.new_shop()
	var shop_a := _offers()
	var up_a := Run.roll_upgrades().map(func(u): return u.stat)
	_setup(2, 123456)
	Run.wave = 3
	Run.new_shop()
	var shop_b := _offers()
	var up_b := Run.roll_upgrades().map(func(u): return u.stat)
	_check(Run.boss_plan == plan_a and shop_a == shop_b and up_a == up_b, "seed : mêmes boss, même boutique, mêmes choix de niveau")
	_check(Run.seeded, "seed : partie marquée « avec seed »")
	var pig := int(Meta.data.get("pigments", 0))
	var ach: Dictionary = (Meta.data.get("achievements", {}) as Dictionary).duplicate()
	Meta.check_achievements({"cleared": 15, "win": true, "level": 50, "kills": 99999})
	Meta.count("damage", 1e9)
	_check(Meta.data.get("achievements", {}) == ach and int(Meta.data.get("pigments", 0)) == pig and float((Meta.data.get("counters", {}) as Dictionary).get("damage", 0.0)) < 1e9,
		"seed : rien ne se débloque, rien ne compte")
	_setup(0, -1)
	_check(not Run.seeded and Run.seed_v >= 0, "sans seed : la partie a quand même sa seed (à partager)")

	# --- Mode infini
	_setup(0, -1)
	Run.wave = 18
	_check(Run.endless_mult() == 1.0, "infini : pas actif → pas de bonus")
	Run.endless = true
	_check(absf(Run.endless_mult() - pow(1.15, 3)) < 0.001, "infini : +15 %% par vague après la 15e (×%.2f en vague 18)" % Run.endless_mult())
	Run.plan_endless_boss(20)
	_check(Run.boss_plan.has(20) and EnemyDB.get_def(Run.boss_plan[20]).has("boss"), "infini : un boss au hasard en vague 20 (%s)" % Run.boss_plan.get(20, "?"))

	# --- Couleur imposée (Aquarelle et plus)
	_setup(2, -1)
	for e in range(1, Pal.COUNT):
		Meta.data.unlocks[Pal.UNLOCK[e]] = 1   # (les couleurs débloquées, quelle que soit la vraie sauvegarde)
	var el := Run.enemy_color("tache")
	_check(el >= 1 and el < Pal.COUNT, "Aquarelle : une couleur imposée à la Tache (%s)" % (Pal.NAMES[el] if el >= 1 else "?"))
	var cfg := DrawCfg.enemy("tache")
	_check(int(cfg.get("need_el", -1)) == el, "Aquarelle : l'écran de dessin connaît la couleur imposée")
	var good := _blob(24, 120, Pal.SHADES[el][1])
	var bad := _blob(24, 120, Pal.SHADES[1 if el != 1 else 2][1])
	_check(DrawCfg.color_issue(cfg, good) == "" and DrawCfg.color_issue(cfg, bad) != "", "Aquarelle : un dessin de la bonne couleur passe, un autre non")
	_setup(1, -1)
	_check(Run.enemy_color("tache") == -1, "Croquis : pas de couleur imposée")

	# --- Pack secondaire : après une victoire
	var saved := Meta.data.duplicate(true)
	Meta.data.wins = 0
	Meta.data.unlocks["pack_primaires"] = 1
	Meta.data.unlocks.erase("pack_secondaires")
	Meta.data.pigments = 999
	_check(not Meta.buy_open("pack_secondaires") and not Meta.buy("pack_secondaires"), "pack secondaire : pas achetable sans victoire")
	Meta.data.wins = 1
	_check(Meta.buy_open("pack_secondaires") and Meta.buy("pack_secondaires"), "pack secondaire : achetable après une victoire")
	_check(UnlockDB.get_def("tool_triangle").size() > 0 and AchievementDB.get_def("rature").unlock == "tool_triangle", "Sans rature → Triangle")
	_check(UnlockDB.for_pigments(UnlockDB.get_def("tool_mirror_h")), "symétrie haut / bas : à l'établi")
	Meta.data = saved

	# --- Familiers à débloquer
	var locked := ["pie", "pigeon", "perroquet", "fantome", "paon", "pavel", "teemeo", "chimere"]
	var all_cond := true
	for id in locked:
		all_cond = all_cond and ItemUnlockDB.CONDS.has("f:" + id)
	_check(all_cond and FamiliarDB.LIST.size() == 15, "8 familiers sur 15 à débloquer")
	_check(ItemUnlockDB.met(ItemUnlockDB.CONDS["f:chimere"], {"pets": 5}) and not ItemUnlockDB.met(ItemUnlockDB.CONDS["f:chimere"], {"pets": 4}), "Chimère : 5 familiers en même temps")
	_check(ItemUnlockDB.met(ItemUnlockDB.CONDS["f:paon"], {"pets": 3, "cleared": 10}), "Paon : vague 10 avec 3 familiers")

	# --- Le Paon : charme
	_setup(0, -1)
	Run.wave = 6
	Run.set_familiar_art("paon", _blob(24, 60, Pal.SHADES[2][1]), "")
	Run.add_familiar("paon")
	var arena := Arena.new()
	add_child(arena)
	for e in arena.enemies.duplicate():
		arena.kill_enemy(e)
	arena.time_left = 999.0
	arena.player.inv = 999.0
	var paon: Familiar = arena.familiars.filter(func(f): return f.id == "paon")[0]
	paon.position = Vector2(300, 200)
	var e1: Enemy = arena.spawn_enemy_now("tache", Vector2(320, 200), false)
	var e2: Enemy = arena.spawn_enemy_now("tache", Vector2(330, 210), false)
	var boss: Enemy = arena.spawn_enemy_now("rature", Vector2(290, 190), false)
	arena._rebuild_grid()
	paon.cd = 0.0
	paon.tick(0.016)
	_check(e1.charmed and e2.charmed and not boss.charmed and not e1 in arena.enemies, "Paon : les ennemis proches sont charmés (pas le boss)")
	for f in 60 * 4:
		arena._process(1.0 / 60.0)
	_check(not e1.charmed and (e1.dead or e1 in arena.enemies), "Paon : le charme s'arrête au bout de 3 s")
	arena.queue_free()
	await get_tree().process_frame

	# --- Chimère : change de pouvoir toutes les 5 s
	_setup(0, -1)
	Run.wave = 6
	Run.set_familiar_art("chimere", _blob(24, 60, Pal.SHADES[5][1]), "")
	Run.add_familiar("chimere")
	arena = Arena.new()
	add_child(arena)
	arena.time_left = 999.0
	arena.player.inv = 999.0
	var ch: Familiar = arena.familiars.filter(func(f): return f.id == "chimere")[0]
	var forms := {ch.form: true}
	for k in 6:
		ch.chim_t = 0.0
		ch.tick(0.016)
		forms[ch.form] = true
	_check(forms.size() >= 3 and not forms.has("chimere"), "Chimère : prend plusieurs pouvoirs (%s)" % ", ".join(forms.keys()))
	for f in 60 * 3:
		arena._process(1.0 / 60.0)
	_check(true, "Chimère : tourne sans erreur")
	arena.queue_free()
	await get_tree().process_frame

	# --- Historique de partie (statistiques)
	_setup(1, -1)
	Run.wave = 7
	Run.kills = 42
	var h := Run.history_entry(false)
	_check(int(h.wave) == 7 and int(h.kills) == 42 and h.has("weapons") and h.has("killer"), "historique : fiche de partie complète")

	Run.active = false
	print("V09LOT : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _offers() -> Array:
	return Run.shop_offers.map(func(o): return "%s:%s:%d" % [o.type, o.get("wtype", o.get("id", "")), int(o.rar)])


func _setup(diff: int, with_seed: int) -> void:
	Run.start(diff, 1, with_seed)
	Run.set_character(_blob(32, 180, Pal.SHADES[1][1]), "")
	Run.set_weapon_art("epee", 0, _blob(32, 90, Pal.SHADES[1][1]), "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	for id in EnemyDB.TYPES:
		var d: Dictionary = EnemyDB.TYPES[id]
		Run.set_enemy_art(id, _blob(d.canvas, int(d.canvas * d.canvas * 0.3), Pal.SHADES[1][1]), "")
		if d.get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)
	return img
