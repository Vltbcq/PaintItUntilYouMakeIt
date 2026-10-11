class_name GalleryShare
extends Control
## Partage de dessins (par-dessus la Galerie) :
## - EXPORTER : tu coches les dessins à partager (tout est coché au départ, filtres par catégorie),
##   puis la fenêtre Windows « Enregistrer sous » crée un .zip (Téléchargements par défaut) ;
## - IMPORTER : tu choisis un .zip reçu ; un aperçu montre ses dessins (ceux que tu as déjà sont
##   grisés), tu coches ceux que tu veux et ils rejoignent ta galerie (jamais rien d'écrasé).
## Le fichier est lu / écrit par Meta.export_gallery / Meta.read_share / Meta.import_share.
## Émet done(changed: bool) en se fermant.

signal done(changed)

static var KINDS := GalleryScreen.KINDS
const CELL := 64.0

var mode := "export"         # "export" | "import"
var items: Array = []        # export : entrées de galerie ; import : {image, kind, effect, outline, dup}
var picked: Array = []       # bool par élément
var kind := "all"            # filtre affiché
var src_name := ""           # import : nom du fichier lu
var body: Control            # le panneau (reconstruit à chaque changement)
var cells: Array = []        # import : [Control de la vignette, index]
var changed := false


static func open_export(parent: Control) -> GalleryShare:
	var s := GalleryShare.new()
	s.mode = "export"
	s.items = Meta.gallery("all")
	s.picked = s.items.map(func(_e): return true)
	parent.add_child(s)
	return s


static func open_import(parent: Control, path: String) -> GalleryShare:
	var s := GalleryShare.new()
	s.mode = "import"
	var r := Meta.read_share(path)
	s.src_name = path.get_file()
	s.items = r.items
	s.picked = s.items.map(func(it): return not it.dup)
	parent.add_child(s)
	if not r.ok:
		s._message(Loc.t("Import impossible"), String(r.error), Pal.BAD)
	return s


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.fill_bg(self, Color(0, 0, 0, 0.72))
	if body == null:
		_build()


func _close() -> void:
	done.emit(changed)
	queue_free()


# ------------------------------------------------------------------ Choix des dessins

func _build() -> void:
	if body:
		body.queue_free()
	cells = []
	body = UI.panel(Pal.BG, Pal.ACCENT, 2)
	UI.put(self, body, Vector2(16, 10), Vector2(608, 340))
	var title := Loc.t("EXPORTER DES DESSINS") if mode == "export" else Loc.t("IMPORTER DES DESSINS")
	UI.put(body, UI.label(title, 20, Pal.ACCENT), Vector2(12, 6), Vector2(400, 24))
	var sub := ""
	if mode == "export":
		sub = Loc.t("Choisis ce que tu partages : tout est coché. Clique un dessin pour le retirer.")
	else:
		var dups := items.filter(func(it): return it.dup).size()
		sub = Loc.t("%s · %d dessin%s · %d nouveau%s%s") % [src_name, items.size(), "s" if items.size() > 1 else "",
			items.size() - dups, Loc.agr(items.size() - dups, "x"), (Loc.t(" · %d déjà dans ta galerie (grisés)") % dups) if dups > 0 else ""]
	var sl := UI.label(sub, 10, Pal.DIM)
	sl.clip_text = true
	UI.put(body, sl, Vector2(12, 32), Vector2(584, 12))

	# Filtres par catégorie (seulement celles présentes) + tout cocher / décocher
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	UI.put(body, row, Vector2(12, 48), Vector2(584, 16))
	for k in KINDS:
		var kid: String = k[0]
		var n := _of_kind(kid).size()
		if n == 0:
			continue
		var b := UI.button("%s %d" % [k[1], n], func():
			kind = kid
			_build())
		if kid == kind:
			UI.selected(b)
		row.add_child(b)

	# Les vignettes
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.put(body, sc, Vector2(12, 70), Vector2(584, 228))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	for i in _of_kind(kind):
		grid.add_child(_cell(i))

	# Bas : le compte et les boutons
	var n_sel := _count()
	var what := Loc.t("dessin%s choisi%s") % ["s" if n_sel > 1 else "", Loc.agr(n_sel)]
	UI.put(body, UI.label("%d %s" % [n_sel, what], 10, Pal.TEXT), Vector2(12, 310), Vector2(120, 12))
	UI.put(body, UI.button(Loc.t("Tout cocher"), func(): _set_all(true)), Vector2(132, 306), Vector2(80, 22))
	UI.put(body, UI.button(Loc.t("Rien"), func(): _set_all(false)), Vector2(216, 306), Vector2(56, 22))
	UI.put(body, UI.hotkey(UI.button(Loc.t("Annuler"), _close), [KEY_ESCAPE]), Vector2(300, 306), Vector2(100, 22))
	var go_txt := (Loc.t("Exporter (%d) →") % n_sel) if mode == "export" else (Loc.t("Ajouter à ma galerie (%d)") % n_sel)
	var go := UI.hotkey(UI.button(go_txt, _export if mode == "export" else _import, 10), [KEY_ENTER, KEY_KP_ENTER])
	go.disabled = n_sel == 0
	UI.put(body, go, Vector2(408, 306), Vector2(188, 22))


func _of_kind(k: String) -> Array:
	var out := []
	for i in items.size():
		if k == "all" or String(items[i].kind) == k:
			out.append(i)
	return out


func _count() -> int:
	return picked.filter(func(p): return p).size()


func _set_all(on: bool) -> void:
	for i in _of_kind(kind):
		if mode == "import" and items[i].dup:
			continue
		picked[i] = on
	Sfx.play("click")
	_build()


## Une vignette : cochée = cadre doré + coche ; décochée = pâlie. Import : un doublon est grisé.
func _cell(i: int) -> Control:
	var it = items[i]
	var img: Image = Meta.gallery_image(it) if mode == "export" else it.image
	var dup: bool = mode == "import" and it.dup
	var on: bool = picked[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.add_theme_stylebox_override("normal", UI.sb(Pal.PAPER, Pal.ACCENT if on else Pal.BORDER, 2 if on else 1))
	b.add_theme_stylebox_override("hover", UI.sb(Color.WHITE, Pal.ACCENT, 2))
	b.add_theme_stylebox_override("pressed", UI.sb(Color.WHITE, Pal.ACCENT, 3))
	b.add_theme_stylebox_override("disabled", UI.sb(Color("8a8070"), Color("5a5040"), 1))
	var cat := ""
	for k in KINDS:
		if k[0] == it.kind:
			cat = k[1]
	b.tooltip_text = cat + (Loc.t(" · déjà dans ta galerie") if dup else "")
	if img:
		var th := UI.thumb(Analyzer.trim(img), Vector2(CELL - 10, CELL - 10))
		th.position = Vector2(5, 5)
		b.add_child(th)
	if dup:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.45)
		var tag := UI.label(Loc.t("déjà là"), 10, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER)
		UI.put(b, tag, Vector2(0, CELL - 13), Vector2(CELL, 12))
	elif on:
		var ck := _Check.new()
		ck.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.put(b, ck, Vector2(CELL - 15, 1), Vector2(14, 14))
	else:
		b.modulate = Color(1, 1, 1, 0.4)
	b.pressed.connect(func():
		picked[i] = not picked[i]
		Sfx.play("click")
		_build())
	cells.append([b, i])
	return b


# ------------------------------------------------------------------ Exporter

func _export() -> void:
	var chosen := []
	for i in items.size():
		if picked[i]:
			chosen.append(items[i])
	var fd := _dialog(FileDialog.FILE_MODE_SAVE_FILE, Loc.t("Enregistrer tes dessins"))
	fd.current_file = Loc.t("PaintIt_dessins_%s.zip") % Time.get_date_string_from_system()
	fd.file_selected.connect(func(path: String):
		if not path.to_lower().ends_with(".zip"):
			path += ".zip"
		var n := Meta.export_gallery(chosen, path)
		if n < 0:
			_message(Loc.t("Export impossible"), Loc.t("Le fichier n'a pas pu être écrit à cet endroit."), Pal.BAD)
			return
		Sfx.play("level")
		_message(Loc.t("%d dessin%s exporté%s !") % [n, "s" if n > 1 else "", Loc.agr(n)],
			Loc.t("%s\nEnvoie ce fichier : ton ami l'ouvre avec « Importer » dans sa galerie.") % path.get_file(), Pal.GOOD, path))
	fd.popup_centered_ratio(0.6)


## Fenêtre Windows « Ouvrir / Enregistrer sous », dans Téléchargements, fichiers .zip.
func _dialog(m: int, title: String) -> FileDialog:
	var fd := FileDialog.new()
	fd.use_native_dialog = true
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = m
	fd.title = title
	fd.filters = PackedStringArray([Loc.t("*.zip ; Dessins Paint It")])
	fd.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	add_child(fd)
	return fd


static func pick_import(parent: Control, on_file: Callable) -> void:
	var holder := GalleryShare.new()   # (juste pour réutiliser _dialog ; rien n'est affiché)
	holder.body = Control.new()
	holder.visible = false
	parent.add_child(holder)
	var fd := holder._dialog(FileDialog.FILE_MODE_OPEN_FILE, Loc.t("Choisis un fichier de dessins (.zip)"))
	fd.file_selected.connect(func(path: String):
		holder.queue_free()
		on_file.call(path))
	fd.canceled.connect(func(): holder.queue_free())
	fd.popup_centered_ratio(0.6)


# ------------------------------------------------------------------ Importer

func _import() -> void:
	var chosen := []
	for i in items.size():
		if picked[i]:
			chosen.append(items[i])
	var n := Meta.import_share(chosen)
	changed = n > 0
	# Petite fête : les vignettes choisies sautent l'une après l'autre avant le message
	var delay := 0.0
	for c in cells:
		var b: Control = c[0]
		if not picked[c[1]] or not is_instance_valid(b):
			continue
		b.pivot_offset = b.size / 2.0
		var tw := b.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(b, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK)
		tw.tween_property(b, "scale", Vector2.ZERO, 0.18)
		delay += 0.04
	Sfx.play("buy")
	await get_tree().create_timer(minf(delay, 1.2) + 0.35).timeout
	if not is_inside_tree():
		return
	Sfx.play("level")
	_message(Loc.t("%d dessin%s ajouté%s à ta galerie !") % [n, "s" if n > 1 else "", Loc.agr(n)],
		Loc.t("Tu peux les reprendre dès qu'on te demande de dessiner (bouton « Galerie »)."), Pal.GOOD)


# ------------------------------------------------------------------ Messages

## Fin (succès ou erreur) : un panneau simple, avec « Ouvrir le dossier » après un export.
func _message(title: String, text: String, col: Color, path := "") -> void:
	if body:
		body.queue_free()
	body = UI.panel(Pal.BG, col, 2)
	UI.put(self, body, Vector2(120, 110), Vector2(400, 140))
	UI.put(body, UI.label(title, 20, col, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 14), Vector2(400, 24))
	var tl := UI.label(text, 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.put(body, tl, Vector2(16, 48), Vector2(368, 44))
	if path != "":
		UI.put(body, UI.button(Loc.t("Ouvrir le dossier"), func(): OS.shell_show_in_file_manager(path)), Vector2(70, 104), Vector2(130, 20))
		UI.put(body, UI.hotkey(UI.button(Loc.t("Fermer"), _close), [KEY_ESCAPE, KEY_ENTER]), Vector2(210, 104), Vector2(120, 20))
	else:
		UI.put(body, UI.hotkey(UI.button(Loc.t("Fermer"), _close), [KEY_ESCAPE, KEY_ENTER]), Vector2(140, 104), Vector2(120, 20))


## Petite coche dorée sur une vignette choisie.
class _Check extends Control:
	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Pal.ACCENT)
		draw_arc(size / 2.0, size.x / 2.0, 0.0, TAU, 16, Pal.INK, 1.0)
		draw_polyline(PackedVector2Array([Vector2(3.5, 7.5), Vector2(6, 10), Vector2(10.5, 4.5)]), Pal.INK, 2.0)
