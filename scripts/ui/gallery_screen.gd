class_name GalleryScreen
extends Control
## Tous tes dessins sauvegardés, réutilisables en partie. Onglet « Tout » ou par catégorie.
## Clique un dessin pour le voir en grand (et le supprimer si tu veux, avec confirmation).

signal done(result)

static var KINDS := [
	["all", "Tout"], ["character", "Persos"], ["melee", "Mêlée"], ["ranged", "Distance"], ["bullet", "Balles"],
	["amulet", "Amulettes"], ["familiar", "Familiers"], ["enemy", "Ennemis"], ["boss", "Boss"],
]

var scroll_mem := {}         # position de défilement de la grille, par onglet
var kind := "all"
var selected := {}          # entrée de galerie sélectionnée
var confirm: Control
var viewer: Control


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	confirm = null
	viewer = null
	UI.fill_bg(self)
	UI.put(self, UI.label(Loc.t("GALERIE"), 20, Pal.ACCENT), Vector2(12, 8))
	# Partage avec d'autres joueurs : un .zip de dessins
	var ib := UI.button(Loc.t("Importer…"), func():
		GalleryShare.pick_import(self, func(path: String):
			var s := GalleryShare.open_import(self, path)
			s.done.connect(func(ch): if ch: _build())))
	ib.tooltip_text = Loc.t("Ajouter des dessins reçus d'un ami (fichier .zip)")
	UI.put(self, ib, Vector2(456, 10), Vector2(84, 18))
	var eb := UI.button(Loc.t("Exporter…"), func():
		var s := GalleryShare.open_export(self)
		s.done.connect(func(_ch): pass))
	eb.tooltip_text = Loc.t("Partager tes dessins : crée un fichier .zip à envoyer")
	eb.disabled = Meta.gallery("all").is_empty()
	UI.put(self, eb, Vector2(544, 10), Vector2(84, 18))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	UI.put(self, tabs, Vector2(12, 34), Vector2(616, 16))
	for k in KINDS:
		var kid: String = k[0]
		var b := UI.button(k[1], func():
			kind = kid
			selected = {}
			_build())
		b.tooltip_text = Loc.t("%d dessin(s)") % Meta.gallery(kid).size()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if kid == kind:
			b.add_theme_stylebox_override("normal", UI.sb(UI.SELECTED, Pal.ACCENT, 1))
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	UI.put(self, sc, Vector2(12, 58), Vector2(616, 268))
	UI.keep_scroll(sc, scroll_mem, str(kind))
	var grid := GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	sc.add_child(grid)
	var entries := Meta.gallery(kind)
	for e in entries:
		var img := Meta.gallery_image(e)
		if img == null:
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 52)
		b.tooltip_text = Loc.t("Encre : %d\nClique pour voir en grand") % Analyzer.ink_cost(img)
		b.add_theme_stylebox_override("normal", UI.sb(Pal.PAPER, Pal.BORDER, 1))
		b.add_theme_stylebox_override("hover", UI.sb(Pal.PAPER, Pal.ACCENT, 2))
		b.add_theme_stylebox_override("pressed", UI.sb(Pal.PAPER, Pal.ACCENT, 3))
		var th := UI.thumb(img, Vector2(44, 44))
		th.position = Vector2(4, 4)
		b.add_child(th)
		var entry: Dictionary = e
		b.pressed.connect(func():
			Sfx.play("click")
			_view(entry))
		grid.add_child(b)
	if entries.is_empty():
		UI.put(self, UI.label(Loc.t("Aucun dessin ici pour l'instant."), 10, Pal.DIM), Vector2(12, 64))
	else:
		UI.put(self, UI.label(Loc.t("%d dessin%s · clique pour voir en grand") % [entries.size(), "s" if entries.size() > 1 else ""], 10, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(228, 337), Vector2(400, 14))
	UI.put(self, UI.hotkey(UI.button(Loc.t("Retour"), func(): done.emit(null)), [KEY_ESCAPE]), Vector2(12, 334), Vector2(80, 18))


## Un dessin en grand, avec ses infos et « Supprimer ».
func _view(e: Dictionary) -> void:
	var img := Meta.gallery_image(e)
	if img == null or viewer:
		return
	selected = e
	viewer = Control.new()
	viewer.set_anchors_preset(PRESET_FULL_RECT)
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(viewer)
	UI.fill_bg(viewer, Color(0, 0, 0, 0.7))
	var p := UI.panel(Pal.BG, Pal.ACCENT, 2)
	UI.put(viewer, p, Vector2(110, 14), Vector2(420, 330))
	var cat := ""
	for k in KINDS:
		if k[0] == e.kind:
			cat = k[1]
	UI.put(p, UI.label(cat.to_upper(), 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 8), Vector2(420, 12))
	var fr := UI.panel(Pal.PAPER, Pal.BORDER, 2)
	UI.put(p, fr, Vector2(70, 26), Vector2(280, 240))
	var t := Analyzer.trim(img)
	var big := UI.thumb(Gfx.baked_outline(t) if e.get("outline", false) else t, Vector2(264, 224))
	UI.put(fr, big, Vector2(8, 8), Vector2(264, 224))
	var ob := UI.button(Loc.t("Bord : %s") % ("oui" if e.get("outline", false) else "non"), func(): pass)
	ob.tooltip_text = Loc.t("Contour noir quand tu réutilises ce dessin (touche C)")
	ob.pressed.connect(func():
		Meta.gallery_set_outline(e, not e.get("outline", false))
		ob.text = Loc.t("Bord : %s") % (Loc.t("oui") if e.outline else Loc.t("non"))
		big.texture = ImageTexture.create_from_image(Gfx.baked_outline(t) if e.outline else t)
		Sfx.play("click"))
	UI.hotkey(ob, [KEY_C])
	UI.put(p, ob, Vector2(330, 8), Vector2(80, 14))
	UI.put(p, UI.label(Loc.t("%d × %d px · encre %d") % [img.get_width(), img.get_height(), Analyzer.ink_cost(img)], 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 270), Vector2(420, 12))
	# À quoi ce dessin sert dans le Codex (dessin de base de...)
	var uses := Meta.gallery_uses(img)
	var ut := (Loc.t("Dessin de base de : ") + ", ".join(uses)) if not uses.is_empty() else Loc.t("Pas utilisé comme dessin de base")
	var ul := UI.label(ut, 10, Pal.GOOD if not uses.is_empty() else Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	ul.clip_text = true
	ul.tooltip_text = "\n".join(uses) if not uses.is_empty() else ""
	ul.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.put(p, ul, Vector2(8, 285), Vector2(404, 12))
	UI.put(p, UI.hotkey(UI.button(Loc.t("Fermer"), func():
		viewer.queue_free()
		viewer = null
		selected = {}), [KEY_ESCAPE]), Vector2(90, 304), Vector2(110, 18))
	UI.put(p, UI.hotkey(UI.button(Loc.t("Supprimer"), _ask_delete), [KEY_DELETE]), Vector2(220, 304), Vector2(110, 18))


func _ask_delete() -> void:
	if selected.is_empty() or confirm:
		return
	confirm = Control.new()
	confirm.set_anchors_preset(PRESET_FULL_RECT)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm)
	UI.fill_bg(confirm, Color(0, 0, 0, 0.6))
	var p := UI.panel(Pal.BG, Pal.BAD, 2)
	UI.put(confirm, p, Vector2(170, 110), Vector2(300, 140))
	UI.put(p, UI.label(Loc.t("Supprimer ce dessin ?"), 20, Pal.BAD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 10), Vector2(300, 24))
	var img := Meta.gallery_image(selected)
	if img:
		var bg := UI.panel(Pal.PAPER, Pal.BORDER, 1)
		UI.put(p, bg, Vector2(126, 40), Vector2(48, 48))
		UI.put(bg, UI.thumb(img, Vector2(44, 44)), Vector2(2, 2), Vector2(44, 44))
	UI.put(p, UI.label(Loc.t("Il disparaîtra définitivement de ta galerie."), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 94), Vector2(300, 12))
	UI.put(p, UI.hotkey(UI.button(Loc.t("Garder"), func():
		confirm.queue_free()
		confirm = null), [KEY_ESCAPE]), Vector2(40, 112), Vector2(100, 18))
	UI.put(p, UI.button(Loc.t("Supprimer"), func():
		Meta.remove_from_gallery(selected)
		Sfx.play("explode")
		selected = {}
		_build()), Vector2(160, 112), Vector2(100, 18))
