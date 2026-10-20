class_name Hud
extends CanvasLayer
## Interface pendant une vague : PV, XP, or, chrono, barre du boss, annonces, pause.

var arena: Arena
var draw_layer: Control
var dark_rect: ColorRect    # le noir (shaders/dark.gdshader), sous draw_layer
var crash_t := 0.0          # L'Écran, boss Le Curseur : faux écran d'erreur (secondes restantes)
var crash_dur := 1.0
var crash_pct := false      # ... avec un faux pourcentage de récupération
var crash_view: Control     # ... dessiné sur son propre calque, par-dessus TOUT le HUD
var popups: VirusPopups     # L'Écran, boss Le Virus : ses fenêtres de pub (créées à la demande)
var announce_label: Label
var announce_sub: Label      # ligne sous l'annonce (ex. l'objectif de la commande)
var ann_tw: Tween
var sub_tw: Tween
var pause_menu: Control
var hurt_flash := 0.0
## OUTIL DE DEV (Ctrl+P) : le dossier scripts/dev/ n'est PAS dans le dépôt (.gitignore). Il n'existe
## que sur l'ordinateur du développeur ; sans lui (versions publiées), Ctrl+P ne fait rien.
const DEV_PATH := "res://scripts/dev/dev_panel.gd"
var dev_panel: Control
var _amulet_btn: Button
var order_label: Label      # Carnet de commandes : la commande de la vague et où tu en es


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dark_rect = ColorRect.new()
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_rect.material = ShaderMaterial.new()
	dark_rect.material.shader = preload("res://shaders/dark.gdshader")
	dark_rect.visible = false
	add_child(dark_rect)
	draw_layer = Control.new()
	draw_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw_layer.draw.connect(_draw_hud)
	add_child(draw_layer)
	announce_label = UI.label("", 30, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	announce_label.position = Vector2(0, 130)
	announce_label.size = Vector2(640, 40)
	add_child(announce_label)
	announce_sub = UI.label("", 13, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	announce_sub.position = Vector2(40, 172)
	announce_sub.size = Vector2(560, 36)
	announce_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	announce_sub.add_theme_constant_override("outline_size", 4)
	announce_sub.add_theme_color_override("font_outline_color", Pal.INK)
	announce_sub.modulate.a = 0.0
	add_child(announce_sub)
	# Afficher / cacher les amulettes sur ton perso (réglage gardé d'une partie à l'autre)
	var ab := UI.button("", _toggle_amulets)
	ab.tooltip_text = Loc.t("Afficher ou cacher les amulettes posées sur ton perso")
	UI.put(self, ab, Vector2(8, 54), Vector2(96, 14))
	_amulet_btn = ab
	_refresh_amulet_btn()
	order_label = UI.label("", 10, Pal.ACCENT)
	UI.put(self, order_label, Vector2(8, 78), Vector2(300, 12))   # (un peu sous le bouton « Amulettes »)


func _toggle_amulets() -> void:
	Meta.set_setting("show_amulets", not bool(Meta.setting("show_amulets")))
	_refresh_amulet_btn()
	if arena and arena.player:
		arena.player.refresh_image()


func _refresh_amulet_btn() -> void:
	_amulet_btn.text = Loc.t("Amulettes : ") + (Loc.t("en orbite") if Run.amulet_count("satellite") > 0 else (Loc.t("oui") if bool(Meta.setting("show_amulets")) else Loc.t("non")))
	_amulet_btn.disabled = Run.amulet_count("satellite") > 0   # (Satellite : elles tournent autour du perso)


func _process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta * 3.0)
	if desk:
		desk_t -= delta
		desk.queue_redraw()
		if desk_t <= 0.0:
			restore()
	if crash_view and crash_view.visible:
		crash_t -= delta   # (le monde est figé pendant ce temps : Arena.hitstop)
		crash_view.visible = crash_t > 0.0
		crash_view.queue_redraw()
	var o: Dictionary = Run.order
	if o.is_empty():
		order_label.text = ""
	elif o.done:
		order_label.text = Loc.t("Commande réussie ✓")
	elif o.kind == "hp":
		order_label.text = Loc.t("Commande : %s") % o.text
	else:
		order_label.text = Loc.t("Commande : %s (%d/%d)") % [o.text, int(o.progress), int(o.n)]
	draw_layer.queue_redraw()


func announce(text: String, color: Color, sub := "") -> void:
	# Une nouvelle annonce remplace la précédente (sinon l'ancien fondu l'efface aussitôt)
	if ann_tw:
		ann_tw.kill()
	if sub_tw:
		sub_tw.kill()
	announce_sub.text = sub
	announce_sub.modulate.a = 1.0 if sub != "" else 0.0
	if sub != "":
		sub_tw = announce_sub.create_tween()
		sub_tw.tween_interval(3.0)   # le détail reste plus longtemps, le temps de le lire
		sub_tw.tween_property(announce_sub, "modulate:a", 0.0, 0.6)
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	announce_label.modulate.a = 1.0
	announce_label.pivot_offset = announce_label.size / 2.0
	announce_label.scale = Vector2(1.8, 1.8)
	ann_tw = announce_label.create_tween()
	ann_tw.tween_property(announce_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ann_tw.tween_interval(2.75 if sub != "" else 1.2)
	ann_tw.tween_property(announce_label, "modulate:a", 0.0, 0.5)


func _bar(pos: Vector2, size: Vector2, t: float, col: Color, text := "") -> void:
	var d := draw_layer
	d.draw_rect(Rect2(pos - Vector2(1, 1), size + Vector2(2, 2)), Pal.INK)
	d.draw_rect(Rect2(pos, size), Pal.PANEL)
	d.draw_rect(Rect2(pos, Vector2(size.x * clampf(t, 0.0, 1.0), size.y)), col)
	d.draw_rect(Rect2(pos, Vector2(size.x * clampf(t, 0.0, 1.0), 1)), col.lightened(0.35))
	if text != "":
		_text(pos + Vector2(0, size.y - 1), text, Pal.TEXT, 10, size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _text(pos: Vector2, text: String, col: Color, fs := 10, w := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_layer.draw_string(UI.font, pos + Vector2(1, 1), text, align, w, UI.fs(fs), Pal.INK)
	draw_layer.draw_string(UI.font, pos, text, align, w, UI.fs(fs), col)


func _draw_hud() -> void:
	# Horloge : le temps est arrêté
	if arena.stop_t > 0.0:
		draw_layer.draw_rect(Rect2(0, 0, 640, 360), Color(0.6, 0.75, 1.0, 0.13))
		_text(Vector2(0, 322), Loc.t("TEMPS ARRÊTÉ  %.1f") % arena.stop_t, Color(0.8, 0.9, 1.0), 10, 640, HORIZONTAL_ALIGNMENT_CENTER)
	# Interro du Professeur : la question, en grand, toujours visible
	for qz in arena.quizzes:
		var k: float = clampf(1.0 - qz.t / qz.dur, 0.0, 1.0)
		draw_layer.draw_rect(Rect2(200, 44, 240, 44), Color(Pal.BG, 0.9))
		draw_layer.draw_rect(Rect2(200, 44, 240, 44), Pal.ACCENT, false, 2.0)
		_text(Vector2(200, 70), String(qz.question), Pal.TEXT, 20, 240, HORIZONTAL_ALIGNMENT_CENTER)
		draw_layer.draw_rect(Rect2(206, 80, 228 * k, 4), Pal.ACCENT if k > 0.35 else Pal.BAD)
		# Les colonnes du tableau, de gauche à droite (toutes visibles, même zoomé) ; la tienne est encadrée
		var n: int = qz.cols
		var cw := 240.0 / n
		var mine := clampi(int(arena.player.position.x / (float(Arena.W) / n)), 0, n - 1)
		for i in n:
			var r := Rect2(200 + i * cw + 2, 90, cw - 4, 18)
			draw_layer.draw_rect(r, Color(Pal.BG, 0.9))
			draw_layer.draw_rect(r, Pal.ACCENT if i == mine else Pal.BORDER, false, 2.0 if i == mine else 1.0)
			_text(Vector2(r.position.x, 104), str(qz.answers[i]), Pal.TEXT, 10, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(Vector2(160, 122), Loc.t("Va dans la colonne de la bonne réponse !"), Pal.ACCENT, 10, 320, HORIZONTAL_ALIGNMENT_CENTER)
	# Nuit d'encre (Encrier renversé) : noir partout sauf autour du joueur (et de la Luciole)
	dark_rect.visible = false
	if arena.dark_t > 0.0:
		var a := clampf(arena.dark_t, 0.0, 1.0) * clampf((6.0 - arena.dark_t) * 2.0, 0.0, 1.0)
		var sp: Vector2 = arena.get_viewport().get_canvas_transform() * arena.player.global_position
		var r: float = arena.dark_r * arena.cam.zoom.x
		var xf := arena.get_viewport().get_canvas_transform()
		var z: float = arena.cam.zoom.x
		# Le noir lui-même : un rectangle à shader (dark_rect), sous ce calque, troué par les lumières
		var lights := PackedVector3Array([Vector3(sp.x, sp.y, r)])
		for fm in arena.familiars:
			# La Luciole (ou la Chimère qui en a pris la forme) éclaire autour d'elle
			if is_instance_valid(fm) and fm.form == "luciole" and lights.size() < 8:
				var lp: Vector2 = xf * fm.global_position
				lights.append(Vector3(lp.x, lp.y, Familiar.LUCIOLE_R * z))
		dark_rect.visible = true
		dark_rect.material.set_shader_parameter("ink", Color(0.05, 0.04, 0.08, 0.95 * a))
		dark_rect.material.set_shader_parameter("count", lights.size())
		dark_rect.material.set_shader_parameter("lights", lights)
		# Les éclats de LUMIÈRE de l'Encrier brillent dans le noir
		for b in arena.bullets:
			if is_instance_valid(b) and b.light:
				var bp: Vector2 = xf * b.global_position
				draw_layer.draw_circle(bp, 6.0 * z, Color(1.0, 0.92, 0.6, 0.3 * a))
				draw_layer.draw_circle(bp, 2.5 * z, Color(1, 1, 1, 0.95 * a))
	# Voile rouge sur les bords quand on prend un coup
	if hurt_flash > 0.0:
		var c := Color(Pal.BAD, 0.45 * hurt_flash)
		for i in 6:
			var inset := float(i) * 4.0
			var ci := Color(c, c.a * (1.0 - i / 6.0))
			draw_layer.draw_rect(Rect2(inset, inset, 640 - inset * 2.0, 360 - inset * 2.0), ci, false, 4.0)
	if arena == null or arena.player == null:
		return
	var p := arena.player
	_draw_party()
	_draw_arrows()
	var cb = arena.boss
	if cb and is_instance_valid(cb) and cb.state == "loading":
		# Le Curseur fait ramer le jeu : une barre de chargement (et des points de suspension qui tournent)
		var ak := clampf(1.0 - cb.st_t / Enemy.LOADING_SEC, 0.0, 1.0)
		draw_layer.draw_rect(Rect2(200, 62, 240, 30), Color(0.05, 0.05, 0.1, 0.9))
		draw_layer.draw_rect(Rect2(200, 62, 240, 30), Pal.BAD, false, 2.0)
		draw_layer.draw_string(UI.font, Vector2(200, 75), Loc.t("CHARGEMENT") + ".".repeat(1 + int(arena.elapsed * 4.0) % 3), HORIZONTAL_ALIGNMENT_CENTER, 240, UI.fs(10), Color.WHITE)
		draw_layer.draw_rect(Rect2(208, 80, 224, 6), Color(1, 1, 1, 0.25))
		draw_layer.draw_rect(Rect2(208, 80, 224 * ak, 6), Color("3a86ff"))
	if not arena.formula.is_empty():
		# Le Tableur : la barre de formule, en haut
		draw_layer.draw_rect(Rect2(210, 44, 220, 14), Color(0.95, 0.95, 0.9))
		draw_layer.draw_rect(Rect2(210, 44, 220, 14), Pal.INK, false, 1.0)
		draw_layer.draw_string(UI.font, Vector2(214, 55), Loc.t("fx   ") + String(arena.formula.text), HORIZONTAL_ALIGNMENT_LEFT, 212, UI.fs(10), Pal.INK)
	var hp_txt := "♥ %d / %d" % [ceili(maxf(0.0, p.hp)), int(p.max_hp)]
	if p.erase_mult < 1.0:
		hp_txt += Loc.t(" (gommé)")
	var hp_k: float = p.hp / p.max_hp
	if arena.bugs and arena.bugs.is_on("fakehp"):
		# L'Écran, boss Le Bug : la barre de vie affiche n'importe quoi (ça change 6 fois par seconde)
		var hk := int(arena.elapsed * 6.0)
		hp_txt = "♥ %d / %d" % [hash(hk) % 999, hash(hk + 7) % 999]
		hp_k = float(hash(hk + 3) % 100) / 100.0
	_bar(Vector2(8, 8), Vector2(140, 12), hp_k, Color("d8433b"), hp_txt)
	_bar(Vector2(8, 24), Vector2(140, 4), float(Run.xp) / Run.xp_needed(), Pal.GOOD)
	_text(Vector2(152, 30), Loc.t("NIV %d") % Run.level, Pal.GOOD)
	_text(Vector2(8, 42), "● %d" % Run.gold, Pal.ACCENT)

	_text(Vector2(0, 22), Loc.t("VAGUE %d") % Run.wave, Pal.TEXT, 20, 640, HORIZONTAL_ALIGNMENT_CENTER)
	if arena.boss_id == "":
		var tl := maxf(0.0, arena.time_left)
		var col := Pal.BAD if tl < 5.0 else Pal.TEXT
		_text(Vector2(0, 36), "%d" % ceili(tl), col, 10, 640, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(0, 12), Meta.DIFFICULTIES[Run.difficulty].name, Pal.DIM, 10, 632, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(0, 24), Pad.txt(Loc.t("Échap : pause")), Pal.DIM, 10, 632, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(0, 36), Pad.txt(Loc.t("Molette / + - : zoom")), Pal.DIM, 10, 632, HORIZONTAL_ALIGNMENT_RIGHT)

	var b := arena.boss
	if b and is_instance_valid(b) and not b.dead:
		_text(Vector2(0, 334), b.def.name, Pal.BAD, 10, 640, HORIZONTAL_ALIGNMENT_CENTER)
		_bar(Vector2(170, 340), Vector2(300, 8), b.hp / b.max_hp, Pal.BAD)


## Chapeau de fête : pendant la fête, la salle s'assombrit, des spots colorés balayent la page,
## une boule à facettes descend et il pleut des confettis (tout en repère écran 640×360).
const PARTY_COLS := [Color("e84a4a"), Color("3a86ff"), Color("f0c43a"), Color("4caf50"), Color("c071f0"), Color("ff8ad0")]


func _draw_party() -> void:
	if arena.party_t <= 0.0:
		return
	var t: float = Arena.PARTY_SEC - arena.party_t
	var a := clampf(t / 0.3, 0.0, 1.0) * clampf(arena.party_t / 0.5, 0.0, 1.0)   # entrée / sortie en fondu
	var beat := pow(1.0 - fmod(t * Arena.PARTY_BEAT, 1.0), 2.0)
	draw_layer.draw_rect(Rect2(0, 0, 640, 360), Color(0.06, 0.03, 0.12, 0.32 * a))
	# Spots : de gros ronds de lumière qui balayent la page
	for k in 6:
		var c: Color = PARTY_COLS[k]
		var p := Vector2(320.0 + sin(t * (0.9 + 0.23 * k) + k * 1.7) * 280.0, 190.0 + cos(t * (1.3 + 0.17 * k) + k * 2.3) * 130.0)
		for r in 3:
			draw_layer.draw_circle(p, 62.0 - r * 16.0, Color(c, (0.08 + 0.05 * beat) * a))
	# Boule à facettes : elle descend, tourne, et renvoie de petits reflets
	var by := lerpf(-20.0, 34.0, clampf(t / 0.5, 0.0, 1.0)) - 60.0 * (1.0 - clampf(arena.party_t / 0.4, 0.0, 1.0))
	var bc := Vector2(430.0, by)   # (à droite du titre : le compte à rebours de la vague reste lisible)
	draw_layer.draw_line(Vector2(bc.x, 0), bc, Color(0.75, 0.75, 0.8, a), 1.0)
	draw_layer.draw_circle(bc, 15.0, Color(0.12, 0.1, 0.18, a))
	draw_layer.draw_circle(bc, 14.0, Color(0.55, 0.58, 0.68, a))
	for fy in range(-2, 3):
		for fx in range(-3, 4):
			var q := Vector2(fx * 4.4 + fmod(t * 9.0, 4.4) - 2.2, fy * 5.0)
			if q.length() > 12.0:
				continue
			var lit := (fx + fy + int(t * 6.0)) % 3 == 0
			draw_layer.draw_rect(Rect2(bc + q - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 1, 1, (0.95 if lit else 0.3) * a))
	for k in 14:
		var ang := t * 1.6 + k * TAU / 14.0
		var rp := Vector2(320.0, by) + Vector2(cos(ang) * (90.0 + 26.0 * (k % 5)) * 1.7, absf(sin(ang)) * (70.0 + 22.0 * (k % 4)) + 20.0)
		draw_layer.draw_rect(Rect2(rp - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 0.9, (0.35 + 0.4 * beat) * a))
	# Pluie de confettis (chacun a sa colonne, sa vitesse et sa couleur ; ils tournent en tombant)
	for k in 90:
		var sx := fmod(k * 73.13, 640.0)
		var spd := 70.0 + fmod(k * 37.7, 80.0)
		var y := fmod(t * spd + fmod(k * 51.9, 400.0), 400.0) - 20.0
		var x := sx + sin(t * 3.0 + k) * 8.0
		var w := 1.0 + 2.5 * absf(sin(t * 6.0 + k * 0.9))   # il tourne : sa largeur change
		draw_layer.draw_rect(Rect2(x - w / 2.0, y, w, 4.0), Color(PARTY_COLS[k % PARTY_COLS.size()], 0.9 * a))


## Flèches au bord de l'écran vers les ennemis hors champ.
## Boss : toujours (grosse flèche rouge). Tireurs : orange. Les autres : seulement s'ils sont proches.
func _draw_arrows() -> void:
	var cam := arena.cam
	var z := cam.zoom.x
	var center := cam.get_screen_center_position()
	var half := Vector2(320.0, 180.0) / z
	var view := Rect2(center - half, half * 2.0)
	var shown := 0
	var list := arena.enemies.duplicate()
	list.sort_custom(func(a, b): return a.position.distance_squared_to(center) < b.position.distance_squared_to(center))
	for e: Enemy in list:
		if e.dead or view.grow(-4.0).has_point(e.position):
			continue
		var col := Pal.DIM
		var size := 4.0
		var shooter: bool = EnemyDB.TYPES[e.id].get("shoots", false)
		if e.is_boss:
			col = Pal.BAD
			size = 8.0
		elif e.elite:
			col = Pal.ACCENT
			size = 6.0
		elif shooter:
			col = Color("f0a030")
			size = 5.0
		elif e.position.distance_to(arena.player.position) > 240.0:
			continue
		var dir := (e.position - center).normalized()
		if not cam.ignore_rotation:
			dir = dir.rotated(-cam.rotation)   # Tête à l'envers : l'écran est retourné
		# Point sur le bord de l'écran (repère de l'écran 640x360)
		var sc := Vector2(320, 180)
		var k := minf((320.0 - 14.0) / maxf(absf(dir.x), 0.001), (180.0 - 14.0) / maxf(absf(dir.y), 0.001))
		var tip := sc + dir * k
		var back := tip - dir * size * 2.0
		var side := dir.orthogonal() * size
		var pts := PackedVector2Array([tip, back + side, back - side])
		draw_layer.draw_colored_polygon(pts, Color(Pal.INK, 0.8))
		var inner := PackedVector2Array([tip - dir * 2.0, back + side * 0.6 + dir, back - side * 0.6 + dir])
		draw_layer.draw_colored_polygon(inner, col)
		shown += 1
		if shown >= 16:
			break


func _unhandled_input(ev: InputEvent) -> void:
	if desk and ev is InputEventJoypadButton and ev.pressed:
		restore()   # fenêtre réduite : à la manette, n'importe quel bouton la rouvre
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_P and ev.ctrl_pressed and ResourceLoader.exists(DEV_PATH):
		toggle_dev()
		get_viewport().set_input_as_handled()
		return
	if dev_panel:
		return   # l'outil de dev gère ses propres touches
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_ESCAPE or ev.keycode == KEY_P):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_START:
		toggle_pause()


## Le Curseur : les écrans qu'il fait passer par-dessus le jeu (sur un calque au-dessus de tout le HUD).
## crash : faux écran d'erreur (with_pct : avec un faux pourcentage) ; "win" : fausse victoire ;
## "closed" : « le jeu a été fermé » (Alt+F4 réussi). Le monde est figé pendant ce temps.
var crash_kind := "crash"


func crash(dur: float, with_pct: bool) -> void:
	screen("crash", dur)
	crash_pct = with_pct


func screen(kind: String, dur: float) -> void:
	crash_kind = kind
	crash_t = dur
	crash_dur = dur
	crash_pct = false
	if crash_view == null:
		crash_view = Control.new()
		crash_view.set_anchors_preset(Control.PRESET_FULL_RECT)
		crash_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crash_view.draw.connect(_draw_crash)
		add_child(crash_view)
	move_child(crash_view, -1)
	crash_view.visible = true


func _draw_crash() -> void:
	if crash_t <= 0.0:
		return
	var k := clampf(1.0 - crash_t / crash_dur, 0.0, 1.0)
	match crash_kind:
		"win":
			# fausse victoire : comme la vraie... puis le doute
			crash_view.draw_rect(Rect2(0, 0, 640, 360), Color(Pal.BG, 0.96))
			crash_view.draw_string(UI.font, Vector2(0, 150), Loc.t("VICTOIRE !"), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(40), Pal.ACCENT)
			if k > 0.3:
				crash_view.draw_string(UI.font, Vector2(0, 186), Loc.t("Le Curseur est vaincu."), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(10), Pal.TEXT)
			if k > 0.72:
				crash_view.draw_string(UI.font, Vector2(0, 226), Loc.t("... ou pas."), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(20), Pal.BAD)
		"closed":
			crash_view.draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.02, 0.04))
			crash_view.draw_string(UI.font, Vector2(0, 176), Loc.t("PaintIt.exe a été fermé."), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(16), Color(1, 1, 1, 0.9))
		_:
			crash_view.draw_rect(Rect2(0, 0, 640, 360), Color("1d3fae"))
			crash_view.draw_string(UI.font, Vector2(60, 110), ":(", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(40), Color.WHITE)
			crash_view.draw_string(UI.font, Vector2(60, 160), Loc.t("Une erreur est survenue dans PaintIt.exe"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(16), Color.WHITE)
			crash_view.draw_string(UI.font, Vector2(60, 190), Loc.t("ERREUR_CURSEUR_HORS_DE_CONTRÔLE"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Color(1, 1, 1, 0.8))
			if crash_pct:
				crash_view.draw_string(UI.font, Vector2(60, 230), Loc.t("Récupération du dessin : %d %%") % int(k * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Color.WHITE)
				crash_view.draw_rect(Rect2(60, 240, 300, 8), Color(1, 1, 1, 0.3))
				crash_view.draw_rect(Rect2(60, 240, 300 * k, 8), Color.WHITE)
			else:
				crash_view.draw_string(UI.font, Vector2(60, 230), Loc.t("Redémarrage..."), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Color.WHITE)


## Le Curseur RÉDUIT la fenêtre du jeu : un faux bureau cache tout, le jeu continue derrière.
## On rouvre en cliquant « PaintIt » dans la barre des tâches (ou n'importe quel bouton de la manette) ;
## sinon la fenêtre revient toute seule après `max_dur` secondes.
var desk: Control
var desk_t := 0.0


func minimize(max_dur: float) -> void:
	if desk:
		return
	desk_t = max_dur
	desk = Control.new()
	desk.set_anchors_preset(Control.PRESET_FULL_RECT)
	desk.mouse_filter = Control.MOUSE_FILTER_STOP
	desk.draw.connect(_draw_desk.bind(desk))
	add_child(desk)
	var b := UI.button(Loc.t("PaintIt"), restore, 10)
	UI.put(desk, b, Vector2(40, 340), Vector2(90, 18))
	desk.set_meta("btn", b)


func restore() -> void:
	if desk:
		desk.queue_free()
		desk = null
		Sfx.play("click")


func _draw_desk(d: Control) -> void:
	d.draw_rect(Rect2(0, 0, 640, 360), Color("2f6f73"))
	# quelques icônes de bureau
	for k in 5:
		var ip := Vector2(24, 20 + k * 52)
		d.draw_rect(Rect2(ip, Vector2(22, 26)), Color("ece6d2"))
		d.draw_rect(Rect2(ip, Vector2(22, 26)), Pal.INK, false, 1.0)
		d.draw_rect(Rect2(ip + Vector2(4, 6), Vector2(14, 2)), Color("8a93a8"))
		d.draw_rect(Rect2(ip + Vector2(4, 11), Vector2(14, 2)), Color("8a93a8"))
		d.draw_string(UI.font, ip + Vector2(-29, 38), [Loc.t("Dessin1"), Loc.t("Dessin2"), Loc.t("Brouillon"), Loc.t("Corbeille"), Loc.t("Notes")][k], HORIZONTAL_ALIGNMENT_CENTER, 80, UI.fs(10), Color.WHITE)
	# barre des tâches
	d.draw_rect(Rect2(0, 336, 640, 24), Color("23262e"))
	d.draw_rect(Rect2(6, 340, 26, 16), Color("46548c"))
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0)
	d.draw_rect(Rect2(38, 338, 94, 22), Color(Pal.ACCENT, blink), false, 2.0)
	d.draw_string(UI.font, Vector2(0, 150), Loc.t("Le Curseur a réduit la fenêtre !"), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(16), Color.WHITE)
	d.draw_string(UI.font, Vector2(0, 176), Pad.txt(Loc.t("Clique « PaintIt » dans la barre des tâches (manette : un bouton)")), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(10), Color(1, 1, 1, 0.85))
	d.draw_string(UI.font, Vector2(0, 196), Loc.t("Ton perso se bat toujours derrière..."), HORIZONTAL_ALIGNMENT_CENTER, 640, UI.fs(10), Color(1, 1, 1, 0.6))


## Le Virus : le calque de ses fenêtres (par-dessus tout le HUD), créé la première fois qu'il en ouvre une.
func ensure_popups() -> VirusPopups:
	if popups == null:
		popups = VirusPopups.new()
		popups.arena = arena
		add_child(popups)
	return popups


## OUTIL DE DEV : ouvre / ferme le panneau (le jeu est en pause pendant qu'il est ouvert).
func toggle_dev() -> void:
	if dev_panel:
		dev_panel.queue_free()
		dev_panel = null
		get_tree().paused = pause_menu != null
		return
	if arena.ended or pause_menu:
		return
	if not ResourceLoader.exists(DEV_PATH):
		return
	get_tree().paused = true
	dev_panel = (load(DEV_PATH) as GDScript).new()
	dev_panel.set("arena", arena)
	add_child(dev_panel)


func toggle_pause() -> void:
	if pause_menu == null and get_tree().paused:
		return   # un conseil est affiché (le jeu est déjà en pause)
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null
		get_tree().paused = false
		return
	if arena.ended:
		return
	get_tree().paused = true
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pause_menu)
	_build_pause()


## Menu pause « cadre de musée » : ton perso encadré au centre, ses stats à gauche, ton
## équipement à droite, faiblesses et synergies sous le cadre, boutons et seed en bas.
func _build_pause() -> void:
	var pm := pause_menu
	UI.fill_bg(pm, Color(Pal.BG, 0.85))   # on devine la partie derrière
	UI.put(pm, UI.label(Loc.t("PAUSE"), 30, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(640, 36))
	var wave_txt := (Loc.t("Vague %d · infini") % Run.wave) if Run.endless else (Loc.t("Vague %d / %d") % [Run.wave, Run.WAVES])
	var info := Loc.t("%s   ·   ♥ %d / %d   ·   ● %d   ·   Niveau %d") % [wave_txt, ceili(arena.player.hp), int(arena.player.max_hp), Run.gold, Run.level]
	UI.put(pm, UI.label(info, 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 42), Vector2(640, 12))

	# --- Gauche : les stats (icônes, le nom au survol)
	var left := UI.panel()
	UI.put(pm, left, Vector2(14, 62), Vector2(196, 150))
	UI.put(left, UI.label(Loc.t("STATS"), 10, Pal.ACCENT), Vector2(8, 4))
	# Beaucoup de résistances : la liste défile (barre à droite, molette)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.put(left, sc, Vector2(6, 18), Vector2(186, 128))
	var stats := StatText.new(2)
	stats.size = Vector2(174, 10)
	stats.custom_minimum_size.x = 174
	sc.add_child(stats)
	stats.set_text(Stats.describe_player(Run.stats))

	# --- Centre : le perso dans un cadre doré
	var frame := UI.panel(Color("b07d1c"), Pal.ACCENT, 3)
	UI.put(pm, frame, Vector2(250, 62), Vector2(140, 124))
	var inner := UI.panel(Pal.PAPER, Color("8c6a1a"), 1)
	UI.put(frame, inner, Vector2(8, 8), Vector2(124, 108))
	if Run.character:
		UI.put(inner, UI.thumb(Run.build_player_image(), Vector2(116, 100)), Vector2(4, 4), Vector2(116, 100))
	# faiblesses (en petit) et synergies sous le cadre
	if UI.has_elements():
		UI.cercle(pm, Vector2(228, 194), true)
	var syn_box := VBoxContainer.new()
	syn_box.add_theme_constant_override("separation", 3)
	UI.put(pm, syn_box, Vector2(318, 196), Vector2(100, 100))
	syn_box.add_child(UI.label(Loc.t("SYNERGIES"), 10, Pal.DIM))
	var counts := Run.synergy_counts()
	if counts.is_empty():
		syn_box.add_child(UI.label(Loc.t("aucune"), 10, Pal.DIM))
	for e in counts:
		var on: bool = counts[e] >= Run.synergy_need()
		var chip := UI.panel(Color(Pal.main_color(e), 0.9 if on else 0.35), Pal.ACCENT if on else Pal.BORDER, 1)
		chip.custom_minimum_size = Vector2(96, 14)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = "%s : %s" % [Pal.NAMES[e], Run.SYNERGY_DESC[e]]
		var cl := UI.label("%s %d/%d%s" % [Pal.NAMES[e], counts[e], Run.synergy_need(), " ✓" if on else ""], 10, Pal.INK if on else Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		UI.put(chip, cl, Vector2(0, 1), Vector2(96, 12))
		syn_box.add_child(chip)

	# --- Droite : armes, amulettes, familiers en vignettes (le nom au survol)
	var right := UI.panel()
	UI.put(pm, right, Vector2(430, 62), Vector2(196, 280))
	var y := 4.0
	var groups := [[Loc.t("ARMES"), Run.weapons.map(func(w): return [Run.weapon_image(w), Pal.RARITY[w.rar],
			"%s %s" % [WeaponDB.get_def(w.type).name, Pal.RARITY_NAMES[w.rar]]])],
		[Loc.t("AMULETTES"), Run.amulets.map(func(a): return [a.image, Pal.RARITY[int(AmuletDB.get_def(a.id).rar)],
			"%s (%s)" % [AmuletDB.get_def(a.id).name, a.get("zone", "")]])],
		[Loc.t("FAMILIERS"), Run.familiars.filter(func(f): return Run.familiar_art.has(f)).map(func(f): return [Run.familiar_art[f].image,
			Pal.RARITY[int(FamiliarDB.get_def(f).rar)], String(FamiliarDB.get_def(f).name)])]]
	for g in groups:
		var items: Array = g[1]
		if items.is_empty() and g[0] == Loc.t("FAMILIERS"):
			continue
		UI.put(right, UI.label(g[0], 10, Pal.ACCENT), Vector2(8, y))
		y += 14.0
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 3)
		grid.add_theme_constant_override("v_separation", 3)
		UI.put(right, grid, Vector2(8, y), Vector2(180, 10))
		for it in items:
			var cell := UI.panel(Pal.PAPER, it[1], 1)
			cell.custom_minimum_size = Vector2(23, 23)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.tooltip_text = it[2]
			if it[0] != null:
				var th := UI.thumb(Analyzer.trim(it[0]), Vector2(19, 19))
				th.position = Vector2(2, 2)
				cell.add_child(th)
			grid.add_child(cell)
		if items.is_empty():
			UI.put(right, UI.label(Loc.t("aucune"), 10, Pal.DIM), Vector2(8, y))
		var rows := maxi(1, ceili(items.size() / 7.0))
		y += rows * 26.0 + 4.0

	# --- Sous les stats : les boutons en colonne, puis la seed
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	UI.put(pm, row, Vector2(14, 220), Vector2(196, 92))
	row.add_child(UI.hotkey(UI.button(Loc.t("Reprendre"), toggle_pause), [KEY_ENTER, KEY_KP_ENTER]))
	row.add_child(UI.hotkey(UI.button(Loc.t("Options"), func():
		var op := OptionsPanel.new()
		pm.add_child(op)
		op.done.connect(func(_r):
			op.queue_free()
			Engine.time_scale = arena.game_speed())), [KEY_O]))
	var sq := UI.button(Loc.t("Sauvegarder et quitter"), func():
		get_tree().paused = false
		arena.ended = true
		arena.done.emit("suspend"))
	sq.tooltip_text = Loc.t("Retour au menu. Tu pourras reprendre plus tard :\ncette vague recommencera depuis son début.")
	row.add_child(sq)
	row.add_child(UI.button(Loc.t("Abandonner la partie"), func():
		# confirmation : une partie abandonnée compte comme perdue
		var c := ChoiceScreens.confirm(Loc.t("Abandonner la partie ?"), Loc.t("Elle comptera comme une défaite."), Loc.t("Abandonner"), Loc.t("Annuler"), true)
		c.process_mode = Node.PROCESS_MODE_ALWAYS
		pm.add_child(c)
		c.done.connect(func(yes):
			c.queue_free()
			if yes:
				get_tree().paused = false
				arena.ended = true
				arena.done.emit("quit"))))
	for b in row.get_children():
		b.custom_minimum_size = Vector2(0, 20)
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 6)
	UI.put(pm, seed_row, Vector2(14, 322), Vector2(196, 16))
	seed_row.add_child(UI.label(Loc.t("Seed : %s%s") % [Run.seed_code(), Loc.t("  (rien ne se débloque)") if Run.seeded else ""], 10, Pal.DIM))
	var cs := UI.button(Loc.t("Copier"), func(): DisplayServer.clipboard_set(Run.seed_code()))
	cs.tooltip_text = Loc.t("Copier la seed pour la partager")
	seed_row.add_child(cs)
