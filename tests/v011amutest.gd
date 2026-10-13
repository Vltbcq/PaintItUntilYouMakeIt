extends Node
## Objets de la v0.11 : La Porte, Lampe torche, Pitcoin, Boîte de Pandore, Le Diplôme ;
## et la couleur imposée (= couleur dominante).
## Godot --headless --path . res://tests/v011amutest.tscn

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

	# --- La Porte : +20 % dégâts, un toc-toc programmé dans la vague (et rien dans la description)
	_setup()
	var d0: float = Run.stats.dmg
	_give("porte")
	_check(absf(Run.stats.dmg - d0 - 20.0) < 0.01, "Porte : +20 %% dégâts (%.1f → %.1f)" % [d0, Run.stats.dmg])
	var desc := AmuletDB.describe(AmuletDB.get_def("porte")).to_lower()
	_check(not ("toc" in desc or "frapp" in desc or "son" in desc), "Porte : la description ne dit rien du toc-toc (« %s »)" % desc)
	_check(ResourceLoader.exists("res://assets/sfx/knock_1.ogg"), "Porte : les sons de toc-toc existent")
	var arena := Arena.new()
	add_child(arena)
	await get_tree().process_frame
	_check(arena.knock_t > 0.0 and arena.knock_t < arena.wave_len, "Porte : quelqu'un frappera à %.1f s (vague de %.0f s)" % [arena.knock_t, arena.wave_len])
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame

	# --- Lampe torche : +30 % dégâts, +15 % critique, noir permanent avec un grand cercle de lumière
	_setup()
	var s0: Dictionary = Run.stats.duplicate()
	_give("lampe")
	_check(absf(Run.stats.dmg - s0.dmg - 30.0) < 0.01 and absf(Run.stats.crit - s0.crit - 15.0) < 0.01, "Lampe : +30 % dégâts, +15 % critique")
	arena = Arena.new()
	add_child(arena)
	await get_tree().process_frame
	arena._process(0.1)
	_check(arena.dark_t > 0.0 and arena.dark_r > 44.0, "Lampe : l'arène est dans le noir (lumière de %.0f px)" % arena.dark_r)
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame

	# --- Pitcoin : 1 chance sur 8 de gagner, sinon une perte ; jamais d'or négatif
	_setup()
	_give("pitcoin")
	seed(99)
	var wins := 0
	for n in 800:
		Run.gold = 1000
		if Run.pitcoin_roll() > 0:
			wins += 1
	_check(wins > 60 and wins < 150, "Pitcoin : %d gains sur 800 (≈ 100 attendus)" % wins)
	var lost_ok := true
	for n in 50:
		Run.gold = 3
		Run.pitcoin_roll()
		lost_ok = lost_ok and Run.gold >= 0
	_check(lost_ok, "Pitcoin : l'or ne passe jamais en négatif")

	# --- Boîte de Pandore : chaque amulette monte d'une rareté, garde son dessin et sa place
	_setup()
	_check(not Run.amulet_usable(AmuletDB.get_def("pandore")), "Pandore : pas proposée sans amulette")
	_give("plume", Vector2i(10, 10))
	_give("coeur", Vector2i(20, 12))
	_give("polygunnus", Vector2i(30, 14))
	_check(Run.amulet_usable(AmuletDB.get_def("pandore")), "Pandore : proposée avec des amulettes")
	var before := []
	for am in Run.amulets:
		before.append({"id": am.id, "rar": int(AmuletDB.get_def(am.id).rar), "image": am.image, "pos": am.pos})
	var ch := Run.open_pandora()
	_check(ch.size() == 3, "Pandore : 3 amulettes changées (%s)" % str(ch))
	var all_ok := true
	for k in Run.amulets.size():
		var am: Dictionary = Run.amulets[k]
		var b: Dictionary = before[k]
		var nd := AmuletDB.get_def(am.id)
		var want := mini(int(b.rar) + 1, 3)
		var ok: bool = int(nd.rar) == want and am.id != b.id and am.image == b.image and am.pos == b.pos and not nd.get("consume", false)
		print("     %s (%d) → %s (%d)" % [b.id, b.rar, am.id, nd.rar])
		all_ok = all_ok and ok
	_check(all_ok, "Pandore : rareté +1 (légendaire → une autre légendaire), même dessin, même place")

	# --- Le Diplôme : proposé seulement s'il reste une arme à améliorer
	_setup()
	_check(Run.amulet_usable(AmuletDB.get_def("diplome")), "Diplôme : proposé avec une arme commune")
	for w in Run.weapons:
		w.rar = 3
	_check(not Run.amulet_usable(AmuletDB.get_def("diplome")), "Diplôme : pas proposé si toutes les armes sont légendaires")
	var pool := Run.amulet_candidates(2).map(func(dd): return dd.id)
	_check(not "diplome" in pool, "Diplôme : absent des amulettes proposables")
	# (v0.13) il ne disparaît plus : il se dessine et se garde ; Pandore ne le fabrique jamais (sans achat, pas d'effet)
	var dip := AmuletDB.get_def("diplome")
	_check(dip.get("on_buy", false) and not dip.get("consume", false) and not AmuletDB.describe(dip).contains("disparaît"), "Diplôme : effet à l'achat, mais l'amulette se garde")
	_check(AmuletDB.get_def("pandore").get("consume", false), "Pandore : elle disparaît toujours")
	_setup()
	_give("plume", Vector2i(10, 10))
	var never := true
	for n in 60:
		Run.amulets[0].id = "plume"
		Run.open_pandora()
		never = never and Run.amulets[0].id != "diplome"
		Run.amulets[0].id = "plume"
	_check(never, "Pandore ne transforme jamais une amulette en Diplôme")

	# --- Couleur imposée : il suffit qu'elle soit la couleur dominante (comme l'élément affiché)
	var cfg := {"need_el": 4}
	var img := _stripes([[4, 45], [1, 30], [2, 25]])
	_check(DrawCfg.color_issue(cfg, img) == "", "Couleur imposée : Poison 45 %%, Feu 30 %%, Glace 25 %% → validé (« %s »)" % DrawCfg.color_issue(cfg, img))
	img = _stripes([[1, 50], [4, 40], [2, 10]])
	_check(DrawCfg.color_issue(cfg, img) != "", "Couleur imposée : Feu dominant → refusé")

	# --- Goofy : Rires en boîte, Chapeau de fête, Tête à l'envers, et le Pigeon (familier)
	_setup()
	_give("rires")
	_give("chapeau_fete")
	_give("envers")
	Run.set_familiar_art("pigeon", _blob(20, 120), "")
	Run.add_familiar("pigeon")
	arena = Arena.new()
	add_child(arena)
	await get_tree().process_frame
	_check(is_equal_approx(arena.cam.rotation, PI) and not arena.cam.ignore_rotation, "Tête à l'envers : la caméra est retournée")
	_check(arena.familiars.any(func(f): return f.id == "pigeon"), "Pigeon : c'est un familier")
	_check(AmuletDB.get_def("pigeon").is_empty() and "pigeon" in FamiliarDB.CHIMERA_FORMS, "Pigeon : plus une amulette ; la Chimère peut le prendre")
	arena.laugh_t = 10.0
	_check(absf(arena.laugh_bonus() - 0.2) < 0.001, "Rires : 10 s sans être touché → +20 %% (%.2f)" % arena.laugh_bonus())
	arena.laugh_t = 100.0
	_check(absf(arena.laugh_bonus() - 0.4) < 0.001, "Rires : plafond à +40 %")
	arena.player.inv = 0.0
	Run.stats.dodge = 0.0
	arena.player.st.dodge = 0.0
	arena.player.take_hit(1.0, 0, null)
	_check(arena.laugh_t == 0.0, "Rires : un coup reçu remet à zéro")
	var e0: Enemy = arena.spawn_enemy_now("tache", arena.player.position + Vector2(60, 0), false)
	e0.hp = 9999.0
	if e0:
		arena.party()
		_check(e0.dance_t > 0.0, "Chapeau de fête : les ennemis dansent")
		# les tués pendant la fête ne comptent pas pour la suivante
		Run.party_kills = 0
		arena.kill_enemy(arena.spawn_enemy_now("tache", arena.player.position + Vector2(0, 90), false))
		_check(Run.party_kills == 0, "Chapeau de fête : un ennemi tué pendant la fête ne compte pas")
		arena.party_t = 0.0
		arena.kill_enemy(arena.spawn_enemy_now("tache", arena.player.position + Vector2(0, 90), false))
		_check(Run.party_kills == 1, "Chapeau de fête : après la fête, le compteur repart")
		arena.party_t = Arena.PARTY_SEC
		var late: Enemy = arena.spawn_enemy_now("tache", arena.player.position + Vector2(-90, 0), false)
		_check(late.dance_t > 0.0, "Chapeau de fête : un ennemi arrivé pendant la fête danse aussi")
		var hp0 := e0.hp
		e0.dance_t = 99.0   # (qu'il reste à portée)
		seed(5)
		await get_tree().create_timer(7.0).timeout
		_check(e0.hp < hp0, "Pigeon : ses fientes blessent (%.1f → %.1f PV)" % [hp0, e0.hp])

	# --- Ratios : +15 % par rang de rareté (fusion)
	Run.gold = 120
	var g0 := Stats.scaled_damage(0.0, "gold", 0)
	var g3 := Stats.scaled_damage(0.0, "gold", 3)
	_check(g0 == 10.0 and g3 == 14.0, "Ratio : 120 or = +%d dégâts en commune, +%d en légendaire" % [g0, g3])
	_check(absf(Stats.crit_ratio(35.0, 2) - (2.0 + 1.3)) < 0.001, "Ratio : Cutter épique, 35 %% critique → critiques ×%.2f" % Stats.crit_ratio(35.0, 2))
	arena.ended = true
	arena.queue_free()
	await get_tree().process_frame

	# --- Dessin trop grand pris dans la galerie : toile agrandie, refusé tant qu'il dépasse le cadre
	Run.active = false
	var big := _blob(40, 1000)
	var dcfg := {"kind": "enemy", "gallery": "enemy", "size": Vector2i(24, 24), "ink": 9999, "title": "t", "sub": "",
		"cancel": false, "min": 1, "base": big, "random": false}
	var ds := DrawScreen.new(dcfg)
	add_child(ds)
	await get_tree().process_frame
	_check(ds.img.get_size() == big.get_used_rect().size and ds.cfg.get("fit") == Vector2i(24, 24) and dcfg.size == Vector2i(24, 24),
		"Trop grand : la toile s'agrandit (%s), cadre %s, la config d'origine garde sa taille" % [ds.img.get_size(), ds.cfg.get("fit")])
	var got := []
	ds.done.connect(func(r): got.append(r))
	ds._validate()
	_check(got.is_empty(), "Trop grand : validation refusée tant qu'il dépasse")
	ds.img.fill(Color(0, 0, 0, 0))
	ds.img.blit_rect(_blob(20, 200), Rect2i(0, 0, 20, 20), Vector2i(2, 15))
	ds._recount()
	ds._validate()
	_check(got.size() == 1 and (got[0].image as Image).get_size() == Vector2i(24, 24), "Trop grand : une fois réduit, validé sur une toile 24×24")
	ds.queue_free()
	await get_tree().process_frame

	Run.active = false
	print("V011AMU : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


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


func _give(id: String, pos := Vector2i(30, 30)) -> void:
	if not Run.amulet_art.has(id):
		Run.set_amulet_art(id, _blob(16, 20), "")
	Run.add_amulet(id, Run.amulet_art[id].image, pos)
	Run.recompute()


## 100 pixels en bandes : [[élément, nombre de pixels], ...]
func _stripes(parts: Array) -> Image:
	var img := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	var i := 0
	for p in parts:
		for n in int(p[1]):
			img.set_pixel(i % 10, i / 10, Pal.SHADES[int(p[0])][1])
			i += 1
	return img


func _blob(size: int, px: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, Pal.SHADES[1][1])
	return img
