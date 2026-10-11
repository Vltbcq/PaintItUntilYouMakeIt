class_name DrawScreen
extends Control
## Écran de dessin générique : toile, encre limitée, outils débloquables, aperçu des stats.
## Émet done({image, effect, outline}) ou done(null) si annulé.
## L'encre ne se dépense que sur les CONTOURS : l'intérieur d'une forme est gratuit.

signal done(result)

const TOOLS := [
	["brush", "Pinceau", "", KEY_B],
	["eraser", "Gomme", "", KEY_E],
	["line", "Ligne", "tool_line", KEY_L],
	["rect", "Rectangle", "tool_rect", KEY_R],
	["ellipse", "Ellipse", "tool_ellipse", KEY_O],
	["triangle", "Triangle", "tool_triangle", KEY_T],
	["fill", "Remplir", "", KEY_F],
	["select", "Sélection", "", KEY_S],
]

var cfg: Dictionary
var img: Image
var tex: ImageTexture
var shape_base: Image
var budget := 0
var used := 0
var tool := "brush"
var brush := 1
var col_a: Color = Pal.SHADES[0][0]
var col_b: Color = Pal.SHADES[0][2]
var gradient := false
var mirror := false
var mirror_h := false   # symétrie haut / bas (avec mirror : les 4 coins)
var effect := ""
var outline := false
var drawing := false
var rmb := false
var stroke_len := 0.0
var stroke_total := 1     # forme en cours : nombre de pixels du contour (dégradé de bout en bout)
var stroke_pts: Array[Vector2i] = []   # trait au pinceau en cours, dans l'ordre (dégradé)
var grad_end := 0         # dégradé : 0 = la palette choisit le DÉBUT, 1 = la FIN
var grad_chips: Array = []
var sel_bar: Control      # boutons Tourner / Miroir, visibles quand une sélection est levée
var last_cell := Vector2i.ZERO
var start_cell := Vector2i.ZERO
# Sélection : "" | "making" (rectangle en cours) | "floating" (zone levée) | "drag" (on la déplace)
var sel_state := ""
var sel_a := Vector2i.ZERO
var sel_b := Vector2i.ZERO
var sel_img: Image          # les pixels sélectionnés
var sel_base: Image         # le dessin SANS ces pixels
var sel_pos := Vector2i.ZERO
var drag_from := Vector2i.ZERO
var drag_pos0 := Vector2i.ZERO
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []

var view: CanvasView
var ink_bar: Control
var stats_label: StatText
var color_box: Control     # petit cercle des faiblesses + couleur principale du dessin, en direct
var color_ring: Control
var main_color_label: Label
var main_color := 0
var color_label: Label
var warn_label: Label
var tool_btns := {}
var toggle_btns := {}
var size_btns := {}
var fx_btns := {}
var swatches: Array = []
var overlay: Control
var preview_rect: TextureRect
var preview_tex: ImageTexture
var preview_mat: ShaderMaterial
var outline_btn: Button
var body_view: Control        # aperçu de l'objet sur le perso, à la même échelle
var view_btn: Button


func _init(c: Dictionary) -> void:
	cfg = c


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var s: Vector2i = cfg.size
	# Dessin de départ plus grand que la toile (pris dans la galerie pour le modifier) : la toile
	# s'agrandit pour le montrer entier, un cadre montre la taille permise (cfg.fit) et on ne
	# peut valider que quand tout le dessin tient dedans
	if cfg.get("base") != null:
		var u: Vector2i = (cfg.base as Image).get_used_rect().size
		if u.x > s.x or u.y > s.y:
			cfg = cfg.duplicate()   # (la config de l'appelant garde sa vraie taille)
			cfg.fit = s
			s = Vector2i(maxi(s.x, u.x), maxi(s.y, u.y))
			cfg.size = s
	img = Image.create_empty(s.x, s.y, false, Image.FORMAT_RGBA8)
	if cfg.get("base") != null:
		_blit_centered(cfg.base)
	tex = ImageTexture.create_from_image(img)
	budget = int(cfg.ink)
	var fx: String = cfg.get("effect", "")
	if fx in Meta.effects():
		effect = fx
	outline = cfg.get("outline", false)
	_build_ui()
	_recount()
	_changed()


# ------------------------------------------------------------------ Interface

func _build_ui() -> void:
	UI.fill_bg(self)
	UI.put(self, UI.label(cfg.title, 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(640, 22))
	var sub := UI.label(cfg.get("sub", ""), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.max_lines_visible = 2
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.mouse_filter = Control.MOUSE_FILTER_STOP
	sub.tooltip_text = cfg.get("sub", "")
	UI.put(self, sub, Vector2(20, 30), Vector2(600, 26))

	# --- Outils (gauche)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	UI.put(self, left, Vector2(8, 62), Vector2(116, 290))
	# Outils en icônes (assets/ui/tools, dessinées par docs/tool_icons.py), rangés par famille ;
	# le nom et le raccourci s'affichent au survol.
	var icon_of := {"brush": "pinceau", "eraser": "gomme", "line": "ligne", "rect": "rect", "ellipse": "ellipse",
		"triangle": "triangle", "fill": "remplir", "select": "selection"}
	var tools := {}
	for t in TOOLS:
		if not Meta.has(t[2]):
			continue
		var id: String = t[0]
		var tip := "%s (%s)" % [t[1], OS.get_keycode_string(t[3])]
		if id == "select":
			tip = "Sélection (S) : trace un rectangle, glisse-le pour le déplacer,\nSuppr pour l'effacer, clic à côté (ou clic droit) pour le poser"
		var b := _icon_button(icon_of[id], tip, func(): _set_tool(id))
		tool_btns[id] = b
		tools[id] = b
	_tool_row(left, "DESSINER", ["brush", "eraser", "fill", "select"].filter(func(k): return tools.has(k)).map(func(k): return tools[k]))
	_tool_row(left, "FORMES", ["line", "rect", "ellipse", "triangle"].filter(func(k): return tools.has(k)).map(func(k): return tools[k]))
	var sizes := []
	if Meta.has("tool_big"):
		for n in [1, 2, 3]:
			var sz: int = n
			var b := _icon_button("taille%d" % n, "Taille du pinceau : %d pixel%s" % [n, "s" if n > 1 else ""], func(): _set_brush(sz))
			size_btns[n] = b
			sizes.append(b)
	_tool_row(left, "TAILLE", sizes)
	var opts := []
	if Meta.has("tool_mirror"):
		toggle_btns.mirror = _icon_button("symetrie", "Symétrie : ce que tu dessines d'un côté se dessine aussi de l'autre", func(): _toggle("mirror"))
		opts.append(toggle_btns.mirror)
	if Meta.has("tool_mirror_h"):
		toggle_btns.mirror_h = _icon_button("symetrie_h", "Symétrie haut / bas (H) : ce que tu dessines en haut se dessine aussi en bas", func(): _toggle("mirror_h"))
		opts.append(toggle_btns.mirror_h)
	if Meta.has("gradient"):
		toggle_btns.gradient = _icon_button("degrade", "Dégradé (G) : chaque trait passe de la couleur de début à celle de fin,\nsur toute sa longueur (choisis-les avec les pastilles Début / Fin)", func(): _toggle("gradient"))
		opts.append(toggle_btns.gradient)
	_tool_row(left, "OPTIONS", opts)
	# Défaire / refaire à gauche, tout effacer à part, à droite
	var hist := HBoxContainer.new()
	hist.add_theme_constant_override("separation", 2)
	hist.add_child(_icon_button("defaire", "Défaire (Ctrl+Z)", _undo))
	hist.add_child(_icon_button("refaire", "Refaire (Ctrl+Y)", _redo))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hist.add_child(gap)
	hist.add_child(_icon_button("effacer", "Tout effacer (se défait avec Ctrl+Z)", _clear))
	var sep := Control.new()
	sep.custom_minimum_size.y = 3
	left.add_child(sep)
	left.add_child(hist)
	var fxs := Meta.effects()
	if fxs.size() > 1:
		left.add_child(UI.label("EFFET (-15% encre)", 10, Pal.DIM))
		for f in fxs:
			var fid: String = f
			var b := UI.button(Stats.EFFECT_NAMES[f], func(): _set_effect(fid))
			b.tooltip_text = Stats.effect_text(fid, String(cfg.kind))   # ce que cet effet fait sur CE dessin
			left.add_child(b)
			fx_btns[f] = b

	# --- Toile (centre)
	var s: Vector2i = cfg.size
	var scale_px := maxi(2, mini(284 / s.x, 264 / s.y))
	view = CanvasView.new(self, scale_px)
	var vs := Vector2(s * scale_px)
	# Cadre doré (fixe) + fenêtre qui coupe la toile quand on zoome (molette, vers le curseur)
	var vpos := Vector2(maxf(156.0, 134 + (284 - vs.x) / 2.0), 62 + (264 - vs.y) / 2.0)
	var frame := _CanvasFrame.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(self, frame, vpos - Vector2(3, 3), vs + Vector2(6, 6))
	var port := Control.new()
	port.clip_contents = true
	port.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.put(self, port, vpos, vs)
	UI.put(port, view, Vector2.ZERO, vs)
	# Sélection levée : « Tourner » (R) et « Miroir » (F), posés sur la toile tant qu'elle est levée
	sel_bar = HBoxContainer.new()
	sel_bar.add_theme_constant_override("separation", 2)
	var rot_b := UI.button("Tourner (R)", func(): _sel_transform("rot"))
	rot_b.tooltip_text = "Tourner la sélection d'un quart de tour"
	var flip_b := UI.button("Miroir (F)", func(): _sel_transform("flip"))
	flip_b.tooltip_text = "Retourner la sélection en miroir"
	sel_bar.add_child(rot_b)
	sel_bar.add_child(flip_b)
	UI.put(self, sel_bar, vpos + Vector2(2, vs.y - 18), Vector2(150, 16))
	sel_bar.visible = false
	ink_bar = Control.new()
	ink_bar.draw.connect(_draw_ink_bar)
	UI.put(self, ink_bar, Vector2(134, 332), Vector2(284, 12))
	warn_label = UI.label(INK_HINT, 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(self, warn_label, Vector2(134, 346), Vector2(284, 12))

	# --- Couleurs + aperçu (droite)
	UI.put(self, UI.label("COULEURS", 10, Pal.DIM), Vector2(426, 62))
	var els := Meta.elements()
	for i in els.size():
		var e: int = els[i]
		for row in Pal.SHADE_ORDER.size():   # 5 nuances, de la plus foncée à la plus claire
			var sw := _Swatch.new(Pal.SHADES[e][Pal.SHADE_ORDER[row]], self)
			UI.put(self, sw, Vector2(426 + i * 18, 75 + row * 10), Vector2(16, 9))
			swatches.append(sw)
	color_label = UI.label("", 10, Pal.TEXT)
	UI.put(self, color_label, Vector2(426, 126), Vector2(136, 12))
	# Dégradé : 2 pastilles. On clique l'une, puis une couleur de la palette pour la changer.
	for k in 2:
		var chip := _GradChip.new(self, k)
		chip.tooltip_text = ["Début du dégradé : clique-moi, puis une couleur", "Fin du dégradé : clique-moi, puis une couleur"][k]
		UI.put(self, chip, Vector2(426 + k * 64, 125), Vector2(60, 14))
		grad_chips.append(chip)

	# Aperçu en jeu avec ou sans contour noir
	var pv := UI.panel(Pal.PAPER, Pal.BORDER, 1)
	UI.put(self, pv, Vector2(558, 62), Vector2(74, 62))
	preview_tex = ImageTexture.create_from_image(Gfx.padded(img))
	preview_mat = Gfx.material(effect, outline)
	preview_rect = TextureRect.new()
	preview_rect.texture = preview_tex
	preview_rect.material = preview_mat
	preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(pv, preview_rect, Vector2(2, 2), Vector2(70, 58))
	outline_btn = UI.button("", _toggle_outline)
	outline_btn.tooltip_text = "Contour noir autour du dessin en jeu (touche C)"
	# (plus large que l'aperçu vers la GAUCHE : à 74 px le texte l'élargissait et il dépassait à droite)
	UI.put(self, outline_btn, Vector2(550, 126), Vector2(82, 14))
	UI.put(self, UI.label("APERÇU", 10, Pal.DIM), Vector2(426, 144))
	stats_label = StatText.new(2)   # icônes des stats (le nom au survol)
	var with_color: bool = cfg.kind in ["character", "melee", "ranged", "bullet", "amulet", "familiar", "enemy", "boss"]
	UI.put(self, stats_label, Vector2(426, 161), Vector2(124 if with_color else 206, 147))
	if with_color:
		# Cercle des faiblesses à côté des stats, et la couleur principale du dessin en direct
		color_box = Control.new()
		color_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.put(self, color_box, Vector2(552, 164), Vector2(84, 130))
		UI.cercle(color_box, Vector2.ZERO, true)
		color_ring = Control.new()
		color_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_ring.draw.connect(_draw_color_ring)
		UI.put(color_box, color_ring, Vector2.ZERO, Vector2(84, 98))
		main_color_label = UI.label("", 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		UI.put(color_box, main_color_label, Vector2(0, 100), Vector2(84, 28))
	if Run.active and Run.character != null and cfg.kind in ["melee", "ranged", "bullet", "amulet", "mark"]:
		_build_body_preview()

	var bx := 426.0
	if cfg.get("gallery", "") != "" and cfg.get("cancel_label", "") != "< Choix":
		# (avec « < Choix », l'écran de choix montre déjà la galerie : pas de doublon ici)
		UI.put(self, UI.button("Galerie", _open_gallery), Vector2(bx, 318), Vector2(66, 16))
		bx += 70
	if cfg.get("random", false):
		UI.put(self, UI.button("Au hasard", _random_monster), Vector2(bx, 318), Vector2(66, 16))
	if cfg.get("cancel", false):
		UI.put(self, UI.hotkey(UI.button(cfg.get("cancel_label", "Retour"), func(): done.emit(null)), [KEY_ESCAPE]), Vector2(426, 338), Vector2(66, 16))
	UI.put(self, UI.hotkey(UI.button("VALIDER →", _validate), [KEY_ENTER, KEY_KP_ENTER]), Vector2(496, 338), Vector2(136, 16))
	_refresh_buttons()


## Cadre de la toile (or + filet d'encre), qui ne bouge pas quand on zoome.
class _CanvasFrame extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Pal.ACCENT)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Pal.INK)


## Pastille « Début » ou « Fin » du dégradé (celle qui est active reçoit la prochaine couleur).
class _GradChip extends Control:
	var ds: DrawScreen
	var k := 0

	func _init(s: DrawScreen, which: int) -> void:
		ds = s
		k = which
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			ds.grad_end = k
			Sfx.play("click")
			ds._refresh_buttons()

	func _draw() -> void:
		var on := ds.grad_end == k
		var c: Color = ds.col_a if k == 0 else ds.col_b
		draw_rect(Rect2(Vector2.ZERO, size), Pal.INK)
		draw_rect(Rect2(1, 1, 12, size.y - 2), c)
		draw_string(UI.font, Vector2(16, size.y - 3), "Début" if k == 0 else "Fin", HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Pal.ACCENT if on else Pal.DIM)
		if on:
			draw_rect(Rect2(Vector2.ZERO, size), Pal.ACCENT, false, 1.0)


class _Swatch extends Control:
	var color: Color
	var ds: DrawScreen

	func _init(c: Color, s: DrawScreen) -> void:
		color = c
		ds = s
		tooltip_text = "Clic : choisir cette couleur (en dégradé : pour la pastille active)"

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				if ds.gradient and ds.grad_end == 1:
					ds.col_b = color
				else:
					ds.col_a = color
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				ds.col_b = color
			if ds.tool == "eraser":
				ds._set_tool("brush")
			Sfx.play("click")
			ds._refresh_buttons()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), color)
		if ds.col_a == color:
			draw_rect(Rect2(Vector2.ZERO, size), Pal.ACCENT, false, 2.0)
		elif ds.gradient and ds.col_b == color:
			draw_rect(Rect2(Vector2.ZERO, size), Pal.TEXT, false, 1.0)


func _draw_ink_bar() -> void:
	var w := ink_bar.size.x
	var eb := eff_budget()
	ink_bar.draw_rect(Rect2(0, 0, w, 12), Pal.INK)
	var t := clampf(float(used) / maxf(1.0, budget), 0.0, 1.0)
	var col := Pal.ACCENT if used < eb else Pal.BAD
	ink_bar.draw_rect(Rect2(1, 1, (w - 2) * t, 10), col.darkened(0.2))
	if eb < budget:
		var x := (w - 2) * float(eb) / budget
		ink_bar.draw_rect(Rect2(1 + x, 1, w - 2 - x, 10), Color(Pal.BORDER, 0.7))
	var mi := int(cfg.get("min_ink", 0))
	if mi > 0:
		var mx := 1 + (w - 2) * float(mi) / budget
		ink_bar.draw_rect(Rect2(mx, 0, 2, 12), Pal.GOOD if used >= mi else Pal.BAD)
	var txt := "ENCRE  %d / %d  · contours seulement" % [used, eb]
	if mi > 0:
		txt = "ENCRE  %d / %d   (minimum %d)" % [used, eb, mi]
	ink_bar.draw_string(UI.font, Vector2(0, 10), txt, HORIZONTAL_ALIGNMENT_CENTER, w, UI.fs(10), Pal.TEXT)


func _refresh_buttons() -> void:
	for id in tool_btns:
		_mark(tool_btns[id], id == tool)
	if toggle_btns.has("mirror"):
		_mark(toggle_btns.mirror, mirror)
	if toggle_btns.has("mirror_h"):
		_mark(toggle_btns.mirror_h, mirror_h)
	if toggle_btns.has("gradient"):
		_mark(toggle_btns.gradient, gradient)
	for n in size_btns:
		_mark(size_btns[n], n == brush)
	for f in fx_btns:
		_mark(fx_btns[f], f == effect)
	_hint()
	if outline_btn:
		outline_btn.text = "Bord : %s" % ("oui" if outline else "non")
		_mark(outline_btn, outline)
	for sw in swatches:
		sw.queue_redraw()
	var ea := Pal.element_of(col_a)
	color_label.text = "%s (%s)" % [Pal.COLOR_NAMES[ea], Pal.NAMES[ea]]
	color_label.visible = not gradient   # en dégradé : les pastilles Début / Fin à la place
	for chip in grad_chips:
		chip.visible = gradient
		chip.queue_redraw()
	if view:
		view.queue_redraw()


## Une famille d'outils : petit titre puis une rangée d'icônes (rien si elle est vide).
func _tool_row(parent: Control, title: String, btns: Array) -> void:
	if btns.is_empty():
		return
	if title != "":
		parent.add_child(UI.label(title, 10, Pal.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for b in btns:
		row.add_child(b)
	parent.add_child(row)


## Bouton d'outil en icône seule (le nom et le raccourci s'affichent au survol).
func _icon_button(icon: String, tip: String, cb: Callable) -> Button:
	var b := UI.button("", cb)
	b.icon = load("res://assets/ui/tools/%s.png" % icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.custom_minimum_size = Vector2(27, 22)
	b.tooltip_text = tip
	return b


func _mark(b: Button, on: bool) -> void:
	if on:
		b.add_theme_stylebox_override("normal", UI.sb(UI.SELECTED, Pal.ACCENT, 1))
		b.add_theme_color_override("font_color", Pal.ACCENT)
	else:
		b.remove_theme_stylebox_override("normal")
		b.remove_theme_color_override("font_color")


func _set_tool(t: String) -> void:
	if t != "select":
		_sel_commit()
	tool = t
	_refresh_buttons()


func _set_brush(n: int) -> void:
	brush = n
	_refresh_buttons()


## Montre l'objet en cours de dessin sur le perso (avec ses amulettes et armes déjà posées),
## à la même échelle qu'en jeu, pour se rendre compte de la taille.
func _build_body_preview() -> void:
	body_view = UI.panel(Pal.PAPER, Pal.BORDER, 1)
	body_view.clip_contents = true
	UI.put(self, body_view, Vector2(426, 158), Vector2(206, 154))
	view_btn = UI.button("", _toggle_body_view)
	view_btn.tooltip_text = "Touche V"
	UI.put(self, view_btn, Vector2(502, 142), Vector2(130, 14))

	var comp := Run.build_player_image()
	var cc := Run.char_center()
	var cr: Rect2i = Run.char_a.rect
	var isz := Vector2(img.get_size())
	var item_c := cc
	match cfg.kind:
		"melee", "ranged":
			item_c = cc + Vector2(cr.size.x / 2.0 + isz.x * 0.3, 2.0)
		"bullet":
			item_c = cc + Vector2(cr.size.x / 2.0 + 10.0 + isz.x / 2.0, 0.0)
	# Rectangles (en pixels du dessin) de tout ce qu'on affiche
	var parts := []   # [texture, material, rect]
	parts.append([ImageTexture.create_from_image(Gfx.padded(comp)),
		Gfx.material(Run.char_effect, Run.char_outline), Rect2(Vector2(-1, -1), Vector2(comp.get_size()) + Vector2(2, 2))])
	for w in Run.weapons:
		var wi := Run.weapon_image(w)
		var ws := Vector2(wi.get_size())
		var art: Dictionary = Run.art_of(w)
		parts.append([Gfx.texture(wi), Gfx.material(art.effect, art.get("outline", false)),
			Rect2(cc + w.anchor - ws / 2.0 - Vector2.ONE, ws + Vector2(2, 2))])
	parts.append([preview_tex, preview_mat, Rect2(item_c - isz / 2.0 - Vector2.ONE, isz + Vector2(2, 2))])
	var bounds: Rect2 = parts[0][2]
	for pt in parts:
		bounds = bounds.merge(pt[2])
	var avail := body_view.size - Vector2(8, 8)
	var sc := minf(avail.x / bounds.size.x, avail.y / bounds.size.y)
	if sc >= 1.0:
		sc = floorf(sc)
	var off := (body_view.size - bounds.size * sc) / 2.0 - bounds.position * sc
	for pt in parts:
		var tr := TextureRect.new()
		tr.texture = pt[0]
		tr.material = pt[1]
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r: Rect2 = pt[2]
		UI.put(body_view, tr, off + r.position * sc, r.size * sc)
	_set_body_view(false)   # de base : les stats (V ou le bouton pour voir sur le perso)


func _toggle_body_view() -> void:
	_set_body_view(not body_view.visible)


func _set_body_view(on: bool) -> void:
	body_view.visible = on
	stats_label.visible = not on
	if color_box:
		color_box.visible = not on
	view_btn.text = "Voir : les stats" if on else "Voir : sur le perso"


func _toggle_outline() -> void:
	outline = not outline
	preview_mat.set_shader_parameter("outline", outline)
	_refresh_buttons()


func _toggle(what: String) -> void:
	if what == "mirror":
		mirror = not mirror
	elif what == "mirror_h":
		mirror_h = not mirror_h
	else:
		gradient = not gradient
	_refresh_buttons()


func _set_effect(f: String) -> void:
	var old := effect
	effect = f
	if used > eff_budget():
		effect = old
		_warn("Trop d'encre utilisée pour cet effet !")
	_refresh_buttons()
	_changed()


const INK_HINT := "Seuls les contours comptent dans l'encre utilisée"


## La ligne d'aide sous la toile : ce que fait l'effet choisi sur CE dessin (en doré), sinon le
## rappel sur l'encre. (Il n'y a de place nulle part ailleurs sur la toile.)
func _hint() -> void:
	if warn_label == null:
		return
	if effect != "":
		warn_label.text = Stats.effect_short(effect, String(cfg.kind))
		warn_label.add_theme_color_override("font_color", Pal.ACCENT)
	else:
		warn_label.text = INK_HINT
		warn_label.add_theme_color_override("font_color", Pal.DIM)


func _warn(t: String) -> void:
	warn_label.text = t
	warn_label.add_theme_color_override("font_color", Pal.BAD)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(_hint)


func _unhandled_input(ev: InputEvent) -> void:
	if overlay:
		return
	# Défaire / refaire (maintenir la touche répète)
	if ev is InputEventKey and ev.pressed and ev.ctrl_pressed:
		if ev.keycode == KEY_Z and not ev.shift_pressed:
			_sel_commit()
			_undo()
			return
		if ev.keycode == KEY_Y or (ev.keycode == KEY_Z and ev.shift_pressed):
			_redo()
			return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		if (k == KEY_DELETE or k == KEY_BACKSPACE) and sel_state == "floating":
			_sel_delete()
			return
		if sel_state == "floating" and (k == KEY_R or k == KEY_F):
			_sel_transform("rot" if k == KEY_R else "flip")   # (pendant une sélection, R et F la transforment)
			return
		for t in TOOLS:
			if k == t[3] and tool_btns.has(t[0]):
				_set_tool(t[0])
				return
		if k == KEY_M and toggle_btns.has("mirror"):
			_toggle("mirror")
		elif k == KEY_H and toggle_btns.has("mirror_h"):
			_toggle("mirror_h")
		elif k == KEY_G and toggle_btns.has("gradient"):
			_toggle("gradient")
		elif k == KEY_C:
			_toggle_outline()
		elif k == KEY_V and body_view:
			_toggle_body_view()


# ------------------------------------------------------------------ Dessin

func eff_budget() -> int:
	if effect == "":
		return budget
	return budget - ceili(budget * Stats.EFFECT_COST)


func _in(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height()


func _cur_tool() -> String:
	return "eraser" if rmb else tool


func begin_stroke(cell: Vector2i, right: bool) -> void:
	if tool == "select":
		if right:
			_sel_commit()   # clic droit : poser la sélection
		else:
			_sel_press(cell)
		return
	_push_undo()
	drawing = true
	rmb = right
	stroke_len = 0.0
	stroke_pts.clear()
	last_cell = cell
	start_cell = cell
	match _cur_tool():
		"brush", "eraser":
			_stamp(cell)
			_regrad()
		"fill":
			_flood(cell)
			drawing = false
		_:
			shape_base = img.duplicate()
			_shape(cell)
	_changed()


func continue_stroke(cell: Vector2i) -> void:
	if not drawing or cell == last_cell:
		return
	if tool == "select":
		_sel_move(cell)
		last_cell = cell
		return
	match _cur_tool():
		"brush", "eraser":
			var pts := _line_cells(last_cell, cell)
			for i in range(1, pts.size()):
				stroke_len += 1.0
				_stamp(pts[i])
			_regrad()
		_:
			_shape(cell)
	last_cell = cell
	_changed()


func end_stroke() -> void:
	if not drawing:
		return
	if tool == "select":
		_sel_release()
		return
	drawing = false
	shape_base = null
	Sfx.play("paint")
	_changed()


## Couleur à poser. Dégradé : du début à la fin du trait (formes : sur tout le contour ;
## pinceau : le trait entier est recoloré à mesure qu'il s'allonge, voir _regrad).
func _paint_color() -> Color:
	if not gradient:
		return col_a
	if tool in ["brush", "eraser"]:
		return col_a
	return _grad_at(stroke_len / maxf(1.0, stroke_total - 1.0))


func _grad_at(t: float) -> Color:
	return col_a.lerp(col_b, roundf(clampf(t, 0.0, 1.0) * 4.0) / 4.0)


## Dégradé au pinceau : recolore tout le trait en cours, du début (couleur de début) au bout
## (couleur de fin). Recolorier ne coûte pas d'encre.
func _regrad() -> void:
	if not gradient or _cur_tool() != "brush" or stroke_pts.is_empty():
		return
	var n := stroke_pts.size()
	for i in n:
		var p: Vector2i = stroke_pts[i]
		if img.get_pixelv(p).a > 0.5:
			img.set_pixelv(p, _grad_at(float(i) / maxf(1.0, n - 1.0)))


func _stamp(c: Vector2i) -> void:
	@warning_ignore("integer_division")
	var off := -(brush - 1) / 2
	for dy in brush:
		for dx in brush:
			var p := Vector2i(c.x + off + dx, c.y + off + dy)
			_plot(p)
			var fx := img.get_width() - 1 - p.x
			var fy := img.get_height() - 1 - p.y
			if mirror:
				_plot(Vector2i(fx, p.y))
			if mirror_h:
				_plot(Vector2i(p.x, fy))
				if mirror:
					_plot(Vector2i(fx, fy))


## Coût local : nombre de pixels de contour parmi p et ses 4 voisins.
func _local_cost(p: Vector2i) -> int:
	var n := 0
	for q in [p, p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN]:
		if Analyzer.is_edge(img, q):
			n += 1
	return n


func _plot(p: Vector2i) -> void:
	if not _in(p):
		return
	var cur := img.get_pixelv(p)
	if _cur_tool() == "eraser":
		if cur.a > 0.5:
			var before := _local_cost(p)
			img.set_pixelv(p, Color(0, 0, 0, 0))
			used += _local_cost(p) - before
		return
	var col := _paint_color()
	if gradient and _cur_tool() == "brush" and not stroke_pts.has(p):
		stroke_pts.append(p)
	if cur.a > 0.5:
		img.set_pixelv(p, col)   # recolorier est gratuit
		return
	var before := _local_cost(p)
	img.set_pixelv(p, col)
	var delta := _local_cost(p) - before
	if used + delta > eff_budget():
		img.set_pixelv(p, Color(0, 0, 0, 0))
	else:
		used += delta


func _shape(end: Vector2i) -> void:
	if shape_base == null:
		return
	img.copy_from(shape_base)
	_recount()
	var cells: Array[Vector2i] = []
	match tool:
		"line":
			cells = _line_cells(start_cell, end)
		"rect":
			var x0 := mini(start_cell.x, end.x)
			var x1 := maxi(start_cell.x, end.x)
			var y0 := mini(start_cell.y, end.y)
			var y1 := maxi(start_cell.y, end.y)
			for x in range(x0, x1 + 1):
				cells.append(Vector2i(x, y0))
				cells.append(Vector2i(x, y1))
			for y in range(y0 + 1, y1):
				cells.append(Vector2i(x0, y))
				cells.append(Vector2i(x1, y))
		"ellipse":
			cells = _ellipse_cells(start_cell, end)
		"triangle":
			# pointe au milieu de la ligne de départ, base sur la ligne d'arrivée
			var apex := Vector2i((start_cell.x + end.x) / 2, start_cell.y)
			var b0 := Vector2i(start_cell.x, end.y)
			cells = _line_cells(apex, b0) + _line_cells(b0, end) + _line_cells(end, apex)
	stroke_total = cells.size()
	for i in cells.size():
		stroke_len = float(i)
		_stamp(cells[i])


func _line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while true:
		out.append(p)
		if p == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return out


func _ellipse_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := (Vector2(a) + Vector2(b)) / 2.0
	var rx := absf(b.x - a.x) / 2.0
	var ry := absf(b.y - a.y) / 2.0
	var n := int((rx + ry) * 4.0) + 8
	var seen := {}
	for i in n:
		var ang := TAU * i / n
		var p := Vector2i(roundi(c.x + cos(ang) * rx), roundi(c.y + sin(ang) * ry))
		if not seen.has(p):
			seen[p] = true
			out.append(p)
	return out


func _flood(start: Vector2i) -> void:
	if not _in(start):
		return
	var target := img.get_pixelv(start)
	var col := col_a
	var target_empty := target.a < 0.5
	if not target_empty and target.is_equal_approx(col):
		return
	var backup := img.duplicate()
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var i := 0
	while i < queue.size():
		var p := queue[i]
		i += 1
		img.set_pixelv(p, col)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var q: Vector2i = p + d
			if not _in(q) or seen.has(q):
				continue
			var qc := img.get_pixelv(q)
			var same := (qc.a < 0.5) if target_empty else (qc.a > 0.5 and qc.is_equal_approx(target))
			if same:
				seen[q] = true
				queue.append(q)
	# Remplir l'intérieur est gratuit, mais une zone ouverte crée de nouveaux contours
	var cost := Analyzer.ink_cost(img)
	if cost > eff_budget():
		img.copy_from(backup)
		_warn("Pas assez d'encre : la zone n'est pas fermée ?")
	else:
		if cost < used:
			# remplir un trou fait disparaître son contour intérieur : on le dit, sinon ça surprend
			_warn("Contour intérieur rempli : −%d encre" % (used - cost))
		used = cost


func _recount() -> void:
	used = Analyzer.ink_cost(img)


func _push_undo() -> void:
	undo_stack.append(img.duplicate())
	if undo_stack.size() > 100:
		undo_stack.pop_front()
	redo_stack.clear()


func _undo() -> void:
	_sel_commit()
	if undo_stack.is_empty():
		_warn("Rien à défaire")
		return
	redo_stack.append(img.duplicate())
	img.copy_from(undo_stack.pop_back())
	_recount()
	_changed()


func _redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(img.duplicate())
	img.copy_from(redo_stack.pop_back())
	_recount()
	_changed()


func _clear() -> void:
	_sel_commit()
	_push_undo()
	img.fill(Color(0, 0, 0, 0))
	used = 0
	_changed()


func _blit_centered(src: Image) -> void:
	img.fill(Color(0, 0, 0, 0))
	var ss := src.get_size()
	var ds := img.get_size()
	@warning_ignore("integer_division")
	var off := Vector2i((ds.x - ss.x) / 2, (ds.y - ss.y) / 2)
	img.blit_rect(src, Rect2i(Vector2i.ZERO, ss), off)


func _changed() -> void:
	tex.update(img)
	if preview_tex:
		preview_tex.update(Gfx.padded(img))
		preview_mat.set_shader_parameter("effect", Gfx.FX_ID.get(effect, 0))
	view.refresh_edges()
	ink_bar.queue_redraw()
	stats_label.set_text(Stats.preview(cfg, img, effect))
	if color_box:
		# arme (et ses balles) : 30 % du dessin ; le reste : 25 %
		var need := 0.3 if cfg.kind in ["melee", "ranged", "bullet"] else 0.25
		var frac: Array = Analyzer.analyze(img).frac
		# arme à distance : la couleur finale mélange l'arme et ses balles (au nombre de pixels)
		if cfg.kind == "bullet" and cfg.has("weapon_a"):
			frac = Stats.mix_frac(cfg.weapon_a, Analyzer.analyze(img))
		elif cfg.kind == "ranged" and cfg.has("bullet_a"):
			frac = Stats.mix_frac(Analyzer.analyze(img), cfg.bullet_a)
		main_color = Pal.color_of(frac, need)
		main_color_label.text = "Couleur\n" + (Pal.color_name(main_color) if main_color != 0 else "aucune")
		main_color_label.add_theme_color_override("font_color", Pal.DIM if main_color == 0 else (Pal.SHADES[0][2] if main_color == Pal.NOIR else Pal.SHADES[main_color][2]))
		color_ring.queue_redraw()


## Entoure la couleur principale du dessin sur le petit cercle (mêmes positions que docs/cercle_elements.py).
func _draw_color_ring() -> void:
	if main_color == 0:
		return
	var pos := Vector2.ZERO
	var rad := 7.0
	var k := Pal.CYCLE.find(main_color)
	if k >= 0:
		var a := -PI / 2.0 + k * TAU / 5.0
		pos = Vector2(42, 40) + Vector2(cos(a), sin(a)) * 31.0
		pos = pos.round()
	elif main_color == Pal.LUMIERE:
		pos = Vector2(25, 88)
		rad = 6.0
	else:
		pos = Vector2(59, 88)
		rad = 6.0
	color_ring.draw_arc(pos + Vector2(0.5, 0.5), rad + 3.0, 0.0, TAU, 24, Pal.ACCENT, 1.0)
	color_ring.draw_arc(pos + Vector2(0.5, 0.5), rad + 4.0, 0.0, TAU, 24, Color(Pal.ACCENT, 0.5), 1.0)


# ------------------------------------------------------------------ Sélection (rectangle)

func _sel_rect() -> Rect2i:
	if sel_state == "making":
		return Rect2i(Vector2i(mini(sel_a.x, sel_b.x), mini(sel_a.y, sel_b.y)), (sel_a - sel_b).abs() + Vector2i.ONE)
	if sel_img == null:
		return Rect2i()
	return Rect2i(sel_pos, sel_img.get_size())


func _sel_press(cell: Vector2i) -> void:
	drawing = true
	last_cell = cell
	if sel_state == "floating" and _sel_rect().has_point(cell):
		sel_state = "drag"   # on attrape la zone pour la déplacer
		drag_from = cell
		drag_pos0 = sel_pos
		return
	_sel_commit()
	sel_state = "making"
	sel_a = cell.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
	sel_b = sel_a
	view.queue_redraw()


func _sel_move(cell: Vector2i) -> void:
	match sel_state:
		"making":
			sel_b = cell.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)
			view.queue_redraw()
		"drag":
			sel_pos = drag_pos0 + (cell - drag_from)
			_sel_compose()


## Le dessin = le fond + la zone sélectionnée à sa position (ce qui sort de la toile est coupé).
func _sel_compose() -> void:
	img.copy_from(sel_base)
	img.blit_rect_mask(sel_img, sel_img, Rect2i(Vector2i.ZERO, sel_img.get_size()), sel_pos)
	_recount()
	_changed()


func _sel_release() -> void:
	drawing = false
	match sel_state:
		"making":
			var r := _sel_rect().intersection(Rect2i(Vector2i.ZERO, img.get_size()))
			var region := img.get_region(r) if r.has_area() else null
			if region == null or region.is_invisible():
				sel_state = ""   # rien dedans : pas de sélection
				view.queue_redraw()
				return
			_push_undo()
			sel_img = region
			sel_base = img.duplicate()
			sel_base.fill_rect(r, Color(0, 0, 0, 0))
			sel_pos = r.position
			sel_state = "floating"
			sel_bar.visible = true
			_warn("R : tourner · F : miroir · Suppr : effacer")
		"drag":
			sel_state = "floating"
			if used > eff_budget():
				sel_pos = drag_pos0   # pas assez d'encre à cet endroit : on revient
				_sel_compose()
				_warn("Pas assez d'encre pour la poser là")
			else:
				Sfx.play("paint")
	view.queue_redraw()


## Sélection levée : quart de tour (sur son centre) ou miroir. Si l'encre ne suffit plus, on annule.
func _sel_transform(what: String) -> void:
	if sel_state != "floating" or sel_img == null:
		_warn("Fais d'abord une sélection (outil S)")
		return
	var old_img := sel_img.duplicate()
	var old_pos := sel_pos
	var c := Vector2(sel_pos) + Vector2(sel_img.get_size()) / 2.0
	if what == "rot":
		sel_img.rotate_90(CLOCKWISE)
		sel_pos = Vector2i((c - Vector2(sel_img.get_size()) / 2.0).round())
	else:
		sel_img.flip_x()
	_sel_compose()
	if used > eff_budget():
		sel_img = old_img
		sel_pos = old_pos
		_sel_compose()
		_warn("Pas assez d'encre pour la tourner là")
		return
	Sfx.play("click")
	view.queue_redraw()


## Pose la sélection (elle fait déjà partie du dessin) et arrête de la déplacer.
func _sel_commit() -> void:
	if sel_state == "":
		return
	sel_state = ""
	sel_img = null
	sel_base = null
	drawing = false
	if sel_bar:
		sel_bar.visible = false
	if view:
		view.queue_redraw()


## Suppr : la zone sélectionnée disparaît (son encre revient).
func _sel_delete() -> void:
	img.copy_from(sel_base)
	_sel_commit()
	_recount()
	_changed()
	Sfx.play("paint")


func _validate() -> void:
	_sel_commit()
	if Analyzer.count_pixels(img) < int(cfg.get("min", 1)):
		_warn("Dessine un peu plus !")
		return
	if cfg.has("fit"):
		var u := img.get_used_rect().size
		if u.x > cfg.fit.x or u.y > cfg.fit.y:
			_warn("Trop grand : ton dessin doit tenir dans le cadre rouge (%d×%d) !" % [cfg.fit.x, cfg.fit.y])
			return
	if used > eff_budget():
		_warn("Trop d'encre !")
		return
	if used < int(cfg.get("min_ink", 0)):
		_warn("Encore %d d'encre à utiliser (95%% minimum) !" % (int(cfg.min_ink) - used))
		return
	var lc := Meta.locked_colors(img)
	if not lc.is_empty():
		_warn("Couleurs pas encore débloquées : " + ", ".join(lc) + " !")
		return
	var ci := DrawCfg.color_issue(cfg, img)
	if ci != "":
		_warn(ci + " !")
		return
	if cfg.has("fit"):
		# il tient dans le cadre : on le remet sur une toile de la vraie taille, centré
		var t := Analyzer.trim(img)
		var fit_img := Image.create_empty(cfg.fit.x, cfg.fit.y, false, Image.FORMAT_RGBA8)
		@warning_ignore("integer_division")
		fit_img.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), (Vector2i(cfg.fit) - t.get_size()) / 2)
		img = fit_img
	Meta.add_to_gallery(cfg.get("gallery", cfg.kind), img, effect)
	Sfx.play("buy")
	done.emit({"image": img, "effect": effect, "outline": outline})


# ------------------------------------------------------------------ Galerie & hasard

func _open_gallery() -> void:
	var entries := Meta.gallery(cfg.gallery)
	overlay = UI.panel(Color(Pal.BG, 0.97), Pal.ACCENT)
	UI.put(self, overlay, Vector2(20, 20), Vector2(600, 320))
	UI.put(overlay, UI.label("GALERIE — réutilise un ancien dessin", 10, Pal.ACCENT), Vector2(10, 8))
	UI.put(overlay, UI.hotkey(UI.button("Fermer", _close_gallery), [KEY_ESCAPE]), Vector2(530, 6), Vector2(60, 16))
	var sc := ScrollContainer.new()
	UI.put(overlay, sc, Vector2(10, 30), Vector2(580, 280))
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(grid)
	var s: Vector2i = cfg.size
	var shown := 0
	for e in entries:
		var ok: bool = int(e.w) <= s.x and int(e.h) <= s.y
		var gi := Meta.gallery_image(e)
		if gi == null:
			continue
		var cost := Analyzer.ink_cost(gi)
		var fits: bool = cost <= (budget if e.get("effect", "") == "" else budget - ceili(budget * Stats.EFFECT_COST))
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		b.focus_mode = Control.FOCUS_NONE
		var th := UI.thumb(gi, Vector2(44, 44))
		th.position = Vector2(4, 4)
		b.add_child(th)
		# Pas utilisable tel quel : pâli, mais on peut quand même le charger et le retoucher
		# (la validation refuse tant que ce n'est pas réglé)
		var issue := DrawCfg.gallery_block(cfg, gi)
		if issue == "" and not (ok and fits):
			issue = "Trop d'encre (%d)" % cost
		if issue == "":
			issue = DrawCfg.color_issue(cfg, gi)
		b.tooltip_text = "Encre : %d" % cost
		var too_big := gi.get_used_rect().size.x > s.x or gi.get_used_rect().size.y > s.y
		if too_big:
			# (ici il serait coupé : on le prend depuis l'écran de choix, qui ouvre une toile agrandie)
			th.modulate = Color(1, 1, 1, 0.3)
			b.tooltip_text = "Trop grand pour cette toile\n(choisis-le avant de dessiner, puis « Modifier »)"
		elif issue != "":
			th.modulate = Color(1, 1, 1, 0.3)
			b.tooltip_text = "%s\n(tu peux le charger et le retoucher)" % issue
		if not too_big:
			var entry: Dictionary = e
			b.pressed.connect(func(): _load_gallery(entry, gi))
		if cfg.has("need_el"):
			var ic := BestiaryPrompt._el_icon(int(Analyzer.analyze(gi).dominant), 13)
			ic.position = Vector2(37, 2)
			b.add_child(ic)
		grid.add_child(b)
		shown += 1
	if shown == 0:
		UI.put(overlay, UI.label("Rien pour l'instant : tes dessins validés arriveront ici.", 10, Pal.DIM), Vector2(10, 40))


func _load_gallery(entry: Dictionary, gi: Image) -> void:
	_push_undo()
	_blit_centered(gi)
	var fx: String = entry.get("effect", "")
	effect = fx if fx in Meta.effects() else ""
	outline = entry.get("outline", false)
	preview_mat.set_shader_parameter("outline", outline)
	_recount()
	_close_gallery()
	_refresh_buttons()
	_changed()


func _close_gallery() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


## Génère un petit monstre symétrique au hasard (pour aller vite sur les ennemis).
func _random_monster() -> void:
	_push_undo()
	var k := 1.0
	for attempt in 6:
		_generate_monster(k)
		_recount()
		if used <= eff_budget():
			break
		k *= 0.8
	_scribble_to(int(cfg.get("min_ink", 0)))
	_changed()


## Ajoute des gribouillis symétriques jusqu'à atteindre `target` d'encre (boss).
func _scribble_to(target: int) -> void:
	if used >= target:
		return
	var saved := [tool, mirror, gradient, rmb, col_a]
	tool = "brush"
	mirror = true
	gradient = false
	rmb = false
	var w := img.get_width()
	var h := img.get_height()
	var els := Meta.elements()
	for walk in 600:
		if used >= target:
			break
		col_a = Pal.SHADES[els.pick_random()][randi() % 2]
		var p := Vector2i(randi_range(1, w / 2), randi_range(1, h - 2))
		var dir := Vector2i([-1, 0, 1].pick_random(), [-1, 0, 1].pick_random())
		for step in randi_range(4, 14):
			if used >= target:
				break
			_stamp(p)
			if randf() < 0.3:
				dir = Vector2i([-1, 0, 1].pick_random(), [-1, 0, 1].pick_random())
			p = (p + dir).clamp(Vector2i.ZERO, Vector2i(w - 1, h - 1))
	tool = saved[0]
	mirror = saved[1]
	gradient = saved[2]
	rmb = saved[3]
	col_a = saved[4]


func _generate_monster(k: float) -> void:
	img.fill(Color(0, 0, 0, 0))
	var w := img.get_width()
	var h := img.get_height()
	var els := Meta.elements()
	var e: int = els.pick_random()
	var dark: Color = Pal.SHADES[e][0]
	var mid: Color = Pal.SHADES[e][1]
	var cx := w / 2.0
	var cy := h / 2.0 + randf_range(-1, 2)
	var rx := w * randf_range(0.22, 0.4) * k
	var ry := h * randf_range(0.2, 0.36) * k
	for y in h:
		for x in int(ceil(cx)):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0 + randf_range(-0.25, 0.25):
				img.set_pixel(x, y, mid)
				img.set_pixel(w - 1 - x, y, mid)
	# Pattes / cornes
	for i in randi_range(1, 3):
		var x := randi_range(1, maxi(1, int(cx) - 1))
		var y0 := int(cy + ry * (1 if randf() < 0.6 else -1))
		var dir := 1 if y0 > cy else -1
		for j in randi_range(2, int(h * 0.2 * k) + 2):
			for q in [Vector2i(x, y0 + j * dir), Vector2i(w - 1 - x, y0 + j * dir)]:
				if _in(q):
					img.set_pixelv(q, dark)
	# Contour sombre
	var copy := img.duplicate()
	for y in h:
		for x in w:
			if Analyzer.is_edge(copy, Vector2i(x, y)):
				img.set_pixel(x, y, dark)
	# Yeux (des trous dans l'encre)
	var ey := int(cy - ry * 0.25)
	var ex := int(cx - rx * randf_range(0.3, 0.55))
	for q in [Vector2i(ex, ey), Vector2i(w - 1 - ex, ey)]:
		if _in(q) and img.get_pixelv(q).a > 0.5:
			img.set_pixelv(q, Color(0, 0, 0, 0))
