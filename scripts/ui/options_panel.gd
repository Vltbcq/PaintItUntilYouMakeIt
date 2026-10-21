class_name OptionsPanel
extends Control
## Options : volumes (général, musique, bruitages), plein écran, zoom par défaut, crédits. Émet done(null) en fermant.

signal done(result)

const ZOOMS := [1.0, 1.25, 1.5, 1.75, 2.0]

var groups := {}
var from_title := false   # la langue ne se change que depuis l'écran-titre (les autres écrans sont déjà construits)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.fill_bg(self)
	UI.put(self, UI.label(Loc.t("OPTIONS"), 30, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 20), Vector2(640, 36))

	var y := 70.0
	for v in [["volume", Loc.t("Volume général")], ["music_volume", Loc.t("Musique")], ["sfx_volume", Loc.t("Bruitages")]]:
		var key: String = v[0]
		UI.put(self, UI.label(v[1], 10, Pal.TEXT), Vector2(150, y + 2))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = float(Meta.setting(key))
		sl.focus_mode = Control.FOCUS_NONE
		sl.value_changed.connect(func(val): Meta.set_setting(key, val))
		sl.drag_ended.connect(func(_c): Sfx.play("click"))
		UI.put(self, sl, Vector2(280, y), Vector2(200, 16))
		y += 26

	y += 10
	UI.put(self, UI.label(Loc.t("Affichage"), 10, Pal.TEXT), Vector2(150, y + 2))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 3)
	UI.put(self, wrow, Vector2(280, y), Vector2(300, 16))
	var wbtns := []
	for m in [["fenetre", Loc.t("Fenêtre")], ["plein", Loc.t("Plein écran")], ["sans_bord", Loc.t("Sans bord")]]:
		var mid: String = m[0]
		var b := UI.button(m[1], func():
			Meta.set_setting("window_mode", mid)
			for o in wbtns:
				o.remove_theme_stylebox_override("normal")
				o.remove_theme_color_override("font_color")
				if o.get_meta("mode") == mid:
					UI.selected(o))
		b.set_meta("mode", mid)
		if String(Meta.setting("window_mode")) == mid:
			UI.selected(b)
		wrow.add_child(b)
		wbtns.append(b)
	wrow.get_child(2).tooltip_text = Loc.t("Plein écran sans bord : Alt+Tab instantané")

	y += 34
	UI.put(self, UI.label(Loc.t("Zoom par défaut"), 10, Pal.TEXT), Vector2(150, y + 2))
	_choices("zoom", ZOOMS, Vector2(280, y))
	UI.put(self, UI.label(Loc.t("(en jeu : molette ou + / -)"), 10, Pal.DIM), Vector2(280, y + 20))

	# Langue : "" = celle du système. Changer reconstruit ce panneau ; l'écran-titre l'est au retour.
	y += 44
	UI.put(self, UI.label(Loc.t("Langue"), 10, Pal.TEXT), Vector2(150, y + 2))
	if from_title:
		var lrow := HBoxContainer.new()
		lrow.add_theme_constant_override("separation", 3)
		UI.put(self, lrow, Vector2(280, y), Vector2(300, 16))
		for id in Loc.LANGS:
			var lid: String = id
			var lb := UI.button(Loc.LANG_NAMES[lid], func():
				Meta.set_setting("lang", lid)
				for c in get_children():
					c.queue_free()
				groups.clear()
				_ready())
			lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			if Loc.lang == lid:
				UI.selected(lb)
			lrow.add_child(lb)
	else:
		UI.put(self, UI.label(Loc.t("%s  (se change depuis l'écran-titre)") % Loc.LANG_NAMES[Loc.lang], 10, Pal.DIM), Vector2(280, y + 2), Vector2(300, 12))

	# Crédits : l'équipe, les testeurs, et le crédit obligatoire des musiques (licence de soundimage.org)
	y += 30
	UI.put(self, UI.label(Loc.t("Crédits"), 10, Pal.TEXT), Vector2(150, y + 2))
	UI.put(self, UI.button(Loc.t("Voir les crédits"), _credits), Vector2(280, y), Vector2(140, 16))

	UI.put(self, UI.hotkey(UI.button(Loc.t("Fermer"), func(): done.emit(null), 20), [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]), Vector2(260, 316), Vector2(120, 26))


## Testeurs : par ordre alphabétique (pseudos tels quels, jamais traduits)
const TESTERS := "CoffeGopher · cecilouXe · chuck joris · elouanr · Enderguigui · fan de moi · Gold Luckyy · KC Dory · Newedgar · Petit Aros · POM'S · Scarab · scraccio"


func _credits() -> void:
	var ov := Control.new()
	ov.process_mode = Node.PROCESS_MODE_ALWAYS
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.put(self, ov, Vector2.ZERO, Vector2(640, 360))
	UI.fill_bg(ov, Color(0, 0, 0, 0.6))
	var p := UI.panel(Pal.PANEL, Pal.BORDER, 2)
	UI.put(ov, p, Vector2(110, 45), Vector2(420, 270))
	UI.put(p, UI.label("PAINT IT UNTIL YOU MAKE IT", 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 8), Vector2(420, 24))
	var y := 40.0
	for part in [[Loc.t("Un jeu de Malphear"), Loc.t("Idée, développement et game design")], [Loc.t("Logo et illustrations"), "cecilouXe"],
			[Loc.t("Testeurs"), TESTERS]]:
		UI.put(p, UI.label(part[0], 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, y), Vector2(420, 12))
		var t := UI.label(part[1], 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # (les pseudos ne se traduisent pas)
		var h := 12.0 if part[1] != TESTERS else 40.0
		UI.put(p, t, Vector2(20, y + 13), Vector2(380, h))
		y += 13.0 + h + 10.0
	var small := UI.label("\n".join([Loc.t("Musique : Eric Matyas · soundimage.org"), Loc.t("Police : Yoster Island, par codeman38"),
		Loc.t("Fait avec Godot Engine · intégration Steam : GodotSteam")]), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(p, small, Vector2(0, y), Vector2(420, 40))
	UI.put(p, UI.label(Loc.t("Merci d'avoir joué !"), 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, y + 46), Vector2(420, 12))
	UI.put(p, UI.hotkey(UI.button(Loc.t("Fermer"), func(): ov.queue_free()), [KEY_ESCAPE]), Vector2(160, 246), Vector2(100, 16))


func _choices(key: String, values: Array, pos: Vector2) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	UI.put(self, row, pos, Vector2(300, 16))
	groups[key] = []
	for v in values:
		var val: float = v
		var b := UI.button("×%s" % str(val), func():
			Meta.set_setting(key, val)
			_refresh())
		b.set_meta("v", val)
		row.add_child(b)
		groups[key].append(b)
	_refresh()


func _refresh() -> void:
	for key in groups:
		for b: Button in groups[key]:
			var on := is_equal_approx(float(b.get_meta("v")), float(Meta.setting(key)))
			if on:
				b.add_theme_stylebox_override("normal", UI.sb(UI.SELECTED, Pal.ACCENT, 1))
				b.add_theme_color_override("font_color", Pal.ACCENT)
			else:
				b.remove_theme_stylebox_override("normal")
				b.remove_theme_color_override("font_color")
