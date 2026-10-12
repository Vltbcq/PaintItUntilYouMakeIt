class_name CanvasView
extends Control
## La toile agrandie sur laquelle on dessine. Transmet la souris au DrawScreen.

var screen: DrawScreen
var px := 8
var hover := Vector2i(-1, -1)
var edges := PackedVector2Array()
var edge_light := PackedByteArray()   # 1 = pixel clair (blanc, jaune pâle...) : point foncé   # pixels de contour (ceux qui coûtent de l'encre)
var pulse_t := 0.0
# Zoom (molette, vers le curseur) de ×1 à ×4 ; clic molette (ou Espace) maintenu : déplacer la vue ;
# double-clic molette : toute la toile.
const ZOOMS := [1.0, 1.5, 2.0, 3.0, 4.0]
var zoom_i := 0
var panning := false


func _init(s: DrawScreen, scale_px: int) -> void:
	screen = s
	px = scale_px
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	mouse_exited.connect(func():
		hover = Vector2i(-1, -1)
		queue_redraw())


func _enter_tree() -> void:
	Pad.canvas = self   # manette : la croix avance d'une case sur cette toile


func _exit_tree() -> void:
	if Pad.canvas == self:
		Pad.canvas = null


## Manette : depuis la position d'écran `at`, la case voisine dans la direction d (son centre, en
## coordonnées d'écran). null si le curseur n'est pas sur la toile.
func pad_step(at: Vector2, d: Vector2i):
	var xf := get_global_transform()
	var c := cell_at(xf.affine_inverse() * at)
	var s := screen.img.get_size()
	if c.x < 0 or c.y < 0 or c.x >= s.x or c.y >= s.y:
		return null
	c = (c + d).clamp(Vector2i.ZERO, s - Vector2i.ONE)
	return xf * ((Vector2(c) + Vector2(0.5, 0.5)) * px)


## Recalcule les pixels de contour (appelé à chaque modification du dessin).
func refresh_edges() -> void:
	edges.clear()
	edge_light.clear()
	var img := screen.img
	for y in img.get_height():
		for x in img.get_width():
			if Analyzer.is_edge(img, Vector2i(x, y)):
				edges.append(Vector2(x, y))
				edge_light.append(1 if img.get_pixel(x, y).get_luminance() > 0.6 else 0)
	queue_redraw()


func _process(delta: float) -> void:
	# les points des contours pulsent doucement (on redessine ~20 fois par seconde)
	pulse_t += delta
	if edge_style == "dots" and not edges.is_empty() and int(pulse_t * 20.0) != int((pulse_t - delta) * 20.0):
		queue_redraw()


func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / px), floori(p.y / px))


## Zoome d'un cran (dir = +1 / -1) en gardant sous la souris le même point de la toile.
func zoom_step(dir: int, at: Vector2) -> void:
	var ni := clampi(zoom_i + dir, 0, ZOOMS.size() - 1)
	if ni == zoom_i:
		return
	var old: float = ZOOMS[zoom_i]
	zoom_i = ni
	var z: float = ZOOMS[zoom_i]
	var anchor := position + at * old            # le point sous la souris, dans la fenêtre
	scale = Vector2(z, z)
	position = anchor - at * z
	_clamp_view()
	queue_redraw()


func reset_zoom() -> void:
	zoom_i = 0
	scale = Vector2.ONE
	position = Vector2.ZERO
	queue_redraw()


## La toile couvre toujours toute la fenêtre (on ne peut pas la faire sortir du cadre).
func _clamp_view() -> void:
	var z: float = ZOOMS[zoom_i]
	position.x = clampf(position.x, size.x - size.x * z, 0.0)
	position.y = clampf(position.y, size.y - size.y * z, 0.0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_step(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1, mb.position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.double_click:
				reset_zoom()
			panning = mb.pressed
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE) and zoom_i > 0:
			panning = mb.pressed   # Espace + clic : déplacer la vue (au lieu de dessiner)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				screen.begin_stroke(cell_at(mb.position), mb.button_index == MOUSE_BUTTON_RIGHT)
			else:
				screen.end_stroke()
			accept_event()
	elif ev is InputEventMouseMotion:
		if panning:
			position += (ev as InputEventMouseMotion).relative * scale.x
			_clamp_view()
			accept_event()
			return
		var c := cell_at((ev as InputEventMouseMotion).position)
		if c != hover:
			hover = c
			if screen.drawing:
				screen.continue_stroke(c)
			queue_redraw()


func _draw() -> void:
	var s := screen.img.get_size()
	# Papier en damier très léger
	for y in s.y:
		for x in s.x:
			var c := Pal.PAPER if (x + y) % 2 == 0 else Pal.PAPER.darkened(0.04)
			draw_rect(Rect2(x * px, y * px, px, px), c)
	if screen.cfg.get("kind", "") in ["melee", "ranged"]:
		_weapon_guide()
	draw_texture_rect(screen.tex, Rect2(Vector2.ZERO, size), false)
	_draw_edges()
	if screen.cfg.has("fit"):
		# Dessin trop grand pour sa toile : le cadre rouge = la taille permise (au centre),
		# l'extérieur est voilé ; il faudra que tout le dessin tienne dans un cadre de cette taille
		var f: Vector2i = screen.cfg.fit
		@warning_ignore("integer_division")
		var fo := (s - f) / 2
		var fr := Rect2(Vector2(fo * px), Vector2(f * px))
		var veil := Color(Pal.INK, 0.25)
		draw_rect(Rect2(0, 0, size.x, fr.position.y), veil)
		draw_rect(Rect2(0, fr.end.y, size.x, size.y - fr.end.y), veil)
		draw_rect(Rect2(0, fr.position.y, fr.position.x, fr.size.y), veil)
		draw_rect(Rect2(fr.end.x, fr.position.y, size.x - fr.end.x, fr.size.y), veil)
		draw_rect(fr, Pal.BAD, false, 2.0)
	if screen.mirror:
		var mx := s.x * px / 2.0
		draw_line(Vector2(mx, 0), Vector2(mx, size.y), Color(Pal.BAD, 0.6), 1.0)
	if screen.mirror_h:
		var my := s.y * px / 2.0
		draw_line(Vector2(0, my), Vector2(size.x, my), Color(Pal.BAD, 0.6), 1.0)
	# Sélection : rectangle en pointillés
	if screen.sel_state != "":
		var r := screen._sel_rect()
		var rr := Rect2(Vector2(r.position * px), Vector2(r.size * px))
		_dashed(rr)
		return
	if screen.tool == "select":
		return
	if hover.x >= 0 and hover.y >= 0 and hover.x < s.x and hover.y < s.y:
		var b := screen.brush
		@warning_ignore("integer_division")
		var off := -(b - 1) / 2
		var r := Rect2((hover.x + off) * px, (hover.y + off) * px, b * px, b * px)
		draw_rect(r, Color(Pal.INK, 0.8), false, 1.0)
		draw_rect(r.grow(-1), Color(1, 1, 1, 0.6), false, 1.0)


## Contours qui coûtent de l'encre : un petit point clair qui pulse au centre de chaque pixel.
## Style d'affichage des bords (ce qui coûte de l'encre) : "line" (liseré fixe autour des formes),
## "line_gold", "line_tint" (liseré + bords légèrement teintés) ou "dots" (les points qui pulsent).
var edge_style := "dots"   # (les autres styles existent, pas encore choisis : voir tests/edgeshot)


func _draw_edges() -> void:
	if edge_style == "dots":
		_draw_edge_dots()
		return
	var img := screen.img
	var w := img.get_width()
	var h := img.get_height()
	var col := Color(1, 1, 1, 0.95)
	var shade := Color(Pal.INK, 0.55)
	var th := 1.0 if px < 6 else 2.0
	if edge_style == "line_gold":
		col = Pal.ACCENT
		shade = Color(Pal.INK, 0.7)
	for i in edges.size():
		var e := edges[i]
		var x := int(e.x)
		var y := int(e.y)
		var o := Vector2(e.x * px, e.y * px)
		if edge_style == "line_tint":
			draw_rect(Rect2(o, Vector2(px, px)), Color(1, 1, 1, 0.22))
		# un trait sur chaque côté du pixel qui touche le vide : le liseré suit le contour des formes
		for side in 4:
			var n: Vector2i = Vector2i(x, y) + [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][side]
			if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and img.get_pixelv(n).a > 0.5:
				continue
			var r: Rect2
			match side:
				0:
					r = Rect2(o.x, o.y, th, px)
				1:
					r = Rect2(o.x + px - th, o.y, th, px)
				2:
					r = Rect2(o.x, o.y, px, th)
				_:
					r = Rect2(o.x, o.y + px - th, px, th)
			draw_rect(Rect2(r.position + Vector2(1, 1), r.size), shade)
			draw_rect(r, col)


## Ancien affichage : un point clair qui pulse au centre de chaque pixel de contour.
func _draw_edge_dots() -> void:
	var a := 0.45 + 0.35 * sin(pulse_t * 4.0)
	var d := maxf(1.0 if px < 4 else 2.0, roundf(px * 0.34))
	var o := (px - d) / 2.0
	for i in edges.size():
		var e := edges[i]
		var r := Rect2(e.x * px + o, e.y * px + o, d, d)
		# point blanc sur les couleurs foncées, point d'encre sur les couleurs claires
		var light := edge_light[i] == 1
		if px >= 6:
			draw_rect(r.grow(1.0), Color(Color.WHITE if light else Pal.INK, a * 0.6))
		draw_rect(r, Color(Pal.INK if light else Color.WHITE, a + (0.2 if light else 0.0)))


func _dashed(r: Rect2) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 4.0)
		for k in n:
			var p0: Vector2 = a.lerp(b, float(k) / n)
			var p1: Vector2 = a.lerp(b, float(k + 1) / n)
			draw_line(p0, p1, Pal.INK if k % 2 == 0 else Color.WHITE, 2.0)


## Repère des armes (sous le dessin) : le manche à gauche, la pointe / le canon à droite.
## C'est le côté droit qui vise l'ennemi et d'où partent les tirs.
func _weapon_guide() -> void:
	var y := size.y / 2.0
	var col := Color(Pal.INK, 0.13)
	var x0 := size.x * 0.12
	var x1 := size.x * 0.88
	draw_line(Vector2(x0, y), Vector2(x1, y), col, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(x1 + 10, y), Vector2(x1 - 8, y - 10), Vector2(x1 - 8, y + 10)]), col)
	var tip := Loc.t("CANON") if screen.cfg.kind == "ranged" else Loc.t("POINTE")
	draw_string(UI.font, Vector2(6, y - 8), Loc.t("CROSSE") if screen.cfg.kind == "ranged" else Loc.t("MANCHE"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Color(Pal.INK, 0.3))
	draw_string(UI.font, Vector2(0, y - 8), tip + " →", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, UI.fs(10), Color(Pal.INK, 0.3))
