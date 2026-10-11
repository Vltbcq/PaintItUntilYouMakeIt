class_name PlaceScreen
extends Control
## Pose une amulette ou une arme où tu veux sur ton perso.
## On peut tourner (R) et retourner en miroir (M) l'objet. Pour une amulette, la zone donne un bonus.
## Pour une arme, sa pointe (le côté droit du dessin après rotation) vise les ennemis.
## Amulette : une fois la nouvelle posée, on peut attraper et DÉCALER les amulettes déjà posées
## (elles peuvent se chevaucher). Tant qu'on tient la nouvelle, les anciennes sont pâlies et figées.
## done({"pos": Vector2i, "image": Image, "rot": int, "flip": bool, "moves": [{pos, image}...]}) pour une amulette,
## done({"anchor": Vector2, "rot": int, "flip": bool}) pour une arme (position relative au centre du perso).

signal done(result)

var mode := "amulet"
var item: Image
var def: Dictionary
var base: Image
var px := 5
var view: Control
var cell := Vector2i(-100, -100)   # coin haut-gauche de l'objet dans l'image composite
var placed := false
var zone_label: Label
var ok_btn: Button
var base_tex: ImageTexture
var item_tex: ImageTexture
var weapon_ghosts: Array = []       # [texture, centre composite, taille]
var rot := 0                        # quarts de tour (appliqués après le miroir)
var margin := 0                     # zone en plus autour du perso (armes : bien plus large)
var outline := false                 # l'objet posé a-t-il un contour noir ?
const WEAPON_MARGIN := 34
var flip := false
var olds: Array = []                # amulettes déjà posées : [{image, pos, tex, outline}]
var held := -1                      # ce qu'on tient : -1 la nouvelle, i une ancienne, -2 rien
var grab_off := Vector2i.ZERO       # où on a attrapé l'ancienne amulette


func _init(m: String, img: Image, d: Dictionary, with_outline := false) -> void:
	mode = m
	item = Analyzer.trim(img)
	def = d
	outline = with_outline


## Texture d'affichage : avec le contour noir s'il est coché (image agrandie d'1px de chaque côté).
func _disp_tex(img: Image, with_outline: bool) -> ImageTexture:
	return ImageTexture.create_from_image(Gfx.baked_outline(img) if with_outline else img)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	UI.fill_bg(self)
	base = Run.build_player_image(mode != "amulet")
	if mode == "amulet":
		for am in Run.amulets:
			var ao: bool = am.get("outline", false)
			olds.append({"image": am.image, "pos": am.pos, "tex": _disp_tex(am.image, ao), "outline": ao})
	if mode == "weapon":
		margin = WEAPON_MARGIN
		var big := Image.create_empty(base.get_width() + margin * 2, base.get_height() + margin * 2, false, Image.FORMAT_RGBA8)
		big.blit_rect(base, Rect2i(Vector2i.ZERO, base.get_size()), Vector2i(margin, margin))
		base = big
	base_tex = _disp_tex(base, Run.char_outline)
	item_tex = _disp_tex(item, outline)
	var cc := Run.char_center() + Vector2(margin, margin)
	for w in Run.weapons:
		var wi := Run.weapon_image(w)
		var wo: bool = Run.art_of(w).get("outline", false)
		weapon_ghosts.append([_disp_tex(wi, wo), cc + w.anchor, Vector2(wi.get_size()), wo])

	var what: String = {"amulet": Loc.t("ton amulette : %s"), "weapon": Loc.t("ton arme : %s"), "mark": Loc.t("ta marque : %s")}[mode] % def.name
	UI.put(self, UI.label(Loc.t("Pose ") + what, 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(640, 24))
	var hint := Loc.t("Clique pour poser (clic droit pour reprendre).  R : tourner · M : miroir")
	if mode == "amulet" and not olds.is_empty():
		hint = Loc.t("Clique pour poser · une fois posée, clique une ancienne amulette pour la décaler · R : tourner · M : miroir")
	UI.put(self, UI.label(hint, 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 32), Vector2(640, 14))

	var s := base.get_size()
	px = maxi(2, mini(290 / s.x, 280 / s.y))
	view = Control.new()
	view.mouse_default_cursor_shape = Control.CURSOR_CROSS
	view.clip_contents = true   # les armes posées loin ne débordent pas du cadre
	view.draw.connect(_draw_view)
	view.gui_input.connect(_view_input)
	var vs := Vector2(s * px)
	UI.put(self, view, Vector2(40 + (300 - vs.x) / 2.0, 56 + (280 - vs.y) / 2.0), vs)

	var y := 60.0
	if mode == "amulet":
		UI.put(self, UI.label(Loc.t("Pose-la où tu veux sur ton perso."), 10, Pal.TEXT), Vector2(370, y), Vector2(260, 14))
		UI.put(self, UI.label(Loc.t("EFFET"), 10, Pal.DIM), Vector2(370, y + 94))
		var am_a: Dictionary = Run.amulet_art[def.id].a
		var eff := UI.label(AmuletDB.describe(def, Stats.amulet_mag(am_a, def)), 10, Pal.TEXT)
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.put(self, eff, Vector2(370, y + 108), Vector2(260, 40))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		UI.put(self, row, Vector2(370, y + 156), Vector2(260, 18))
		row.add_child(UI.button(Loc.t("Tourner (R)"), _rotate))
		row.add_child(UI.button(Loc.t("Miroir (M)"), _mirror))
	elif mode == "mark":
		var info := UI.label(def.desc + Loc.t("\n\nPose ta marque où tu veux : elle décore ton perso sans le rendre plus gros ni plus lent."), 10, Pal.TEXT)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.put(self, info, Vector2(370, y), Vector2(260, 80))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		UI.put(self, row, Vector2(370, y + 90), Vector2(260, 18))
		row.add_child(UI.button(Loc.t("Tourner (R)"), _rotate))
		row.add_child(UI.button(Loc.t("Miroir (M)"), _mirror))
	else:
		var info := UI.label(def.desc + Loc.t("\n\nPlace-la sur une main, sur la tête, dans le dos... Elle attaque l'ennemi le plus proche depuis là où tu l'as posée.\n\nTourne-la pour choisir sa position au repos : c'est le côté droit du dessin qui vise."), 10, Pal.TEXT)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.put(self, info, Vector2(370, y), Vector2(260, 130))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		UI.put(self, row, Vector2(370, y + 140), Vector2(260, 18))
		row.add_child(UI.button(Loc.t("Tourner (R)"), _rotate))
		row.add_child(UI.button(Loc.t("Miroir (M)"), _mirror))
	ok_btn = UI.hotkey(UI.button(Loc.t("VALIDER →"), _validate), [KEY_ENTER, KEY_KP_ENTER])
	ok_btn.disabled = true
	UI.put(self, ok_btn, Vector2(496, 330), Vector2(136, 18))


func _validate() -> void:
	if not placed:
		return
	Sfx.play("buy")
	if mode != "weapon":
		done.emit({"pos": cell, "image": item, "rot": rot, "flip": flip,
			"moves": olds.map(func(o): return {"pos": o.pos, "image": o.image})})
	else:
		var center := Vector2(cell) + Vector2(item.get_size()) / 2.0
		done.emit({"anchor": center - Run.char_center() - Vector2(margin, margin), "rot": rot, "flip": flip})


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_R:
			_rotate()
		elif ev.keycode == KEY_M:
			_mirror()


func _rotate() -> void:
	var center := Vector2(cell) + Vector2(item.get_size()) / 2.0
	item.rotate_90(CLOCKWISE)
	rot = (rot + 1) % 4
	_after_transform(center)


func _mirror() -> void:
	var center := Vector2(cell) + Vector2(item.get_size()) / 2.0
	item.flip_x()
	# miroir après rotation = rotation inverse après miroir
	flip = not flip
	rot = (4 - rot) % 4
	_after_transform(center)


func _after_transform(center: Vector2) -> void:
	item_tex = _disp_tex(item, outline)
	if cell.x > -50:
		cell = _clamp(Vector2i((center - Vector2(item.get_size()) / 2.0).round()))
	Sfx.play("click")
	_update()


func _cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(floori(p.x / px), floori(p.y / px))
	@warning_ignore("integer_division")
	return c - Vector2i(item.get_width() / 2, item.get_height() / 2)


func _clamp(p: Vector2i) -> Vector2i:
	var s := base.get_size()
	return Vector2i(clampi(p.x, 0, maxi(0, s.x - item.get_width())), clampi(p.y, 0, maxi(0, s.y - item.get_height())))


## Amulette déjà posée sous ce point (la plus haute), ou -1.
func _old_at(c: Vector2i) -> int:
	for i in range(olds.size() - 1, -1, -1):
		if Rect2i(olds[i].pos, olds[i].image.get_size()).grow(1).has_point(c):
			return i
	return -1


func _view_input(ev: InputEvent) -> void:
	if mode == "amulet" and not olds.is_empty() and _amulet_input(ev):
		return
	if ev is InputEventMouseMotion and not placed:
		cell = _clamp(_cell_at(ev.position))
		_update()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		cell = _clamp(_cell_at(ev.position))
		placed = true
		ok_btn.disabled = false
		Sfx.play("paint")
		_update()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		placed = false
		ok_btn.disabled = true
		_update()


## Décaler les amulettes déjà posées. Retourne true si l'événement est traité ici.
func _amulet_input(ev: InputEvent) -> bool:
	var c := Vector2i(floori(ev.position.x / px), floori(ev.position.y / px))
	if held >= 0:
		var o: Dictionary = olds[held]
		var s := base.get_size()
		var isz: Vector2i = o.image.get_size()
		var np := c - grab_off
		np = Vector2i(clampi(np.x, 0, maxi(0, s.x - isz.x)), clampi(np.y, 0, maxi(0, s.y - isz.y)))
		o.pos = np
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			held = -2 if placed else -1   # posée ; si la nouvelle n'est pas encore posée, on la reprend
			Sfx.play("paint")
		view.queue_redraw()
		return ev is InputEventMouseMotion or ev is InputEventMouseButton
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# Tant que la nouvelle n'est pas posée, le clic la POSE (même par-dessus une ancienne) :
		# les anciennes ne s'attrapent qu'après (sinon on décalait celle du dessous par accident)
		if not placed:
			return false
		# la nouvelle (posée) passe devant : on l'attrape d'abord avec le comportement normal
		var on_new := placed and Rect2i(cell, item.get_size()).has_point(c)
		var i := _old_at(c)
		if i >= 0 and not on_new:
			held = i
			grab_off = c - olds[i].pos
			Sfx.play("click")
			view.queue_redraw()
			return true
	return false


func _update() -> void:
	if zone_label:
		zone_label.text = Loc.t("Zone : %s") % Run.zone_at(cell, item.get_size())
	view.queue_redraw()


func _draw_view() -> void:
	var sz := view.size
	view.draw_rect(Rect2(Vector2(-2, -2), sz + Vector2(4, 4)), Pal.ACCENT)
	view.draw_rect(Rect2(Vector2.ZERO, sz), Pal.PAPER)
	if mode == "amulet":
		var r: Rect2i = Run.char_a.rect
		var rr := Rect2(Vector2(r.position + Vector2i(Run.PAD, Run.PAD)) * px, Vector2(r.size) * px)
		view.draw_rect(rr, Color(Pal.BORDER, 0.12))
		view.draw_rect(rr, Color(Pal.BORDER, 0.5), false, 1.0)
		for t in [0.33, 0.7]:
			var yy: float = rr.position.y + rr.size.y * t
			view.draw_line(Vector2(rr.position.x, yy), Vector2(rr.end.x, yy), Color(Pal.BORDER, 0.4))
	var bo := 1.0 if Run.char_outline else 0.0
	view.draw_texture_rect(base_tex, Rect2(Vector2(-bo, -bo) * px, sz + Vector2(bo, bo) * 2.0 * px), false)
	for i in olds.size():
		var o: Dictionary = olds[i]
		var oo := 1.0 if o.outline else 0.0
		var orc := Rect2(Vector2(o.pos) * px, Vector2(o.image.get_size()) * px)
		# pendant qu'on tient la nouvelle, les anciennes pâlissent : on voit où on pose
		var fade := 0.4 if (mode == "amulet" and not placed and i != held) else 1.0
		view.draw_texture_rect(o.tex, orc.grow(oo * px), false, Color(1, 1, 1, fade))
		if i == held:
			view.draw_rect(orc.grow(oo * px + 1.0), Pal.ACCENT, false, 1.0)
	for g in weapon_ghosts:
		var go := 1.0 if g[3] else 0.0
		var gs: Vector2 = (g[2] + Vector2(go, go) * 2.0) * px
		view.draw_texture_rect(g[0], Rect2(g[1] * px - gs / 2.0, gs), false, Color(1, 1, 1, 0.85))
	if cell.x > -50:
		var a := 1.0 if placed else 0.75
		var io := 1.0 if outline else 0.0
		var rect := Rect2(Vector2(cell) * px, Vector2(item.get_size()) * px)
		view.draw_texture_rect(item_tex, rect.grow(io * px), false, Color(1, 1, 1, a))
		view.draw_rect(rect.grow(io * px + 1.0), Color(Pal.ACCENT, a), false, 1.0)
