class_name StatsScreen
extends Control
## Statistiques : résumé global, courbes par partie, objets favoris, dessins et couleurs.
## Les fiches de parties (Meta.data.history) existent depuis la v0.9 ; les totaux (parties,
## ennemis, boss...) viennent de toute la sauvegarde. Émet done(null) en fermant.

signal done(result)

static var TABS := [["resume", "Résumé"], ["parties", "Parties"], ["objets", "Objets"], ["dessins", "Dessins"]]
const LAST := 30   # parties montrées sur les courbes

var tab := "resume"
var history: Array = []
var _counting := false     # des dessins n'ont pas encore leurs couleurs comptées (Meta s'en charge)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	history = Meta.data.get("history", [])
	# Les dessins jamais comptés le sont en arrière-plan (Meta.prefetch) : l'écran s'affiche tout de suite
	if (Meta.data.get("gallery", []) as Array).any(func(e): return not e.has("el")):
		_counting = true
		Meta.infos_done.connect(_on_infos)
		Meta.prefetch()
	_build()


func _on_infos() -> void:
	_counting = false
	if tab == "dessins":
		_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	UI.fill_bg(self)
	UI.put(self, UI.label(Loc.t("STATISTIQUES"), 20, Pal.ACCENT), Vector2(12, 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	UI.put(self, row, Vector2(200, 12), Vector2(420, 16))
	for t in TABS:
		var id: String = t[0]
		var b := UI.button(t[1], func():
			tab = id
			_build())
		if id == tab:
			UI.selected(b)
		row.add_child(b)
	match tab:
		"resume":
			_resume()
		"parties":
			_parties()
		"objets":
			_objets()
		"dessins":
			_dessins()
	UI.put(self, UI.hotkey(UI.button(Loc.t("Retour"), func(): done.emit(null)), [KEY_ESCAPE]), Vector2(12, 336), Vector2(80, 18))


# ------------------------------------------------------------------ Résumé

func _resume() -> void:
	var d := Meta.data
	var c: Dictionary = d.get("counters", {})
	var runs := int(d.get("runs", 0))
	var wins := int(d.get("wins", 0))
	var lines := [
		[Loc.t("Parties jouées"), str(runs)],
		[Loc.t("Victoires"), "%d  (%d %%)" % [wins, roundi(100.0 * wins / maxf(1.0, runs))]],
		[Loc.t("Temps de jeu"), _duration(float(d.get("play_time", 0.0)))],
		[Loc.t("Ennemis tués"), _big(int(d.get("total_kills", 0)))],
		[Loc.t("Élites tuées"), _big(int(d.get("total_elites", 0)))],
		[Loc.t("Boss vaincus"), _big(int(c.get("bosses", 0)))],
		[Loc.t("Dégâts infligés"), _big(int(c.get("damage", 0)))],
		[Loc.t("Or ramassé"), _big(int(c.get("gold_earned", 0)))],
		[Loc.t("Or dépensé"), _big(int(c.get("gold_spent", 0)))],
		[Loc.t("Record de vague"), str(maxi(int(d.get("best_wave", 0)), int(d.get("best_endless", 0))))],   # (mode infini compris)
	]
	var p := UI.panel()
	UI.put(self, p, Vector2(12, 40), Vector2(290, 290))
	UI.put(p, UI.label(Loc.t("TOUTES PARTIES"), 10, Pal.ACCENT), Vector2(10, 8))
	for i in lines.size():
		UI.put(p, UI.label(lines[i][0], 10, Pal.DIM), Vector2(10, 28 + i * 22), Vector2(150, 12))
		UI.put(p, UI.label(lines[i][1], 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(150, 28 + i * 22), Vector2(130, 12))
	# Par difficulté : parties, victoires, et une barre du % de victoire
	var q := UI.panel()
	UI.put(self, q, Vector2(310, 40), Vector2(318, 290))
	UI.put(q, UI.label(Loc.t("PAR DIFFICULTÉ"), 10, Pal.ACCENT), Vector2(10, 8))
	if history.is_empty():
		_empty(q, Vector2(318, 290))
		return
	for i in Meta.DIFFICULTIES.size():
		var played := history.filter(func(h): return int(h.diff) == i)
		var won := played.filter(func(h): return bool(h.win))
		var y := 34 + i * 50
		UI.put(q, UI.label(Meta.DIFFICULTIES[i].name, 10, Pal.TEXT), Vector2(10, y), Vector2(120, 12))
		UI.put(q, UI.label(Loc.t("%d parties · %d victoires") % [played.size(), won.size()], 10, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(120, y), Vector2(188, 12))
		var rate := float(won.size()) / maxf(1.0, played.size())
		var bar := _Bars.new()
		bar.values = [rate]
		bar.max_v = 1.0
		bar.cols = [Pal.GOOD]
		bar.horizontal = true
		bar.labels = ["%d %%" % roundi(rate * 100.0) if not played.is_empty() else "—"]
		UI.put(q, bar, Vector2(10, y + 16), Vector2(298, 14))
	UI.put(q, UI.label(Loc.t("(fiches de parties depuis la v0.9)"), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 270), Vector2(318, 12))


# ------------------------------------------------------------------ Parties

func _parties() -> void:
	var last := history.slice(maxi(0, history.size() - LAST))
	var specs := [
		[Loc.t("VAGUE ATTEINTE (%d dernières parties)") % LAST, "wave", "line"],
		[Loc.t("ENNEMIS TUÉS PAR PARTIE"), "kills", "bars"],
		[Loc.t("DÉGÂTS INFLIGÉS PAR PARTIE"), "damage", "bars"],
	]
	for i in specs.size():
		var p := UI.panel()
		UI.put(self, p, Vector2(12, 40 + i * 98), Vector2(616, 92))
		UI.put(p, UI.label(specs[i][0], 10, Pal.ACCENT), Vector2(10, 6))
		if last.is_empty():
			_empty(p, Vector2(616, 92))
			continue
		var vals := last.map(func(h): return float(h.get(specs[i][1], 0)))
		var mx: float = vals.max()
		if specs[i][1] == "wave":
			mx = maxf(float(Run.WAVES), mx)
		UI.put(p, UI.label(_big(int(mx)), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(546, 6), Vector2(60, 12))
		var ch := _Bars.new()
		ch.values = vals
		ch.max_v = maxf(1.0, mx)
		ch.line = specs[i][2] == "line"
		ch.cols = last.map(func(h): return Pal.GOOD if bool(h.win) else Pal.BAD)
		ch.goal = float(Run.WAVES) if ch.line else -1.0
		UI.put(p, ch, Vector2(10, 22), Vector2(596, 62))
	UI.put(self, UI.label(Loc.t("vert = victoire · rouge = défaite"), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(300, 338), Vector2(328, 12))


# ------------------------------------------------------------------ Objets favoris

func _objets() -> void:
	var cols := [[Loc.t("ARMES"), "weapons"], [Loc.t("AMULETTES"), "amulets"], [Loc.t("FAMILIERS"), "familiars"]]
	for i in cols.size():
		var p := UI.panel()
		UI.put(self, p, Vector2(12 + i * 206, 40), Vector2(200, 290))
		UI.put(p, UI.label(cols[i][0], 10, Pal.ACCENT), Vector2(10, 8))
		if history.is_empty():
			_empty(p, Vector2(200, 290))
			continue
		# Combien de parties avec cet objet, et combien gagnées
		var n := {}
		var w := {}
		for h in history:
			for id in h.get(cols[i][1], []):
				n[id] = int(n.get(id, 0)) + 1
				if bool(h.win):
					w[id] = int(w.get(id, 0)) + 1
		var ids := n.keys()
		ids.sort_custom(func(a, b): return int(n[a]) > int(n[b]))
		ids = ids.slice(0, 9)
		if ids.is_empty():
			UI.put(p, UI.label(Loc.t("Aucun pour l'instant."), 10, Pal.DIM), Vector2(10, 30))
			continue
		var top := float(n[ids[0]])
		for k in ids.size():
			var id: String = ids[k]
			var y := 28 + k * 28
			UI.put(p, UI.label(_item_name(cols[i][1], id), 10, Pal.TEXT), Vector2(10, y), Vector2(180, 12))
			var bar := _Bars.new()
			bar.values = [float(n[id])]
			bar.max_v = top
			bar.cols = [Pal.ACCENT]
			bar.horizontal = true
			bar.labels = ["%d · %d %% V" % [int(n[id]), roundi(100.0 * int(w.get(id, 0)) / float(n[id]))]]
			UI.put(p, bar, Vector2(10, y + 13), Vector2(180, 11))
	UI.put(self, UI.label(Loc.t("parties avec l'objet · % de victoires"), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(300, 338), Vector2(328, 12))


func _item_name(kind: String, id: String) -> String:
	match kind:
		"weapons":
			return String(WeaponDB.get_def(id).get("name", id))
		"amulets":
			return String(AmuletDB.get_def(id).get("name", id))
	return String(FamiliarDB.get_def(id).get("name", id))


# ------------------------------------------------------------------ Dessins et couleurs

func _dessins() -> void:
	# Pixels de chaque couleur dans toute la galerie : comptés une fois par dessin, puis gardés
	# dans sa fiche (« el », voir Meta.drawing_info), car relire des centaines de fichiers est lent
	var entries: Array = Meta.data.get("gallery", [])
	var px := []
	px.resize(Pal.COUNT)
	px.fill(0.0)
	for e in entries:
		for k in mini((e.get("el", []) as Array).size(), Pal.COUNT):
			px[k] += float(e.el[k])
	var p := UI.panel()
	UI.put(self, p, Vector2(12, 40), Vector2(330, 290))
	UI.put(p, UI.label(Loc.t("COULEURS DE TES DESSINS"), 10, Pal.ACCENT), Vector2(10, 8))
	var total: float = 0.0
	for v in px:
		total += v
	if _counting:
		UI.put(p, UI.label(Loc.t("Calcul des couleurs..."), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 130), Vector2(330, 12))
	elif total <= 0.0:
		_empty(p, Vector2(330, 290))
	else:
		var pie := _Pie.new()
		pie.values = px
		pie.cols = range(Pal.COUNT).map(func(k): return Color("4a4a58") if k == 0 else Pal.main_color(k))
		UI.put(p, pie, Vector2(10, 40), Vector2(170, 170))
		for k in Pal.COUNT:
			var y := 40 + k * 22
			var sw := ColorRect.new()
			sw.color = pie.cols[k]
			UI.put(p, sw, Vector2(196, y + 1), Vector2(10, 10))
			UI.put(p, UI.label("%s  %d %%" % [Pal.NAMES[k], roundi(100.0 * px[k] / total)], 10, Pal.TEXT), Vector2(212, y), Vector2(110, 12))
	# Chiffres et l'ennemi qui t'a le plus effacé
	var q := UI.panel()
	UI.put(self, q, Vector2(350, 40), Vector2(278, 290))
	UI.put(q, UI.label(Loc.t("TES DESSINS"), 10, Pal.ACCENT), Vector2(10, 8))
	var facts := [
		[Loc.t("Pixels peints"), _big(int(Meta.data.get("pixels_painted", 0)))],
		[Loc.t("Dessins en galerie"), str(entries.size())],
	]
	for i in facts.size():
		UI.put(q, UI.label(facts[i][0], 10, Pal.DIM), Vector2(10, 28 + i * 22), Vector2(150, 12))
		UI.put(q, UI.label(facts[i][1], 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT), Vector2(150, 28 + i * 22), Vector2(118, 12))
	UI.put(q, UI.label(Loc.t("TON PIRE ENNEMI"), 10, Pal.ACCENT), Vector2(10, 90))
	var k_n := {}
	for h in history:
		var kid := String(h.get("killer", ""))
		if kid != "":
			k_n[kid] = int(k_n.get(kid, 0)) + 1
	if k_n.is_empty():
		UI.put(q, UI.label(Loc.t("Personne ne t'a encore effacé."), 10, Pal.DIM), Vector2(10, 110), Vector2(258, 12))
		return
	var worst: String = k_n.keys()[0]
	for kid in k_n:
		if int(k_n[kid]) > int(k_n[worst]):
			worst = kid
	var fr := UI.panel(Pal.PAPER, Pal.BAD, 2)
	UI.put(q, fr, Vector2(10, 110), Vector2(84, 84))
	var art = Meta.bestiary_get(worst)
	var img: Image = Analyzer.trim(art.image) if art != null else Gfx.icon(Gfx.ICON_UNKNOWN)
	UI.put(fr, UI.thumb(img, Vector2(76, 76)), Vector2(4, 4), Vector2(76, 76))
	UI.put(q, UI.label(String(EnemyDB.get_def(worst).get("name", worst)), 20, Pal.BAD), Vector2(104, 120), Vector2(164, 24))
	UI.put(q, UI.label(Loc.t("t'a effacé %d fois") % int(k_n[worst]), 10, Pal.TEXT), Vector2(104, 150), Vector2(164, 12))


# ------------------------------------------------------------------ Outils

func _empty(parent: Control, size: Vector2) -> void:
	UI.put(parent, UI.label(Loc.t("Joue une partie pour voir tes statistiques ici."), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, size.y / 2.0 - 6), Vector2(size.x, 12))


static func _big(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func _duration(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%d h %02d" % [m / 60, m % 60] if m >= 60 else Loc.t("%d min") % m


## Barres (verticales ou horizontales) ou courbe à points.
class _Bars extends Control:
	var values: Array = []
	var cols: Array = []
	var labels: Array = []
	var max_v := 1.0
	var horizontal := false
	var line := false
	var goal := -1.0   # ligne repère (ex. vague 15)

	func _draw() -> void:
		var n := values.size()
		if n == 0:
			return
		if horizontal:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
			var w := size.x * clampf(float(values[0]) / max_v, 0.0, 1.0)
			draw_rect(Rect2(0, 0, w, size.y), cols[0])
			if not labels.is_empty():
				draw_string(UI.font, Vector2(4, size.y - 2), String(labels[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Pal.INK if w > 60.0 else Pal.TEXT)
			return
		draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Pal.DIM, 1.0)
		if goal > 0.0:
			var gy := size.y * (1.0 - goal / max_v)
			for x in range(0, int(size.x), 8):
				draw_line(Vector2(x, gy), Vector2(x + 4, gy), Color(Pal.ACCENT, 0.6), 1.0)
		var step := size.x / float(n)
		var prev := Vector2.ZERO
		for i in n:
			var v := clampf(float(values[i]) / max_v, 0.0, 1.0)
			var x := step * (i + 0.5)
			var y := size.y * (1.0 - v)
			var col: Color = cols[i] if i < cols.size() else Pal.ACCENT
			if line:
				if i > 0:
					draw_line(prev, Vector2(x, y), Color(Pal.TEXT, 0.5), 1.0)
				draw_circle(Vector2(x, y), 3.0, col)
				prev = Vector2(x, y)
			else:
				draw_rect(Rect2(x - step * 0.35, y, step * 0.7, size.y - y), col)


## Camembert.
class _Pie extends Control:
	var values: Array = []
	var cols: Array = []

	func _draw() -> void:
		var total := 0.0
		for v in values:
			total += float(v)
		if total <= 0.0:
			return
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		var a := -PI / 2.0
		for i in values.size():
			var sweep := TAU * float(values[i]) / total
			if sweep <= 0.0:
				continue
			var pts := PackedVector2Array([c])
			var steps := maxi(2, int(sweep * 20.0))
			for k in steps + 1:
				pts.append(c + Vector2.from_angle(a + sweep * k / steps) * r)
			draw_colored_polygon(pts, cols[i])
			a += sweep
		draw_arc(c, r, 0.0, TAU, 64, Pal.INK, 2.0)
