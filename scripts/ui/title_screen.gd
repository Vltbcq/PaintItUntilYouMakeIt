class_name TitleScreen
extends Control
## Écran titre façon « galerie d'exposition » : les dessins du joueur sont accrochés dans des
## cadres qui changent régulièrement, et ses persos / ennemis / boss défilent en bas.
## Sans aucun dessin : l'expo est « en cours d'installation » (cadres bâchés, escabeau, pots de
## peinture, ruban de chantier, déménageurs qui passent avec des cadres et des cartons). Aucun texte.
## done("play" | "atelier" | "gallery" | "options" | "quit")

signal done(result)

const FRAME_KINDS := ["character", "boss", "enemy", "melee", "ranged", "amulet"]
static var KIND_NAMES := {"character": "Personnage", "boss": "Boss", "enemy": "Ennemi", "melee": "Arme",
	"ranged": "Arme", "amulet": "Amulette", "mark": "Marque", "bullet": "Projectile"}
const WALKER_KINDS := ["character", "enemy", "enemy", "boss"]
const FRAME_SPOTS := [Vector2(16, 64), Vector2(16, 186), Vector2(524, 64), Vector2(524, 186)]
const FRAME_SIZE := Vector2(100, 100)
const FLOOR_Y := 338.0

var t := 0.0
var entries := []           # entrées de galerie utilisables
var tex_cache := {}
var frames: Array = []      # {panel, pic, label}
var swap_t := 4.0
var swap_i := 0
var walkers: Array = []     # {tex, x, speed, scale, phase} ; en installation : {mover, load, x, speed, phase}
var installing := false     # aucun dessin : l'expo est en cours d'installation
var walk_t := 0.5
var parade: Control
var hero: TextureRect


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	UI.fill_bg(self)
	for k in FRAME_KINDS + ["bullet"]:
		entries += Meta.gallery(k)
	installing = entries.is_empty()
	# Version du jeu (en bas à droite) : écrite par la pipeline de Release à partir du tag
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "?")), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.z_index = 10
	UI.put(self, ver, Vector2(480, 346), Vector2(154, 12))

	# Mur de l'expo (papier) derrière les cadres et le défilé
	var rail := ColorRect.new()
	rail.color = UI.GOLD_DARK
	UI.put(self, rail, Vector2(0, 58), Vector2(640, 2))
	var floor_band := ColorRect.new()
	floor_band.color = UI.WOOD
	UI.put(self, floor_band, Vector2(0, 310), Vector2(640, 50))
	var floor_line := ColorRect.new()
	floor_line.color = UI.GOLD_DARK
	UI.put(self, floor_line, Vector2(0, 310), Vector2(640, 2))
	if installing:
		var site := _Site.new()
		site.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.put(self, site, Vector2.ZERO, Vector2(640, 360))

	# Défilé en bas (derrière le menu)
	parade = Control.new()
	parade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parade.z_index = 20   # les dessins qui se baladent passent devant le menu
	parade.draw.connect(_draw_parade)
	UI.put(self, parade, Vector2.ZERO, Vector2(640, 360))

	# Titre
	UI.logo(self, 320.0, 2.0)

	# Cadres
	for i in FRAME_SPOTS.size():
		frames.append(_make_frame(FRAME_SPOTS[i]))
	for i in frames.size():
		_fill_frame(i, false)

	# Menu au centre, dans un panneau
	var mp := UI.panel(Color(Pal.BG, 0.92), Pal.BORDER, 2)
	UI.put(self, mp, Vector2(208, 74), Vector2(224, 232))
	var sb := UI.hotkey(UI.button(Loc.t("Sauvegarde %d  ·  changer") % Meta.slot, func(): done.emit("slots")), [KEY_S, KEY_ESCAPE])
	UI.put(mp, sb, Vector2(22, 6), Vector2(180, 16))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	UI.put(mp, vb, Vector2(22, 30), Vector2(180, 150))
	var run := Meta.read_run() if Meta.has_run() else {}
	if not run.is_empty():
		var rb := UI.button(Loc.t("Reprendre"), func(): done.emit("resume"), 20)
		rb.tooltip_text = Loc.t("Vague %d · %s") % [int(run.wave), Meta.DIFFICULTIES[int(run.difficulty)].name]
		vb.add_child(UI.hotkey(rb, [KEY_ENTER, KEY_KP_ENTER, KEY_C]))
		vb.add_child(UI.hotkey(UI.button(Loc.t("Nouvelle partie"), func(): done.emit("play")), [KEY_N]))
	else:
		vb.add_child(UI.hotkey(UI.button(Loc.t("Nouvelle partie"), func(): done.emit("play"), 20), [KEY_ENTER, KEY_KP_ENTER, KEY_N]))
	var ab := UI.hotkey(UI.button(Loc.t("Atelier  ◆ %d") % Meta.pigments(), func(): done.emit("atelier")), [KEY_A])
	vb.add_child(ab)
	if Meta.atelier_new():
		_glow(ab)
	vb.add_child(UI.hotkey(UI.button(Loc.t("Galerie"), func(): done.emit("gallery")), [KEY_G]))
	# Codex et Statistiques sur la même ligne (le menu tient dans son panneau)
	var cs := HBoxContainer.new()
	cs.add_theme_constant_override("separation", 4)
	var cb := UI.hotkey(UI.button(Loc.t("Codex"), func(): done.emit("codex")), [KEY_B])
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cs.add_child(cb)
	var stb := UI.hotkey(UI.button(Loc.t("Stats"), func(): done.emit("stats")), [KEY_T])
	stb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cs.add_child(stb)
	vb.add_child(cs)
	vb.add_child(UI.hotkey(UI.button(Loc.t("Options"), func(): done.emit("options")), [KEY_O]))
	vb.add_child(UI.button(Loc.t("Quitter"), func(): done.emit("quit")))
	var d := Meta.data
	var info := Loc.t("Record : vague %d\nParties : %d  ·  Victoires : %d") % [int(d.best_wave), int(d.runs), int(d.wins)]
	UI.put(mp, UI.label(info, 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 198), Vector2(224, 30))

	for i in 3:
		_spawn_walker(randf_range(40.0, 600.0))
	UI.use_menu_font(self)   # tout l'écran titre en Yoster Island


# ------------------------------------------------------------------ Cadres

## Bouton Atelier quand un nouvel achat est possible : il pulse en doré, avec une pastille « ! ».
func _glow(b: Button) -> void:
	b.tooltip_text = Loc.t("Tu peux t'offrir quelque chose de nouveau !")
	b.add_theme_color_override("font_color", Pal.ACCENT)
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "self_modulate", Color(1.45, 1.25, 0.7), 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "self_modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)
	# Pastille 10×10 dessinée au pixel près (le « ! » de la police est trop haut pour elle)
	var img := Image.create_empty(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(UI.GOLD_DARK)
	img.fill_rect(Rect2i(1, 1, 8, 8), Pal.ACCENT)
	img.fill_rect(Rect2i(4, 2, 2, 4), Pal.INK)   # la barre
	img.fill_rect(Rect2i(4, 7, 2, 1), Pal.INK)   # le point
	var badge := TextureRect.new()
	badge.texture = ImageTexture.create_from_image(img)
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)   # (centrée verticalement sur le bouton)
	badge.offset_left = -15.0
	badge.offset_right = -5.0
	badge.offset_top = -5.0
	badge.offset_bottom = 5.0
	b.add_child(badge)


func _make_frame(pos: Vector2) -> Dictionary:
	# Cadre doré + passe-partout papier
	var outer := UI.panel(Color("b07d1c"), Pal.ACCENT, 2)
	UI.put(self, outer, pos, FRAME_SIZE)
	var inner := UI.panel(Pal.PAPER, Color("8c6a1a"), 1)
	UI.put(outer, inner, Vector2(6, 6), FRAME_SIZE - Vector2(12, 12))
	var pic := TextureRect.new()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(inner, pic, Vector2(4, 4), FRAME_SIZE - Vector2(20, 20))
	# Petit cartel sous le cadre
	var plate := UI.panel(Pal.INK, Color("8c6a1a"), 1)
	UI.put(self, plate, pos + Vector2(12, FRAME_SIZE.y + 2), Vector2(FRAME_SIZE.x - 24, 14))
	var label := UI.label("", 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(plate, label, Vector2(0, 1), Vector2(FRAME_SIZE.x - 24, 12))
	if installing:
		# Expo en installation : le cadre est bâché et n'a pas encore de cartel
		plate.visible = false
		var drape := _Drape.new()
		drape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		drape.seed_v = int(pos.x + pos.y)
		UI.put(outer, drape, Vector2(-5, -7), Vector2(FRAME_SIZE.x + 10, FRAME_SIZE.y - 14))   # le bas du cadre dépasse
	return {"panel": outer, "pic": pic, "label": label, "inner": inner}


func _texture(e: Dictionary) -> Texture2D:
	var key: String = e.file
	if not tex_cache.has(key):
		var img := Meta.gallery_image(e)
		if img == null:
			return null
		img = Analyzer.trim(img)
		tex_cache[key] = ImageTexture.create_from_image(img)   # sans bord (comme les dessins par défaut)
	return tex_cache[key]


## Met un dessin au hasard dans le cadre i (en évitant ceux déjà affichés).
func _fill_frame(i: int, animate: bool) -> void:
	var f: Dictionary = frames[i]
	var tex: Texture2D = null
	var kind := ""
	if not entries.is_empty():
		var shown := []
		for o in frames:
			shown.append(o.get("file", ""))
		for attempt in 12:
			var e: Dictionary = entries.pick_random()
			if e.file in shown and entries.size() > frames.size():
				continue
			tex = _texture(e)
			if tex:
				kind = e.kind
				f.file = e.file
				break
	if tex == null and not installing:
		tex = ImageTexture.create_from_image(Gfx.icon(Gfx.ICON_UNKNOWN))
		kind = ""
	var pic: TextureRect = f.pic
	var label: Label = f.label
	if animate:
		var tw := create_tween()
		tw.tween_property(pic, "modulate:a", 0.0, 0.35)
		tw.tween_callback(func():
			pic.texture = tex
			label.text = KIND_NAMES.get(kind, Loc.t("À dessiner !")))
		tw.tween_property(pic, "modulate:a", 1.0, 0.35)
	else:
		pic.texture = tex
		label.text = KIND_NAMES.get(kind, Loc.t("À dessiner !"))


# ------------------------------------------------------------------ Défilé

func _spawn_walker(x := -60.0) -> void:
	if installing:
		# Déménageurs : un carton, un cadre retourné, ou un grand cadre porté à deux
		walkers.append({"mover": true, "load": ["box", "frame", "duo"].pick_random(), "x": x,
			"speed": randf_range(24.0, 34.0), "phase": randf() * TAU})
		return
	var pool := entries.filter(func(e): return e.kind in WALKER_KINDS)
	if pool.is_empty():
		return
	var e: Dictionary = pool.pick_random()
	var tex := _texture(e)
	if tex == null:
		return
	var big := maxf(tex.get_width(), tex.get_height())
	var sc := minf(3.0, 56.0 / big)   # gros et bien visible
	if sc >= 1.0:
		sc = floorf(sc)                # échelle entière = pixels nets
	walkers.append({"tex": tex, "x": x, "speed": randf_range(22.0, 38.0) * (0.7 if e.kind == "boss" else 1.0),
		"scale": sc, "phase": randf() * TAU})


func _process(delta: float) -> void:
	t += delta
	# Les cadres flottent un peu
	for i in frames.size():
		var f: Dictionary = frames[i]
		f.panel.position.y = FRAME_SPOTS[i].y + sin(t * 1.3 + i * 1.7) * 2.0
	swap_t -= delta
	if swap_t <= 0.0 and entries.size() > 0:
		swap_t = 3.0
		swap_i = (swap_i + 1) % frames.size()
		_fill_frame(swap_i, true)
	walk_t -= delta
	if walk_t <= 0.0:
		walk_t = randf_range(2.0, 3.5)
		_spawn_walker()
	for w in walkers:
		w.x += w.speed * delta
	walkers = walkers.filter(func(w): return w.x < 720.0)
	parade.queue_redraw()


func _draw_parade() -> void:
	for w in walkers:
		if w.has("mover"):
			_draw_mover(w)
			continue
		var tex: Texture2D = w.tex
		var sz: Vector2 = tex.get_size() * w.scale
		var bob := absf(sin(t * 7.0 + w.phase)) * 3.0
		var pos := Vector2(w.x - sz.x / 2.0, FLOOR_Y - sz.y - bob)
		parade.draw_set_transform(Vector2(pos.x + sz.x / 2.0, FLOOR_Y), 0.0, Vector2(1.0, 0.35))
		parade.draw_circle(Vector2.ZERO, sz.x * 0.4, Color(0, 0, 0, 0.3))
		parade.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		parade.draw_texture_rect(tex, Rect2(pos, sz), false)


# ------------------------------------------------------------------ Expo en installation

const MOVER := Color("3a6ea5")        # bleu de travail des déménageurs
const SKIN := Color("e8b890")
const CAP := Color("d2433a")
const BOX := Color("c8975a")
const BOX_D := Color("8a6436")
const FRAME_BACK := Color("8a5a2b")
const FRAME_BAR := Color("b9864a")


## Un déménageur (ou deux) qui traverse la page avec sa charge.
func _draw_mover(w: Dictionary) -> void:
	var x: float = w.x
	var step: float = t * 7.0 + float(w.phase)
	var bob := absf(sin(step)) * 2.0
	match String(w.load):
		"box":
			_person(x, step)
			var b := Rect2(x + 1, FLOOR_Y - 31 - bob, 17, 14)   # porté contre lui : la tête reste visible
			parade.draw_rect(b, BOX)
			parade.draw_rect(b, BOX_D, false, 1.0)
			parade.draw_rect(Rect2(b.position.x + 9, b.position.y, 4, b.size.y), Color("e6d3a8"))   # scotch
			parade.draw_line(b.position + Vector2(0, 5), b.position + Vector2(b.size.x, 5), BOX_D, 1.0)
		"frame":
			_person(x, step)
			_frame_back(Rect2(x + 6, FLOOR_Y - 44 - bob, 24, 32))   # porté sur le côté
		"duo":
			_person(x, step)
			_person(x - 64, step + PI)
			_frame_back(Rect2(x - 70, FLOOR_Y - 70 - bob, 78, 26))   # à bout de bras, au-dessus des têtes


func _person(x: float, step: float) -> void:
	var y := FLOOR_Y
	var sw := sin(step) * 4.0
	parade.draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.35))
	parade.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.25))
	parade.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	parade.draw_line(Vector2(x - 2, y - 14), Vector2(x - 3 + sw, y), Color("27496e"), 3.0)    # jambes
	parade.draw_line(Vector2(x + 2, y - 14), Vector2(x + 3 - sw, y), Color("27496e"), 3.0)
	parade.draw_rect(Rect2(x - 5, y - 30, 10, 17), MOVER)                           # corps
	parade.draw_rect(Rect2(x - 5, y - 30, 10, 17), Pal.INK, false, 1.0)
	parade.draw_circle(Vector2(x, y - 35), 5.0, SKIN)                                # tête
	parade.draw_arc(Vector2(x, y - 35), 5.0, 0.0, TAU, 14, Pal.INK, 1.0)
	parade.draw_rect(Rect2(x - 6, y - 41, 12, 3), CAP)                               # casquette
	parade.draw_line(Vector2(x + 3, y - 28), Vector2(x + 9, y - 36), SKIN, 2.5)     # bras levés
	parade.draw_line(Vector2(x - 3, y - 28), Vector2(x + 3, y - 38), SKIN, 2.5)


## Un cadre vu de dos (châssis et traverses).
func _frame_back(r: Rect2) -> void:
	parade.draw_rect(r, FRAME_BACK)
	parade.draw_rect(r.grow(-3), Color("6f4520"))
	parade.draw_line(r.position + Vector2(3, r.size.y / 2.0), r.end - Vector2(3, r.size.y / 2.0), FRAME_BAR, 3.0)
	parade.draw_line(r.position + Vector2(r.size.x / 2.0, 3), r.position + Vector2(r.size.x / 2.0, r.size.y - 3), FRAME_BAR, 3.0)
	parade.draw_rect(r, Pal.INK, false, 1.0)


## Drap posé sur un cadre : il dépasse un peu, avec des plis et un bas ondulé.
class _Drape extends Control:
	var seed_v := 0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cloth := Color("eee6d6")
		var shade := Color("cfc3ab")
		var pts := PackedVector2Array([Vector2(6, 2), Vector2(w - 6, 2), Vector2(w - 1, 10)])
		for i in range(9, -1, -1):   # bas ondulé
			var x := w * i / 9.0
			pts.append(Vector2(x, h - 4.0 + sin(i * 1.7 + seed_v) * 3.0))
		pts.append(Vector2(1, 10))
		draw_colored_polygon(pts, cloth)
		for i in 5:   # plis
			var x := w * (0.15 + 0.18 * i) + sin(seed_v + i) * 3.0
			draw_line(Vector2(x, 10 + (i % 2) * 6), Vector2(x + 4.0 * sin(i + seed_v), h - 7), shade, 2.0)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("9c8f78"), 1.0)


## Le chantier : escabeau, pots de peinture et ruban de chantier au sol.
class _Site extends Control:
	func _draw() -> void:
		var fy := 338.0
		# ruban de chantier jaune et noir le long du sol
		var x := 0.0
		var k := 0
		while x < 640.0:
			draw_rect(Rect2(x, 314, 10, 5), Color("f0c43a") if k % 2 == 0 else Color("2b2433"))
			x += 10.0
			k += 1
		# escabeau (près des cadres de gauche)
		var wood := Color("b9864a")
		draw_line(Vector2(132, fy), Vector2(150, fy - 74), wood, 3.0)
		draw_line(Vector2(168, fy), Vector2(150, fy - 74), wood, 3.0)
		for i in 4:
			var yy := fy - 14.0 - i * 15.0
			var off := (fy - yy) * 18.0 / 74.0
			draw_line(Vector2(132 + off, yy), Vector2(168 - off, yy), wood, 2.0)
		# pots de peinture (et une coulure)
		for p in [[476.0, Color("d2433a")], [500.0, Color("3a86ff")], [588.0, Color("f0c43a")]]:
			var px: float = p[0]
			draw_rect(Rect2(px, fy - 16, 16, 16), Color("b8b8c4"))
			draw_rect(Rect2(px, fy - 16, 16, 4), p[1])
			draw_rect(Rect2(px, fy - 16, 16, 16), Pal.INK, false, 1.0)
			draw_arc(Vector2(px + 8, fy - 16), 7.0, PI, TAU, 10, Pal.INK, 1.0)   # anse
		draw_circle(Vector2(520, fy + 2), 5.0, Color(0.23, 0.53, 1.0, 0.8))
		# un pinceau posé sur le pot jaune
		draw_line(Vector2(584, fy - 22), Vector2(610, fy - 12), Color("8a5a2b"), 2.0)
		draw_rect(Rect2(580, fy - 25, 6, 5), Color("f0c43a"))
