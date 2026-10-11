class_name RunLogScreen
extends Control
## Journal de la partie : ton perso (armes, amulettes), difficulté, vague, stats au début de la
## dernière vague, et tout ce que tu as fait (achats, bonus de niveau, événements...).
## Mode « resume » : boutons Reprendre / Retour -> done(true / false). Mode « view » : Fermer -> done(false).

signal done(result)

var mode := "view"


func _init(m := "view") -> void:
	mode = m


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UI.fill_bg(self)
	var title := Loc.t("REPRENDRE LA PARTIE ?") if mode == "resume" else Loc.t("JOURNAL DE LA PARTIE")
	UI.put(self, UI.label(title, 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(640, 24))

	# --- Gauche : le perso, ses armes et amulettes
	var pf := UI.panel(Pal.PAPER, Pal.ACCENT, 2)
	UI.put(self, pf, Vector2(12, 36), Vector2(120, 132))
	if Run.character:
		UI.put(pf, UI.thumb(Run.build_player_image(), Vector2(108, 120)), Vector2(6, 6), Vector2(108, 120))
	var wl := UI.label(Loc.t("ARMES"), 10, Pal.DIM)
	UI.put(self, wl, Vector2(12, 172))
	var wx := 12.0
	var wy := 186.0
	for w in Run.weapons:
		var f := UI.panel(Pal.PAPER, Pal.RARITY[int(w.rar)], 2)
		f.tooltip_text = "%s %s" % [WeaponDB.get_def(w.type).name, Pal.RARITY_NAMES_F[int(w.rar)].to_lower()]
		UI.put(self, f, Vector2(wx, wy), Vector2(38, 30))
		UI.put(f, UI.thumb(Run.weapon_image(w), Vector2(32, 24)), Vector2(3, 3), Vector2(32, 24))
		wx += 41
		if wx > 100:
			wx = 12
			wy += 33
	var ay := wy + 38.0
	UI.put(self, UI.label(Loc.t("AMULETTES"), 10, Pal.DIM), Vector2(12, ay))
	var ax := 12.0
	ay += 14
	for am in Run.amulets:
		var d := AmuletDB.get_def(am.id)
		var th := UI.thumb(am.image, Vector2(18, 18))
		th.mouse_filter = Control.MOUSE_FILTER_STOP
		th.tooltip_text = "%s\n%s" % [d.name, AmuletDB.describe(d, am.mag)]
		UI.put(self, th, Vector2(ax, ay), Vector2(18, 18))
		ax += 20
		if ax > 120:
			ax = 12
			ay += 20

	# --- Milieu : la partie + stats au début de la dernière vague
	var info := Loc.t("%s · %s\nVague %d / %d · Niveau %d\nOr : ● %d · PV %d / %d\nEnnemis tués : %d") % [
		MapDB.get_def(Run.map).name, Meta.DIFFICULTIES[Run.difficulty].name, Run.wave, Run.WAVES, Run.level,
		Run.gold, ceili(Run.hp), int(Run.stats.get("max_hp", 0)), Run.kills]
	var il := UI.label(info, 10, Pal.TEXT)
	UI.put(self, il, Vector2(142, 36), Vector2(200, 56))
	var sw := int(Run.wave_stats.get("wave", 0))
	UI.put(self, UI.label(Loc.t("STATS AU DÉBUT DE LA VAGUE %d") % sw if sw > 0 else Loc.t("STATS"), 10, Pal.ACCENT), Vector2(142, 96))
	var sp := UI.panel()
	UI.put(self, sp, Vector2(142, 110), Vector2(200, 214))
	var st_txt := String(Run.wave_stats.get("text", Stats.describe_player(Run.stats)))
	var sl := StatText.new(2)
	UI.put(sp, sl, Vector2(6, 4), Vector2(190, 206))
	sl.set_text(st_txt)

	# --- Droite : le journal (le plus récent en haut)
	UI.put(self, UI.label(Loc.t("JOURNAL"), 10, Pal.ACCENT), Vector2(352, 36))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.put(self, sc, Vector2(352, 50), Vector2(276, 274))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.custom_minimum_size = Vector2(262, 0)
	sc.add_child(vb)
	var entries: Array = Run.journal.duplicate()
	entries.reverse()
	for e in entries:
		var l := UI.label("V%d  %s" % [int(e.w), e.t], 10, _col(String(e.get("k", ""))))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(262, 0)
		vb.add_child(l)
	if entries.is_empty():
		vb.add_child(UI.label(Loc.t("Rien pour l'instant."), 10, Pal.DIM))

	# --- Boutons
	if mode == "resume":
		UI.put(self, UI.hotkey(UI.button(Loc.t("Retour"), func(): done.emit(false)), [KEY_ESCAPE]), Vector2(12, 334), Vector2(100, 18))
		UI.put(self, UI.hotkey(UI.button(Loc.t("REPRENDRE →"), func(): done.emit(true), 20), [KEY_ENTER, KEY_KP_ENTER]), Vector2(488, 330), Vector2(140, 24))
	else:
		UI.put(self, UI.hotkey(UI.button(Loc.t("Fermer"), func(): done.emit(false)), [KEY_ESCAPE, KEY_ENTER]), Vector2(270, 334), Vector2(100, 18))


static func _col(kind: String) -> Color:
	match kind:
		"buy":
			return Pal.TEXT
		"level":
			return Pal.GOOD
		"event":
			return Pal.ACCENT
		"wave":
			return Pal.DIM
		"sell":
			return Color("f0a060")
	return Pal.TEXT
