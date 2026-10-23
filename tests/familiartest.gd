extends Node
## Test : les familiers (boutique, 12 comportements, Woinic, oiseaux de la Cage, Sifflet, Fouet, sauvegarde).
## Godot --path . res://tests/familiartest.tscn [-- <capture.png> <capture_boutique.png>]

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	for d in FamiliarDB.LIST:   # tous les familiers débloqués pour le test
		Meta.data.item_unlocks["f:" + d.id] = true
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var args := OS.get_cmdline_user_args()
	Run.start(0, 1)
	Run.wave = 6
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(6, 6, 12, 12), Pal.SHADES[1][1])
	Run.set_character(img, "")
	Run.set_weapon_art("epee", 0, img, "", null, "")
	Run.add_weapon("epee", 0, 0, Vector2(8, 0))
	for id in EnemyDB.TYPES:
		Run.set_enemy_art(id, img, "")
		if EnemyDB.TYPES[id].get("shoots", false):
			Run.auto_eproj(id)
	Run.recompute()

	# --- Boutique : sans familier, pas d'objets de familiers
	var pet_am := false
	for r in 4:
		for d in Run.amulet_candidates(r):
			pet_am = pet_am or d.get("pet", false)
	_check(not pet_am, "sans familier : aucune amulette de familier proposée")
	_check(not "cage" in WeaponDB.allowed_for(3) and not "sifflet" in WeaponDB.allowed_for(0), "sans familier : aucune arme de familier")
	_check(not "sifflet" in WeaponDB.of_kind("ranged"), "le Sifflet n'est pas une arme de départ")
	var seen := {}
	var dup := false
	for k in 200:
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		var here := {}
		for o in Run.shop_offers:
			if o.type == "familiar":
				seen[o.id] = true
				dup = dup or here.has(o.id)
				here[o.id] = true
				dup = dup or int(FamiliarDB.get_def(o.id).rar) != int(o.rar)
	_check(seen.size() >= 6, "la boutique propose des familiers (%d différents en 200 tirages)" % seen.size())
	_check(not dup, "jamais deux fois le même familier en vitrine, bonne rareté")

	# --- Tous les familiers
	var cols := [Pal.SHADES[0][1], Pal.SHADES[2][1], Pal.SHADES[3][1], Pal.SHADES[4][1]]
	for d in FamiliarDB.LIST:
		var fi := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		fi.fill_rect(Rect2i(3, 3, 10, 10), cols[int(d.rar)])
		Run.set_familiar_art(d.id, fi, "")
		Run.add_familiar(d.id)
	Run.add_familiar("yuki")
	_check(Run.familiars.size() == FamiliarDB.LIST.size(), "%d familiers uniques" % Run.familiars.size())
	_check("cage" in WeaponDB.allowed_for(3), "avec un familier : la Cage peut sortir")
	var fresh := true
	for k in 100:
		Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
		Run.roll_shop()
		for o in Run.shop_offers:
			fresh = fresh and o.type != "familiar"
	_check(fresh, "un familier possédé n'est plus jamais proposé")

	# --- Sauvegarde
	var sv := Run.to_save("wave")
	var keep := Run.familiars.duplicate()
	Run.familiars = []
	Run.familiar_art = {}
	Run.from_save(sv)
	_check(Run.familiars.size() == FamiliarDB.LIST.size() and Run.familiar_art.size() == FamiliarDB.LIST.size(), "sauvegarde : familiers et dessins rechargés")
	_check(Run.familiars == keep, "sauvegarde : même ordre")
	Run.wave = 6
	Run.recompute()

	# --- Arène
	var arena := Arena.new()
	add_child(arena)
	for e in arena.enemies.duplicate():
		arena.kill_enemy(e)
	arena.time_left = 999.0
	await get_tree().process_frame
	_check(arena.familiars.size() == FamiliarDB.LIST.size(), "tous les familiers sur la page")
	var foes := []
	for k in 14:
		foes.append(arena.spawn_enemy_now("tache" if k % 2 == 0 else "colosse", arena.player.position + Vector2.from_angle(k * 0.45) * (60.0 + k * 8.0), false))
	var hp0 := 0.0
	for e in foes:
		hp0 += e.hp
	arena.player.hp = arena.player.max_hp * 0.2
	for f in 60 * 13:
		arena.player.inv = 999.0
		arena._process(1.0 / 60.0)
		if f == 60 * 6 and args.size() > 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[0])
	var dealt := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead or e.hp < e.max_hp:
			dealt += 1
	_check(dealt >= 6, "les familiers frappent (%d ennemis touchés)" % dealt)
	_check(not arena.shrooms.is_empty() or Run.kills > 0, "Teemeo plante des champignons")
	_check(arena.player.hp > arena.player.max_hp * 0.2, "Yuki soigne (%.0f / %.0f PV)" % [arena.player.hp, arena.player.max_hp])

	# Woinic attire les ennemis proches
	var pavel: Familiar = null
	for fm in arena.familiars:
		if fm.id == "pavel":
			pavel = fm
	pavel.ko_t = 0.0
	pavel.visible = true
	_check(arena.target_pos(pavel.position + Vector2(20, 0)) == pavel.position, "Woinic attire les ennemis près de lui")
	_check(arena.target_pos(pavel.position + Vector2(400, 0)) != pavel.position or arena.player.position == pavel.position, "les ennemis loin de Woinic visent toujours toi")

	# Sifflet : la cible est désignée aux familiers
	var t: Enemy = arena.spawn_enemy_now("colosse", arena.player.position + Vector2(120, 40), false)
	t.max_hp = 1000000.0   # qu'il survive aux 12 familiers pendant le test
	t.hp = t.max_hp
	t.dodge = 0.0   # (l'esquive tirée de son dessin ne doit pas faire rater le coup de sifflet)
	var gr0: Familiar = null
	for fm in arena.familiars:
		if fm.id == "grenouille":
			gr0 = fm
	gr0.cd = 5.0
	var d0 := gr0.position.distance_to(t.position)
	arena.whistle_cd = 0.0
	arena.hit_enemy(t, 1.0, {"type": "sifflet", "style": "shot"}, Vector2.RIGHT, 0.0)
	_check(arena.whistle == t, "Sifflet : l'ennemi touché devient la cible")
	var rushing := arena.familiars.filter(func(f): return f.rush_t > 0.0).size()
	var support := arena.familiars.filter(func(f): return f.id in ["yuki", "pavel", "pie"] and f.rush_t > 0.0).size()
	_check(rushing >= 8 and support == 0 and gr0.cd <= 0.0, "Rappel au pied : %d familiers foncent, capacités rechargées (pas Yuki, Woinic, Pie)" % rushing)
	gr0.rush_t = 1.0
	for f in 20:
		arena.player.inv = 999.0
		gr0.tick(1.0 / 60.0)
	_check(gr0.position.distance_to(t.position) < d0, "la Grenouille accourt vers la cible (%.0f → %.0f)" % [d0, gr0.position.distance_to(t.position)])
	for fm in arena.familiars:
		fm.rush_t = 0.0
		if fm.form == "paon" or fm.id == "chimere":
			fm.cd = 999.0       # (le Paon charmerait la cible : elle quitterait les ennemis)
			fm.chim_t = 999.0
			fm.state = "walk"
	arena.hit_enemy(t, 1.0, {"type": "sifflet", "style": "shot"}, Vector2.RIGHT, 0.0)
	_check(arena.familiars.filter(func(f): return f.rush_t > 0.0).is_empty(), "pas de nouveau rappel avant 3 s")
	for f in 120:
		arena.player.inv = 999.0
		arena._process(1.0 / 60.0)
	var lu := false
	for fm in arena.familiars:
		if fm.id == "luciole":
			lu = fm.target == t
	_check(lu and t.firefly, "la Luciole met son aura sur la cible du Sifflet")

	# Fouet : bonus de dégâts qui se cumule
	var fm0: Familiar = arena.familiars[0]
	var before := fm0.fdmg(10.0, 0.0)
	for k in 7:
		arena.hit_enemy(t, 1.0, {"type": "fouet"}, Vector2.RIGHT, 0.0)
	_check(arena.whip_stacks == 5, "Fouet : 5 cumuls max (%d)" % arena.whip_stacks)
	_check(absf(fm0.fdmg(10.0, 0.0) / before - 1.5) < 0.01, "Fouet : +50% de dégâts des familiers")

	# Cage : oiseaux temporaires (5 max)
	var n0 := arena.familiars.size()
	for k in 7:
		arena.add_bird(Gfx.texture(img), "", false, 8.0)
	_check(arena.familiars.size() == n0 + 5, "Cage : 5 oiseaux max (%d)" % (arena.familiars.size() - n0))
	for f in 60 * 7:
		arena.player.inv = 999.0
		arena._process(1.0 / 60.0)
	_check(arena.familiars.size() == n0, "les oiseaux s'envolent au bout de 6 s")
	# Moustique : pique et soigne
	var mq: Familiar = null
	var pie: Familiar = null
	for fm in arena.familiars:
		if fm.id == "moustique":
			mq = fm
		if fm.id == "pie":
			pie = fm
	var prey: Enemy = arena.spawn_enemy_now("colosse", arena.player.position + Vector2(60, 0), false)
	mq.target = prey
	mq.position = prey.position
	mq.cd = 0.0
	arena.player.hp = 3.0
	var php := prey.hp
	mq.tick(1.0 / 60.0)
	_check(prey.hp < php and arena.player.hp >= 4.0, "Moustique : pique (%.0f → %.0f) et rend 1 PV (%.0f)" % [php, prey.hp, arena.player.hp])
	# Pie : va chercher la pièce brillante et te la rapporte
	var g0 := Run.gold
	pie.fetch = [{"pos": arena.player.position + Vector2(90, 30), "v": 2, "test": true}, {"pos": arena.player.position + Vector2(-70, 50), "v": 1, "test": true}, {"pos": arena.player.position + Vector2(40, -60), "v": 1, "test": true}]
	pie.carry = false
	var went := false
	for f in 480:
		arena.player.inv = 999.0
		arena._process(1.0 / 60.0)
		went = went or pie.carry
		if f == 50 and args.size() > 2:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(args[2])
	var mine := pie.fetch.filter(func(f): return f.pos.distance_to(arena.player.position) > 0.0 and f.v >= 1 and f.get("test", false))
	_check(went and mine.is_empty() and Run.gold >= g0 + 4, "Pie : va chercher les pièces et rapporte l'or (+%d)" % (Run.gold - g0))
	var drops := 0
	for k in 300:
		arena.kill_enemy(arena.spawn_enemy_now("tache", arena.player.position + Vector2(200, 0), false))
		drops += pie.fetch.size()
		pie.fetch.clear()
	_check(drops > 10, "Pie : des pièces brillent quand l'or tombe (%d sur 300 éliminations)" % drops)
	# Perroquet : répète ton épée sur l'ennemi le plus proche de lui
	var par: Familiar = null
	for fm in arena.familiars:
		if fm.id == "perroquet":
			par = fm
	for e in arena.enemies.duplicate():
		arena.kill_enemy(e)
	var pv: Enemy = arena.spawn_enemy_now("colosse", par.position + Vector2(40, 0), false)
	pv.dodge = 0.0   # (sinon une esquive fait rater le test)
	var pvh := pv.hp
	par.cd = 0.0
	par.tick(1.0 / 60.0)
	var held := par.copy_spr != null   # il tient ton épée et refait son geste (balayage)
	for f in 40:
		arena.player.inv = 999.0
		arena._process(1.0 / 60.0)
	_check(held and par.copy.is_empty() and pv.hp < pvh, "Perroquet : copie le geste de l'épée (%.0f → %.0f)" % [pvh, pv.hp])
	# Taupe : dégâts de zone en surgissant
	var tp: Familiar = null
	for fm in arena.familiars:
		if fm.id == "taupe":
			tp = fm
	for e in arena.enemies.duplicate():
		arena.kill_enemy(e)
	var c0: Enemy = arena.spawn_enemy_now("colosse", arena.player.position + Vector2(150, 0), false)
	var c1: Enemy = arena.spawn_enemy_now("colosse", c0.position + Vector2(20, 0), false)
	var c2: Enemy = arena.spawn_enemy_now("colosse", c0.position + Vector2(0, -22), false)
	arena.player.inv = 999.0
	arena._process(1.0 / 60.0)   # grille des ennemis à jour
	var h1 := c1.hp
	var h2 := c2.hp
	var h0 := c0.hp
	tp.target = c0
	tp.state = "dig"
	tp.st_t = 0.0
	tp.tick(1.0 / 60.0)
	_check(c0.hp < h0 and c1.hp < h1 and c2.hp < h2 and c0.pin_t > 0.0, "Taupe : dégâts de zone (3 ennemis touchés) et cible étourdie")
	# Grenouille : coup de langue circulaire, touche tout autour
	var gr: Familiar = null
	var lc: Familiar = null
	for fm in arena.familiars:
		if fm.id == "grenouille":
			gr = fm
		if fm.id == "luciole":
			lc = fm
	for e in arena.enemies.duplicate():
		arena.kill_enemy(e)
	var ring := []
	for k in 4:
		ring.append(arena.spawn_enemy_now("colosse", gr.position + Vector2.from_angle(k * TAU / 4.0) * 40.0, false))
	arena.player.inv = 999.0
	arena._process(1.0 / 60.0)
	var rh := ring.map(func(e): return e.hp)
	gr.cd = 0.0
	gr.state = "walk"
	gr.tick(1.0 / 60.0)
	var all_hit := true
	for k in 4:
		all_hit = all_hit and ring[k].hp < rh[k]
	_check(all_hit, "Grenouille : le coup de langue touche les 4 ennemis autour")
	# Luciole : aura +15 % sur tous les ennemis dedans
	lc.position = ring[0].position
	lc.target = ring[0]
	lc.tick(1.0 / 60.0)
	var inside: int = ring.filter(func(e): return e.firefly).size()
	_check(inside >= 1 and lc.lit.size() == inside, "Luciole : aura sur %d ennemi(s)" % inside)
	var e_lit: Enemy = ring[0]
	var e_off: Enemy = ring[2]
	var h_lit: float = e_lit.hp
	var h_off: float = e_off.hp
	e_lit.hurt(50.0, false, Vector2.ZERO)
	e_off.hurt(50.0, false, Vector2.ZERO)
	var ratio: float = (h_lit - e_lit.hp) / maxf(0.01, h_off - e_off.hp)
	_check(e_lit.firefly and not e_off.firefly and absf(ratio - 1.15) < 0.02, "Luciole : +15%% de dégâts dans l'aura (×%.2f)" % ratio)
	# Teemeo : la fléchette s'arrête sur le premier ennemi touché
	var tm: Familiar = null
	for fm in arena.familiars:
		if fm.id == "teemeo":
			tm = fm
	for e in arena.enemies.duplicate():
		arena.kill_enemy(e)
	tm.position = arena.player.position + Vector2(0, 80)
	var d1: Enemy = arena.spawn_enemy_now("colosse", tm.position + Vector2(50, 0), false)
	var d2: Enemy = arena.spawn_enemy_now("colosse", tm.position + Vector2(80, 0), false)
	arena.player.inv = 999.0
	arena._process(1.0 / 60.0)
	var dh1 := d1.hp
	var dh2 := d2.hp
	var all_fams: Array = arena.familiars.duplicate()
	arena.familiars = [tm]   # les autres familiers ne doivent pas toucher le 2e ennemi
	arena.shrooms.clear()    # ni les champignons / nuages déjà posés
	arena.clouds.clear()
	var base := tm.position
	d1.pin_t = 99.0
	d2.pin_t = 99.0
	tm.darts = [{"pos": base, "vel": Vector2(260, 0), "life": 1.2}]
	for f in 40:
		tm.cd = 99.0
		d1.position = base + Vector2(50, 0)
		d2.position = base + Vector2(80, 0)
		arena._process(1.0 / 60.0)
	arena.familiars = all_fams
	_check(d1.poison > 0, "Teemeo : la fléchette empoisonne")
	_check(d1.hp < dh1 and d2.hp == dh2 and tm.darts.is_empty(), "Teemeo : la fléchette touche le 1er ennemi et s'arrête (%.0f→%.0f, 2e : %.0f→%.0f)" % [dh1, d1.hp, dh2, d2.hp])
	# Couleurs = éléments : un familier dessiné tout en couleur Poison empoisonne
	var pimg := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	pimg.fill_rect(Rect2i(2, 2, 12, 12), Pal.main_color(Pal.POISON))
	Run.set_familiar_art("corbeau", pimg, "")
	var pc := Familiar.new()
	arena.world.add_child(pc)
	pc.setup(arena, "corbeau")
	var pe: Enemy = arena.spawn_enemy_now("colosse", arena.player.position + Vector2(0, -90), false)
	for k in 6:
		pc.hit(pe, 1.0)
	_check(pe.poison == 0, "sans Teinture : pas d'effet élémentaire")
	Run.set_amulet_art("teinture", img, "")
	Run.add_amulet("teinture", img, Vector2i(20, 20))
	for k in 6:
		pc.hit(pe, 1.0)
	_check(pe.poison > 0, "avec Teinture : un dessin vert empoisonne (frac poison %.2f)" % float(pc.frac[Pal.POISON]))
	# Taille du dessin : gros = plus de dégâts, plus lent
	var big := FamiliarDB.size_mult(FamiliarDB.get_def("corbeau"), FamiliarDB.ink(FamiliarDB.get_def("corbeau")))
	var small := FamiliarDB.size_mult(FamiliarDB.get_def("corbeau"), 5)
	_check(big.dmg > 1.35 and big.spd < 0.9 and small.dmg < 0.85 and small.spd > 1.15, "taille : gros ×%.2f dégâts / ×%.2f vitesse, petit ×%.2f / ×%.2f" % [big.dmg, big.spd, small.dmg, small.spd])
	_check(FamiliarDB.ink(FamiliarDB.get_def("moustique")) == 55, "Moustique : 55 pixels d'encre")
	# Collier à grelot : 1 PV toutes les 5 actions
	Run.set_amulet_art("collier_grelot", img, "")
	Run.add_amulet("collier_grelot", img, Vector2i(20, 20))
	arena.grelot_n = 0
	arena.player.hp = 3.0
	for k in 4:
		pc._action()
	var hp4 := arena.player.hp
	pc._action()
	_check(hp4 == 3.0 and arena.player.hp == 4.0, "Collier à grelot : rien pendant 4 actions, +1 PV à la 5e")
	pc.queue_free()
	# Meute : un kill de familier réduit de 50 % les délais de tous les familiers
	Run.set_amulet_art("meute", img, "")
	Run.add_amulet("meute", img, Vector2i(20, 20))
	for fm in arena.familiars:
		fm.cd = 4.0
	var weak: Enemy = arena.spawn_enemy_now("tache", arena.player.position + Vector2(-60, 0), false)
	mq.hit(weak, weak.hp + 10.0)
	var halved := true
	for fm in arena.familiars:
		halved = halved and absf(fm.cd - 2.0) < 0.01
	_check(weak.dead and halved, "Meute : un kill de familier divise par 2 le délai de tous")
	arena.queue_free()

	# --- Boutique : capture avec un familier en vitrine
	Run.familiars = ["yuki", "pie", "moustique"]
	Run.set_amulet_art("niche", img, "")
	Run.add_amulet("niche", img, Vector2i(20, 20))
	Run.seed_v = randi()   # (seed : sinon toujours la même boutique)
	Run.roll_shop()
	Run.shop_offers[0] = {"type": "familiar", "id": "teemeo", "rar": 3, "price": 88, "sold": false}
	Run.shop_offers[1] = {"type": "familiar", "id": "perroquet", "rar": 1, "price": 30, "sold": false}
	var shop := ShopScreen.new()
	add_child(shop)
	await get_tree().process_frame
	await get_tree().process_frame
	if args.size() > 1:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args[1])
	shop.queue_free()
	Run.active = false
	print("FAMILIERS : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)
