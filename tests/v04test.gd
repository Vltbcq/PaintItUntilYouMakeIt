extends Node
## Test des nouveautés : version à l'écran titre, icônes arme / amulette en boutique, fusions au choix,
## pot d'encre (retouche du perso + rangement des amulettes), bord dans la galerie, amulettes
## élémentaires limitées à 1, plus de bonus de zone, Retouche à 5 %.
## Godot --path . res://tests/v04test.tscn [-- <dossier de captures>]

var fails := 0
var shots := ""


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
	# Copie de la sauvegarde, avec toutes les couleurs (le test dessine en rouge, quelle que soit la vraie sauvegarde)
	Meta.data = Meta.data.duplicate(true)
	for e in range(1, Pal.COUNT):
		Meta.data.unlocks[Pal.UNLOCK[e]] = 1
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	await get_tree().process_frame

	# --- Version à l'écran titre
	var title := TitleScreen.new()
	title.size = Vector2(640, 360)
	add_child(title)
	await get_tree().process_frame
	var v := String(ProjectSettings.get_setting("application/config/version", ""))
	var lab: Array = title.find_children("*", "Label", true, false).filter(func(l): return l.text == "v" + v)
	_check(v != "" and lab.size() == 1, "version affichée : v%s" % v)
	await _shot("titre_version")
	title.queue_free()

	# --- Partie de test
	Run.start(0, 1)
	Run.wave = 6
	Run.set_character(_blob(32, 180, Pal.SHADES[1][1]), "")
	for t in ["epee", "arc"]:
		Run.set_weapon_art(t, 0, _blob(32, 90, Pal.INK), "", _blob(16, 20, Pal.SHADES[2][1]) if t == "arc" else null, "")
	for k in 2:
		Run.add_weapon("epee", 0, 14, Vector2(-10 + k * 4, 0))
		Run.add_weapon("arc", 0, 14, Vector2(6 + k * 4, 4))
	Run.set_amulet_art("coeur", _blob(16, 30, Pal.SHADES[1][1]), "")
	Run.add_amulet("coeur", Run.amulet_art["coeur"].image, Vector2i(30, 30))
	Run.recompute()

	# --- Plus de bonus de zone
	var base := Stats.player(Run)
	Run.amulets[0].zone = "Tête"
	var st2 := Stats.player(Run)
	_check(st2.crit == base.crit, "zones : plus de bonus selon l'endroit")

	# --- Amulettes élémentaires : 1 max
	var lim := ["allumette", "braise", "givre", "stalactite", "paratonnerre", "dynamo", "fiole", "champignon", "grimoire", "pentacle", "vitrail", "aureole"].all(func(i): return int(AmuletDB.get_def(i).get("limit", 0)) == 1)
	_check(lim, "amulettes élémentaires : 1 max chacune")

	# --- Boutique : icônes + fusions au choix
	Run.gold = 300
	Run.shop_offers = [{"type": "weapon", "wtype": "epee", "rar": 1, "price": 30, "sold": false},
		{"type": "amulet", "id": "sablier", "rar": 0, "price": 10, "sold": false},
		Run.make_case(3, "amulet"),
		{"type": "heal", "id": "encre", "rar": 0, "price": 12, "sold": false}]
	var shop := ShopScreen.new()
	shop.size = Vector2(640, 360)
	add_child(shop)
	await get_tree().process_frame
	var badges: Array = shop.find_children("*", "Panel", true, false).filter(func(p): return p.tooltip_text in ["Arme", "Amulette"])
	_check(badges.size() == 3, "icônes arme / amulette sur les tableaux (%d)" % badges.size())
	var fus: Array = shop.find_children("*", "Button", true, false).filter(func(b): return b.tooltip_text.begins_with("Fusion"))
	_check(fus.size() == 2, "2 fusions possibles → 2 boutons (%d)" % fus.size())
	await _shot("boutique_icones_fusions")
	shop.queue_free()

	# --- Rangement : les amulettes se déplacent
	var ar := ArrangeScreen.new("", 0)
	ar.size = Vector2(640, 360)
	add_child(ar)
	await get_tree().process_frame
	var am_e: Array = ar.entries.filter(func(e): return e.get("kind", "") == "amulet")
	_check(am_e.size() == 1, "rangement : l'amulette est déplaçable")
	if am_e.size() == 1:
		am_e[0].tl += Vector2i(5, 3)
	await _shot("rangement_amulettes")
	var got = []
	ar.done.connect(func(r): got.append(r))
	ar._validate()
	_check(got.size() == 1 and got[0].amulet_moves.size() == 1, "rangement : nouvelle position de l'amulette renvoyée")
	if got.size() == 1:
		Run.apply_amulet_moves(got[0].amulet_moves)
		_check(Run.amulets[0].pos == Vector2i(35, 33), "amulette déplacée (%s)" % [Run.amulets[0].pos])
	ar.queue_free()

	# --- Pot d'encre : retouche du perso (+40 d'encre), payé seulement si on valide, puis rangement
	var main: Node = load("res://scripts/main.gd").new()
	main.set_process(false)
	add_child(main)
	await get_tree().process_frame
	Run.gold = 100
	Run.shop_offers = [{"type": "heal", "id": "encre", "rar": 0, "price": 12, "sold": false}]
	var px0 := int(Run.char_a.pixels)
	var run_ink := func(): await main._ink_pot(0)
	run_ink.call()
	var seen := []
	for f in 30:
		await get_tree().process_frame
		var cur: Node = main.current
		if cur is DrawScreen and not seen.has("dessin"):
			seen.append("dessin")
			var had := Analyzer.ink_cost(Run.character)
			_check(cur.eff_budget() == had + 40, "pot d'encre : pile +40 sur l'encre déjà utilisée (%d → %d)" % [had, cur.eff_budget()])
			cur.img.fill_rect(Rect2i(2, 2, 4, 14), Pal.SHADES[1][1])   # on ajoute un bras (32 de contour)
			cur._recount()
			cur._validate()
		elif cur is ArrangeScreen and not seen.has("rangement"):
			seen.append("rangement")
			cur._validate()
	_check(seen == ["dessin", "rangement"], "pot d'encre : dessin puis rangement (%s)" % [seen])
	_check(Run.gold == 88 and Run.shop_offers[0].sold and Run.char_ink_bonus == 40, "pot d'encre : payé 12, +40 d'encre gardé pour la partie")
	_check(int(Run.char_a.pixels) > px0, "le perso a grandi (%d → %d px)" % [px0, int(Run.char_a.pixels)])
	main.queue_free()

	# --- Retouche : 5 %
	var src := FileAccess.get_file_as_string("res://scripts/game/arena.gd")
	_check(src.contains('weapon_count("retouche") > 0 and not e.is_boss and not e.small and randf() < 0.05'), "Retouche : 5 % de chances")

	# --- Galerie : bord au choix
	if not Meta.gallery("all").is_empty():
		Meta.data = Meta.data.duplicate(true)
		var e: Dictionary = Meta.gallery("all")[0]
		var gal := GalleryScreen.new()
		gal.size = Vector2(640, 360)
		add_child(gal)
		await get_tree().process_frame
		gal._view(e)
		await get_tree().process_frame
		var ob: Array = gal.viewer.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("Bord"))
		var before: bool = e.get("outline", false)
		if ob.size() == 1:
			ob[0].pressed.emit()
		await get_tree().process_frame
		_check(ob.size() == 1 and bool(Meta.gallery("all")[0].get("outline", false)) != before, "galerie : bouton Bord")
		await _shot("galerie_bord")
		gal.queue_free()
	Run.active = false
	print("V04 : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)


func _blob(size: int, px: int, col: Color) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size / 2.0, size / 2.0)
	var r := minf(sqrt(px / PI), size / 2.0)
	for y in size:
		for x in size:
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)
	return img
