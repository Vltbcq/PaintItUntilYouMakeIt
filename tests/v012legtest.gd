extends Node
## Les 19 amulettes légendaires de la v0.12.
## Godot --headless --path . res://tests/v012legtest.tscn

const IDS := ["satellite", "talons_aiguilles", "biscuit_gorille", "chargeur", "ceinture", "canon_verre", "grenade",
	"catalyseur", "matador", "bulldozer", "carte_credit", "investisseur", "ticket_entree", "pellicule", "boisson",
	"punching_ball", "galerie_musee", "constellation"]

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


func _give(id: String) -> void:
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
	arena.player.st = arena.player.st.duplicate()


func _enemy(offset: Vector2, hp := 100000.0) -> Enemy:
	var e := arena.spawn_enemy_now("tache", arena.player.position + offset, false)
	e.max_hp = hp
	e.hp = hp
	e.dodge = 0.0
	e.speed = 0.0
	e.loot = 0.0
	return e


## Une image de jeu sans que le joueur prenne de coups ni que des ennemis arrivent.
func _step() -> void:
	arena.player.god = true
	arena.spawn_acc = -9999.0
	arena.hitstop_t = 0.0
	arena._process(1.0 / 60.0)
	arena.player.god = false


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	await get_tree().process_frame

	# --- Catalogue et traduction
	var n_ok := 0
	for id in IDS:
		var d := AmuletDB.get_def(id)
		if not d.is_empty() and int(d.rar) == 3 and AmuletDB.describe(d).ends_with("UNIQUE") and not AmuletDB.describe(d).contains("{"):
			n_ok += 1
		else:
			print("   catalogue : ", id)
	_check(n_ok == IDS.size(), "les %d amulettes existent, légendaires et uniques (%d)" % [IDS.size(), n_ok])
	Loc.ignore_env = true
	Loc.apply("en")
	var bad := []
	var rx := RegEx.create_from_string("[éèêàâçîôûù]|\\b(tes|ton|les|des|une|vague)\\b")
	for id in IDS:
		var d := AmuletDB.get_def(id)
		if rx.search(AmuletDB.describe(d)) or rx.search(String(d.name)):
			bad.append(id)
	_check(bad.is_empty(), "traduction anglaise : noms et descriptions (%s)" % str(bad))
	Loc.apply("fr")

	# --- Stats : Canon de verre, Pellicule, Investisseur, Musée, Carte de crédit, Biscuit, Constellation
	_setup()
	var s0: Dictionary = Run.stats.duplicate()
	_give("canon_verre")
	Run.bonus = {"armor": 5.0, "dodge": 20.0}
	Run.recompute()
	_check(absf(Run.stats.dmg - s0.dmg - 50.0) < 0.01 and Run.stats.dodge == 0.0 and Run.stats.armor <= 0.0, "Slip : +50 %% dégâts, ni armure ni esquive (armure %.0f, esquive %.0f)" % [Run.stats.armor, Run.stats.dodge])
	_setup()
	s0 = Run.stats.duplicate()
	_give("pellicule")
	_check(absf(Run.stats.dmg - s0.dmg - 30.0) < 0.01 and absf(Run.stats.speed - s0.speed - 15.0) < 0.01, "Pellicule : +30 % dégâts, +15 % vitesse")
	_setup()
	_give("investisseur")
	var d0: float = Run.stats.dmg
	Run.gold = 99999
	Run.spend(350)
	Run.recompute()
	_check(absf(Run.stats.dmg - d0 - 3.0) < 0.01, "Investisseur : 350 or dépensés = +3 %% dégâts (%.1f)" % (Run.stats.dmg - d0))
	Run.spend(20000)
	Run.recompute()
	_check(absf(Run.stats.dmg - d0 - 80.0) < 0.01, "Investisseur : plafonné à +80 %")
	Run.refund(20000)
	Run.recompute()
	_check(absf(Run.stats.dmg - d0 - 3.0) < 0.01, "Investisseur : un achat annulé ne compte plus")
	_setup()
	s0 = Run.stats.duplicate()
	_give("galerie_musee")
	_check(Run.legend_count() == 1 and absf(Run.stats.dmg - s0.dmg - 4.0) < 0.01 and absf(Run.stats.max_hp - s0.max_hp - 2.0) < 0.01, "Musée seul : 1 légendaire = +4 % dégâts, +2 PV max")
	_give("pellicule")
	Run.set_weapon_art("epee", 3, _blob(32, 90), "", null, "")
	Run.add_weapon("epee", 3, 10, Vector2(3, 0))
	Run.recompute()
	_check(Run.legend_count() == 3 and absf(Run.stats.dmg - s0.dmg - 12.0 - 30.0) < 0.01, "Musée : 3 légendaires (amulettes et arme) = +12 % dégâts")
	_setup()
	_give("carte_credit")
	d0 = Run.stats.dmg
	Run.gold = 30
	_check(Run.cash() == 130, "Carte de crédit : 30 or en poche, 130 à dépenser")
	Run.spend(100)
	Run.recompute()
	_check(Run.gold == -70 and absf(Run.stats.dmg - d0 + 20.0) < 0.01, "Carte de crédit : à -70 or, -20 % dégâts")
	Run.gold = 5
	Run.recompute()
	_check(absf(Run.stats.dmg - d0) < 0.01, "Carte de crédit : de retour dans le vert, plus de malus")
	_setup()
	_check(Run.cash() == Run.gold, "sans Carte de crédit : pas de découvert")
	s0 = Run.stats.duplicate()
	_give("biscuit_gorille")
	Run.end_wave()
	Run.end_wave()
	_check(Run.gorilla == 2 and absf(Run.stats.dmg - s0.dmg - 6.0) < 0.01 and absf(Run.stats.max_hp - s0.max_hp - 6.0) < 0.5 and Run.stats.radius > s0.radius * 1.05, "Biscuit pour gorille : 2 vagues = +6 %% dégâts, +6 PV max, plus gros (rayon %.1f → %.1f)" % [s0.radius, Run.stats.radius])
	_setup()
	s0 = Run.stats.duplicate()
	_give("constellation")
	Run.constel = ["dmg", "max_hp"]
	Run.recompute()
	_check(absf(Run.stats.dmg - s0.dmg - 40.0) < 0.01 and absf(Run.stats.max_hp - roundf(s0.max_hp * 0.8)) < 0.6, "Constellation : +40 %% dégâts, PV max ×0,8 (%s)" % Run.constellation_text())
	Run.roll_constellation()
	_check(Run.constel.size() == 2 and Run.constel[0] != Run.constel[1], "Constellation : deux stats différentes tirées")
	await _arena()
	_check(Run.constel.size() == 2, "Constellation : tirée au début de la vague")
	Run.end_wave()
	_check(Run.constel.is_empty(), "Constellation : remise à zéro à la fin de la vague")

	# --- Dégâts : Boisson énergisante, Punching-ball
	_setup()
	_give("boisson")
	_give("punching_ball")
	await _arena()
	var p := arena.player
	var e := _enemy(Vector2(200, 0))
	e.hp = e.max_hp * 0.6
	_check(absf(arena._amulet_dmg_mult(e, {"kind": "melee"}) - 0.5) < 0.001, "Boisson énergisante : dégâts ÷ 2")
	var wn: WeaponNode = p.weapons[0]
	wn.cd = 10.0
	wn.tick(1.0)
	var fast := 10.0 - wn.cd
	_check(absf(fast - 2.0 * wn._atk_mult()) < 0.01, "Boisson énergisante : la recharge va 2× plus vite (%.2f s en 1 s)" % fast)
	p.st.dodge = 0.0
	p.max_hp = 500.0
	p.hp = 500.0
	for k in 5:
		p.inv = 0.0
		p.take_hit(2.0, 0, null)
	_check(p.punch_n == 5 and absf(arena._amulet_dmg_mult(e, {"kind": "melee"}) - 0.5 * 1.1) < 0.001, "Punching-ball : 5 coups reçus = +10 % dégâts")

	# --- Ceinture de sécurité
	_setup()
	_give("ceinture")
	await _arena()
	p = arena.player
	p.st.dodge = 0.0
	p.st.armor = 0.0
	p.max_hp = 100.0
	p.hp = 100.0
	p.take_hit(90.0, 0, null)
	_check(absf(p.hp - 80.0) < 0.01, "Ceinture de sécurité : un coup de 90 n'enlève que 20 PV sur 100 (%.0f)" % p.hp)

	# --- Critiques : Grenade à fragmentation, Chargeur grande capacité, Catalyseur
	_setup()
	Run.add_weapon("epee", 0, 10, Vector2(4, 0))
	_give("grenade")
	_give("chargeur")
	await _arena()
	p = arena.player
	var a := _enemy(Vector2(120, 0))
	var b := _enemy(Vector2(150, 0))
	_step()
	var hb := b.hp
	for wn2 in p.weapons:
		wn2.cd = 5.0
	arena._on_crit(a, 40.0, p.weapons[0].st)
	_check(absf(hb - b.hp - 20.0) < 0.01, "Grenade : le critique rebondit sur le voisin à 50 %% (%.0f)" % (hb - b.hp))
	_check(p.weapons[0].cd == 5.0 and p.weapons[1].cd == 0.0, "Chargeur : l'autre arme attaque aussitôt, pas celle qui vient de frapper")
	p.weapons[1].cd = 5.0
	arena._on_crit(a, 40.0, p.weapons[0].st)
	_check(p.weapons[1].cd == 5.0, "Chargeur : au plus une fois par seconde")
	_setup()
	_give("catalyseur")
	await _arena()
	p = arena.player
	p.st.crit = 100.0
	p.st.crit_mult = 2.0
	a = _enemy(Vector2(120, 0))
	var ha := a.hp
	a.hurt(10.0, false, Vector2.ZERO, Pal.FEU)
	_check(absf(ha - a.hp - 20.0) < 0.01, "Catalyseur : une brûlure peut faire un critique (%.0f au lieu de 10)" % (ha - a.hp))
	ha = a.hp
	a.hurt(10.0, false, Vector2.ZERO, 0)
	_check(absf(ha - a.hp - 10.0) < 0.01, "Catalyseur : un coup sans élément n'est pas concerné")

	# --- Matador
	_setup()
	_give("matador")
	await _arena()
	p = arena.player
	p.st.dodge = 100.0
	p.weapons[0].cd = 5.0
	p.inv = 0.0
	p.take_hit(5.0, 0, null)
	_check(p.weapons[0].cd == 0.0, "Matador : une esquive déclenche l'arme de mêlée")

	# --- Satellite, Talons aiguilles, Bulldozer
	_setup()
	_give("plume")
	_give("satellite")
	_check(not Run.show_amulets(), "Satellite : les amulettes ne sont plus dessinées sur le perso (elles tournent)")
	await _arena()
	p = arena.player
	_step()
	_check(arena.sat_nodes.size() == 2, "Satellite : une amulette en orbite par amulette possédée (%d)" % arena.sat_nodes.size())
	var orbit: Vector2 = (arena.sat_nodes[0] as Sprite2D).position
	_check(orbit.distance_to(p.position) > 20.0, "Satellite : elles tournent à distance du perso (%.0f px)" % orbit.distance_to(p.position))
	var target := _enemy(orbit - p.position)
	var ht := target.hp
	for k in 6:
		target.position = (arena.sat_nodes[0] as Sprite2D).position
		_step()
	_check(target.hp < ht, "Satellite : un ennemi touché par une amulette prend des dégâts (%.0f)" % (ht - target.hp))
	_setup()
	_give("talons_aiguilles")
	await _arena()
	p = arena.player
	var c0 := arena.clouds.size()
	for k in 30:
		_step()
		p.moving = true
		arena._tick_legends(1.0 / 60.0)
	_check(arena.clouds.size() > c0, "Talons aiguilles : le perso en mouvement laisse de l'encre (%d flaques)" % (arena.clouds.size() - c0))
	_setup()
	_give("bulldozer")
	await _arena()
	p = arena.player
	var close := _enemy(Vector2(p.radius + 6.0, 0))
	var hc := close.hp
	_step()
	arena._tick_legends(1.0 / 60.0)
	_check(close.hp <= hc - 3.0 and close.knock.x > 100.0, "Bulldozer : l'ennemi touché est repoussé et prend au moins 3 dégâts (%.0f)" % (hc - close.hp))

	# --- Ticket d'entrée
	_setup()
	_give("ticket_entree")
	await _arena()
	for k in 4:
		_enemy(Vector2(100 + 10 * k, 60))
	var g0 := Run.gold
	Run.stats.harvest = 0.0
	arena._end_wave()
	_check(Run.gold - g0 >= 4, "Ticket d'entrée : 4 ennemis encore en vie = +4 or (%d)" % (Run.gold - g0))

	# --- Pellicule : le voile noir et blanc
	_setup()
	_give("pellicule")
	await _arena()
	_step()
	_check(arena.gray_layer != null and ResourceLoader.exists("res://shaders/gray.gdshader"), "Pellicule : le voile noir et blanc est posé sous le HUD")

	arena.ended = true
	Run.active = false
	print("V012LEG : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
