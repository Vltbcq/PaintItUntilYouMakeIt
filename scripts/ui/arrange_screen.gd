class_name ArrangeScreen
extends Control
## Range tes armes sur ton perso : pose la nouvelle (s'il y en a une), et clique sur
## n'importe quelle arme déjà posée pour la reprendre, la déplacer ou la tourner.
## done({"new": {anchor, rot, flip} ou null, "moves": [{anchor, rot, flip} pour chaque arme existante]})

signal done(result)

const MARGIN := 34      # grande zone autour du perso pour placer les armes

var new_type := ""
var new_rar := 0
var base: Image
var base_tex: ImageTexture
var px := 3
var view: Control
var entries: Array = []     # {src, img, tex, tl (Vector2i), rot, flip, outline, placed, idx}
var held := -1              # entrée tenue par la souris (-1 = aucune)
var sel := -1               # dernière entrée touchée (pour Tourner / Miroir)
var cc := Vector2.ZERO      # centre du perso dans l'image composite agrandie
var ok_btn: Button
var info: Label


func _init(type := "", rar := 0) -> void:
	new_type = type
	new_rar = rar


func _ready() -> void:
	add_to_group("pad_turn")   # manette : ici LB tourne (R) et RB retourne en miroir (M)
	set_anchors_preset(PRESET_FULL_RECT)
	UI.fill_bg(self)
	var comp := Run.build_player_image(false)   # sans les amulettes : elles se déplacent aussi
	base = Image.create_empty(comp.get_width() + MARGIN * 2, comp.get_height() + MARGIN * 2, false, Image.FORMAT_RGBA8)
	base.blit_rect(comp, Rect2i(Vector2i.ZERO, comp.get_size()), Vector2i(MARGIN, MARGIN))
	base_tex = ImageTexture.create_from_image(Gfx.baked_outline(base) if Run.char_outline else base)
	cc = Run.char_center() + Vector2(MARGIN, MARGIN)

	for i in Run.weapons.size():
		var w: Dictionary = Run.weapons[i]
		var e := _entry(w.type, w.rar, int(w.get("rot", 0)), bool(w.get("flip", false)), i)
		e.tl = Vector2i((cc + w.anchor - Vector2(e.img.get_size()) / 2.0).round())
		e.placed = true
		entries.append(e)
	# Amulettes : déplaçables (et orientables) comme les armes
	for i in Run.amulets.size():
		var am: Dictionary = Run.amulets[i]
		var e := {"kind": "amulet", "id": am.id, "src": am.image, "rot": 0, "flip": false,
			"outline": am.get("outline", false), "idx": i, "tl": Vector2i(am.pos) + Vector2i(MARGIN, MARGIN), "placed": true}
		_rebuild(e)
		entries.append(e)
	if new_type != "":
		var e := _entry(new_type, new_rar, 0, false, -1)
		e.placed = false
		entries.append(e)
		held = entries.size() - 1
		sel = held

	var title: String = Loc.t("Pose ton arme : %s") % WeaponDB.get_def(new_type).name if new_type != "" else Loc.t("Range tes armes et amulettes")
	UI.put(self, UI.label(title, 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(640, 24))
	UI.put(self, UI.label(Loc.t("Clique une arme ou une amulette pour la prendre, reclique pour la poser.  R : tourner · M : miroir (pose au repos)"),
		10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 30), Vector2(640, 14))

	var s := base.get_size()
	px = maxi(2, mini(300 / s.x, 280 / s.y))
	view = Control.new()
	view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	view.draw.connect(_draw_view)
	view.gui_input.connect(_input_view)
	var vs := Vector2(s * px)
	UI.put(self, view, Vector2(36 + (310 - vs.x) / 2.0, 66 + (270 - vs.y) / 2.0), vs)   # (sous les 2 lignes d'aide)

	info = UI.label("", 10, Pal.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.put(self, info, Vector2(370, 60), Vector2(260, 120))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	UI.put(self, row, Vector2(370, 190), Vector2(260, 18))
	row.add_child(UI.button(Loc.t("Tourner (R)"), _rotate))
	row.add_child(UI.button(Loc.t("Miroir (M)"), _mirror))
	ok_btn = UI.hotkey(UI.button(Loc.t("VALIDER →"), _validate), [KEY_ENTER, KEY_KP_ENTER])
	UI.put(self, ok_btn, Vector2(496, 330), Vector2(136, 18))
	_update()


func _entry(type: String, rar: int, rot: int, flip: bool, idx: int) -> Dictionary:
	var art: Dictionary = Run.weapon_art[Run.art_key(type, rar)]
	var e := {"kind": "weapon", "type": type, "src": Analyzer.trim(art.image), "rot": rot, "flip": flip,
		"outline": art.get("outline", false), "idx": idx, "tl": Vector2i(-100, -100)}
	_rebuild(e)
	return e


func _rebuild(e: Dictionary) -> void:
	e.img = Gfx.transformed(e.src, e.rot, e.flip)
	e.tex = ImageTexture.create_from_image(Gfx.baked_outline(e.img) if e.outline else e.img)


func _clamp_tl(e: Dictionary, tl: Vector2i) -> Vector2i:
	var sz: Vector2i = e.img.get_size()
	if e.get("kind", "weapon") == "amulet":
		# une amulette reste sur l'image du perso (sa marge comprise)
		var lo := Vector2i(MARGIN, MARGIN)
		var hi := base.get_size() - Vector2i(MARGIN, MARGIN) - sz
		return Vector2i(clampi(tl.x, lo.x, maxi(lo.x, hi.x)), clampi(tl.y, lo.y, maxi(lo.y, hi.y)))
	var s := base.get_size()
	return Vector2i(clampi(tl.x, 0, maxi(0, s.x - sz.x)), clampi(tl.y, 0, maxi(0, s.y - sz.y)))


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / px), floori(p.y / px))


func _input_view(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and held >= 0:
		var e: Dictionary = entries[held]
		@warning_ignore("integer_division")
		e.tl = _clamp_tl(e, _cell(ev.position) - Vector2i(e.img.get_width() / 2, e.img.get_height() / 2))
		view.queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if held >= 0:
			entries[held].placed = true
			held = -1
			Sfx.play("paint")
		else:
			var c := _cell(ev.position)
			for i in range(entries.size() - 1, -1, -1):
				var e: Dictionary = entries[i]
				if Rect2i(e.tl, e.img.get_size()).grow(1).has_point(c):
					held = i
					sel = i
					Sfx.play("click")
					break
		_update()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_R:
			_rotate()
		elif ev.keycode == KEY_M:
			_mirror()


func _transform(rotate: bool) -> void:
	if sel < 0:
		return
	var e: Dictionary = entries[sel]
	var center := Vector2(e.tl) + Vector2(e.img.get_size()) / 2.0
	if rotate:
		e.rot = (e.rot + 1) % 4
	else:
		e.flip = not e.flip
	_rebuild(e)
	if e.placed or held == sel:
		e.tl = _clamp_tl(e, Vector2i((center - Vector2(e.img.get_size()) / 2.0).round()))
	Sfx.play("click")
	_update()


func _rotate() -> void:
	_transform(true)


func _mirror() -> void:
	_transform(false)


func _all_placed() -> bool:
	if held >= 0:
		return false
	for e in entries:
		if not e.placed:
			return false
	return true


func _update() -> void:
	ok_btn.disabled = not _all_placed()
	var txt := ""
	if sel >= 0:
		var e: Dictionary = entries[sel]
		if e.get("kind", "weapon") == "amulet":
			var ad := AmuletDB.get_def(e.id)
			txt = Loc.t("%s (amulette)\n%s\n\n") % [ad.name, AmuletDB.describe(ad)]
		else:
			var def := WeaponDB.get_def(e.type)
			txt = "%s%s\n%s\n\n" % [def.name, Loc.t(" (nouvelle)") if e.idx < 0 else "", def.desc]
	txt += Loc.t("Chaque arme attaque l'ennemi le plus proche depuis l'endroit où elle est posée. C'est le côté droit du dessin qui vise.")
	info.text = txt
	view.queue_redraw()


func _validate() -> void:
	if not _all_placed():
		return
	Sfx.play("buy")
	var res := {"new": null, "moves": [], "amulet_moves": []}
	for e in entries:
		if e.get("kind", "weapon") == "amulet":
			res.amulet_moves.append({"pos": e.tl - Vector2i(MARGIN, MARGIN), "image": e.img})
			continue
		var center := Vector2(e.tl) + Vector2(e.img.get_size()) / 2.0
		var d := {"anchor": center - cc, "rot": e.rot, "flip": e.flip}
		if e.idx < 0:
			res.new = d
		else:
			res.moves.append(d)
	done.emit(res)


func _draw_view() -> void:
	var sz := view.size
	view.draw_rect(Rect2(Vector2(-2, -2), sz + Vector2(4, 4)), Pal.ACCENT)
	view.draw_rect(Rect2(Vector2.ZERO, sz), Pal.PAPER)
	var bo := 1.0 if Run.char_outline else 0.0
	view.draw_texture_rect(base_tex, Rect2(Vector2(-bo, -bo) * px, sz + Vector2(bo, bo) * 2.0 * px), false)
	for i in entries.size():
		var e: Dictionary = entries[i]
		if not e.placed and held != i:
			continue
		var o := 1.0 if e.outline else 0.0
		var rect := Rect2(Vector2(e.tl) * px, Vector2(e.img.get_size()) * px)
		view.draw_texture_rect(e.tex, rect.grow(o * px), false, Color(1, 1, 1, 0.75 if held == i else 1.0))
		if i == sel:
			view.draw_rect(rect.grow(o * px + 1.0), Pal.ACCENT, false, 1.0)
