class_name VirusPopups
extends Control
## Les fenêtres du boss « Le Virus » (L'Écran, vague 5) : de fausses pubs s'ouvrent PAR-DESSUS le
## jeu, qui continue derrière. Il faut les fermer soi-même, sinon on ne voit plus rien.
## - Clavier-souris : cliquer la croix (parfois minuscule, parfois elle fuit), ne pas se faire avoir
##   par le gros bouton FERMER. Les énigmes (faux captchas) n'ont PAS de croix : il faut les résoudre.
## - Manette : la fenêtre du dessus affiche 3 touches à presser dans l'ordre (une erreur : on recommence).
## Posé dans le HUD : les fenêtres passent devant tout, barre de vie comprise.

const MAX := 12            # jamais plus de fenêtres que ça (ça reste jouable)
const MAX_PUZZLES := 2     # énigmes sans croix ouvertes en même temps, au plus
const W := 170.0
const QTE_KEYS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]
const QTE_NAMES := ["A", "B", "X", "Y"]
const QTE_COLS := [Color("6ad36a"), Color("e84a4a"), Color("3a86ff"), Color("f0c43a")]

## Pubs à fermer par la croix : [titre, texte]
const ADS := [
	["Rencontres", "STOP ! Arrête de te dessiner : elle est FRAÎCHE et près de chez toi. Nouveau pot de peinture."],
	["Astuce", "Tu veux AGRANDIR la taille de ton pinceau ?"],
	["Près de chez toi", "Des toiles VIERGES dans ta région n'attendent que toi."],
	["Rencontres", "Pinceaux célibataires à moins de 2 pixels de toi."],
	["Performance", "Marre des traits trop courts ? Tiens 15 vagues sans recharger ton encre."],
	["Message urgent", "Un prince de la Feuille veut te léguer 4 000 000 de pigments. Il lui faut juste ton numéro de palette."],
	["Incroyable", "Ce boss a une faiblesse cachée. La n°7 va te choquer."],
]

var arena: Arena
var wins: Array = []        # fenêtres ouvertes (la dernière est au-dessus)
var pad := false            # le joueur est à la manette (dernier appareil utilisé)
var door_shown := false     # clin d'œil à La Porte : une seule fois par combat
var closed := 0             # fenêtres fermées par le joueur (pour les tests et le journal)


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE


func count() -> int:
	return wins.size()


## Ouvre une fenêtre (au hasard si kind est vide). Retourne null si l'écran en est déjà plein.
func spawn(kind := "") -> Control:
	if wins.size() >= MAX:
		return null
	if kind == "":
		kind = _pick()
	var w := _build(kind)
	w.position = Vector2(randf_range(8.0, 640.0 - W - 8.0), randf_range(40.0, 360.0 - w.size.y - 8.0))
	add_child(w)
	wins.append(w)
	_qte_refresh()
	Sfx.play("click")
	return w


func _pick() -> String:
	if Run.amulet_count("porte") > 0 and not door_shown and randf() < 0.25:
		door_shown = true
		return "door"
	if randf() < 0.05:
		return "honest"   # une pub sur vingt est honnête
	var kinds := ["ad", "ad", "ad", "tiny", "flee", "trap", "memory"]
	# les énigmes (sans croix) : jamais plus de MAX_PUZZLES ouvertes à la fois
	if wins.filter(func(w): return String(w.get_meta("kind")).begins_with("c_")).size() < MAX_PUZZLES:
		kinds += ["c_spots", "c_round"]
	return kinds.pick_random()


func close(w: Control, by_player := true) -> void:
	if not wins.has(w):
		return
	wins.erase(w)
	w.queue_free()
	if by_player:
		closed += 1
		Sfx.play("paint")
	_qte_refresh()


func close_all() -> void:
	for w in wins.duplicate():
		close(w, false)


# ------------------------------------------------------------------ Construction des fenêtres

func _build(kind: String) -> Control:
	var title := "Publicité"
	var body := ""
	var extra := 0.0   # place sous le texte (boutons, captcha)
	match kind:
		"ad", "tiny", "flee", "trap":
			var ad: Array = ADS.pick_random()
			title = ad[0]
			body = ad[1]
			extra = 20.0 if kind == "trap" else 0.0
		"memory":
			title = "Système"
			body = "Mémoire pleine : supprimer 3 de tes amulettes ?"
			extra = 20.0
		"honest":
			title = "Offre honnête"
			body = "Vraie récompense, sans piège : clique ICI."
			extra = 20.0
		"door":
			title = "Information"
			body = "Quelqu'un frappe à ta porte ? Ce n'est pas nous."
		"c_spots":
			title = "Vérification"
			body = "Clique sur toutes les cases qui contiennent une TACHE."
			extra = 56.0
		"c_round":
			title = "Vérification"
			body = "Prouve que tu es un artiste : clique sur le rond."
			extra = 26.0
	# hauteur selon la longueur du texte (~19 caractères par ligne dans cette police, 13 px par ligne)
	var lines := ceili(body.length() / 19.0)
	var text_h := lines * 13.0
	var ty := 16.0 + text_h + 2.0   # là où commence ce qu'il y a sous le texte
	var h := ty + extra + 4.0
	var w := UI.panel(Color("ece6d2"), Color("2b3350"), 2)
	w.size = Vector2(W, h)
	w.mouse_filter = MOUSE_FILTER_STOP
	w.set_meta("kind", kind)
	var bar := ColorRect.new()
	bar.color = Color("46548c")
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	UI.put(w, bar, Vector2(2, 2), Vector2(W - 4, 11))
	var tl := UI.label(title, 10, Color.WHITE)
	tl.mouse_filter = MOUSE_FILTER_IGNORE
	UI.put(w, tl, Vector2(5, 1), Vector2(W - 24, 12))
	var bl := UI.label(body, 10, Color("1a1423"))
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.mouse_filter = MOUSE_FILTER_IGNORE
	UI.put(w, bl, Vector2(5, 15), Vector2(W - 10, text_h + 2.0))
	w.set_meta("flee", 3 if kind == "flee" else 0)
	if kind.begins_with("c_"):
		# une énigme n'a PAS de croix : il faut la résoudre pour la fermer (manette : le QTE)
		match kind:
			"c_spots":
				_spots(w, ty)
			"c_round":
				_round(w, ty)
		return w
	# la croix : normale, minuscule, ou qui fuit la souris
	var small := kind in ["tiny", "trap"]
	var x := Button.new()
	x.text = "" if small else "x"
	x.focus_mode = FOCUS_NONE
	x.add_theme_font_size_override("font_size", 1 if small else UI.fs(10))   # (police de 1 px : sinon le bouton ne peut pas être minuscule)
	x.add_theme_stylebox_override("normal", UI.sb(Color("e84a4a"), Color("1a1423"), 1, 0, 0))
	x.add_theme_stylebox_override("hover", UI.sb(Color("ff7a6a"), Color("1a1423"), 1, 0, 0))
	x.add_theme_stylebox_override("pressed", UI.sb(Color("b82a2a"), Color("1a1423"), 1, 0, 0))
	x.pressed.connect(func(): close(w))
	var xs := Vector2(5, 5) if small else Vector2(11, 9)
	w.add_child(x)   # (pas UI.put : il regonflerait la police, donc la croix minuscule)
	x.position = Vector2(W - 3 - xs.x, 3)
	x.size = xs
	w.set_meta("x", x)
	match kind:
		"trap":
			# le gros bouton FERMER est un piège : il ouvre deux fenêtres de plus
			UI.put(w, _btn("FERMER", _trap.bind(w)), Vector2((W - 80.0) / 2.0, ty), Vector2(80, 16))
		"memory":
			# du bluff : « Accepter » ne supprime rien, ça ferme juste la fenêtre
			UI.put(w, _btn("Accepter", func(): close(w)), Vector2((W - 70.0) / 2.0, ty), Vector2(70, 15))
		"honest":
			UI.put(w, _btn("ICI", _honest.bind(w)), Vector2((W - 50.0) / 2.0, ty), Vector2(50, 15))
	return w


func _trap(w: Control) -> void:
	close(w, false)
	spawn("ad")
	spawn("ad")


func _honest(w: Control) -> void:
	var g := 5 + Run.wave
	Run.gold += g
	if arena:
		arena.float_text(arena.player.position + Vector2(0, -28), "+● %d (pub honnête !)" % g, Pal.ACCENT)
	Sfx.play("coin")
	close(w)


## Une forme pleine posée sur un bouton : un carré, ou un rond (coins arrondis au maximum).
func _shape(b: Button, round: bool, col: Color, px: float) -> Panel:
	var sh := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	if round:
		sb.set_corner_radius_all(int(px))
	sh.add_theme_stylebox_override("panel", sb)
	sh.mouse_filter = MOUSE_FILTER_IGNORE
	sh.size = Vector2(px, px)
	sh.position = (b.size - Vector2(px, px)) / 2.0
	b.add_child(sh)
	return sh


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = FOCUS_NONE
	b.add_theme_font_size_override("font_size", UI.fs(10))
	b.add_theme_color_override("font_color", Color("1a1423"))
	b.add_theme_color_override("font_hover_color", Color("1a1423"))
	b.add_theme_stylebox_override("normal", UI.sb(Color("d7d0b8"), Color("2b3350"), 1, 2, 0))
	b.add_theme_stylebox_override("hover", UI.sb(Color("f4efe2"), Color("2b3350"), 1, 2, 0))
	b.add_theme_stylebox_override("pressed", UI.sb(Color("b9b29a"), Color("2b3350"), 1, 2, 0))
	b.pressed.connect(cb)
	return b


## Captcha « clique sur toutes les cases qui contiennent une tache » : 3 × 3 cases, 3 ou 4 taches.
## Une case vide cliquée : tout est à refaire.
func _spots(w: Control, ty: float) -> void:
	var cells := []
	var spots := {}
	var order := range(9)
	order.shuffle()
	for k in randi_range(3, 4):
		spots[order[k]] = true
	var found := {}
	for i in 9:
		var c := _btn("", func(): pass)
		cells.append(c)
		UI.put(w, c, Vector2((W - 49.0) / 2.0 + (i % 3) * 17, ty + (i / 3) * 17), Vector2(15, 15))
		if spots.has(i):
			_shape(c, true, Color("1a1423"), 9.0)   # la tache
	for i in 9:
		var idx: int = i
		(cells[i] as Button).pressed.connect(func():
			if spots.has(idx):
				found[idx] = true
				(cells[idx] as Button).add_theme_stylebox_override("normal", UI.sb(Color("8fd98a"), Color("2b3350"), 1, 2, 0))
				if found.size() == spots.size():
					close(w)
			else:
				found.clear()
				for c in cells:
					(c as Button).add_theme_stylebox_override("normal", UI.sb(Color("d7d0b8"), Color("2b3350"), 1, 2, 0)))
	w.set_meta("spots", spots.keys())
	w.set_meta("cells", cells)


## Captcha « clique sur le rond » : il n'y a que des carrés... au bout de 2 s, l'un d'eux devient rond.
func _round(w: Control, ty: float) -> void:
	var btns := []
	var shapes := []
	for i in 4:
		var b := _btn("", func(): pass)
		btns.append(b)
		UI.put(w, b, Vector2((W - 88.0) / 2.0 + i * 23, ty), Vector2(19, 19))
		shapes.append(_shape(b, false, Color("1a1423"), 11.0))
	w.set_meta("round_t", 2.0)
	w.set_meta("round_btns", btns)
	w.set_meta("round_shapes", shapes)
	w.set_meta("round_i", randi() % 4)
	w.set_meta("round_ok", false)


# ------------------------------------------------------------------ Boucle

func _process(delta: float) -> void:
	var mouse := get_local_mouse_position()
	for w in wins:
		# la croix qui fuit : elle saute dans un autre coin quand la souris approche (3 fois)
		var flee: int = w.get_meta("flee")
		if flee > 0:
			var x: Button = w.get_meta("x")
			if (w.position + x.position + x.size / 2.0).distance_to(mouse) < 16.0:
				var corners := [Vector2(3, 3), Vector2(W - 14, 3), Vector2(3, w.size.y - 12), Vector2(W - 14, w.size.y - 12)]   # (les 4 coins)
				corners = corners.filter(func(c): return c.distance_to(x.position) > 4.0)
				x.position = corners.pick_random()
				w.set_meta("flee", flee - 1)
		# le rond qui apparaît
		if w.has_meta("round_t"):
			var rt: float = float(w.get_meta("round_t")) - delta
			w.set_meta("round_t", rt)
			if rt <= 0.0 and not w.has_meta("round_done"):
				w.set_meta("round_done", true)
				var ri := int(w.get_meta("round_i"))
				var rb: Button = (w.get_meta("round_btns") as Array)[ri]
				# le carré devient rond
				var sb2 := StyleBoxFlat.new()
				sb2.bg_color = Color("1a1423")
				sb2.set_corner_radius_all(11)
				((w.get_meta("round_shapes") as Array)[ri] as Panel).add_theme_stylebox_override("panel", sb2)
				w.set_meta("round_ok", true)
				var ww: Control = w
				rb.pressed.connect(func(): close(ww))


# ------------------------------------------------------------------ Manette : QTE de 3 touches

func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.5):
		if not pad:
			pad = true
			_qte_refresh()
	elif ev is InputEventMouseMotion or ev is InputEventMouseButton:
		if pad:
			pad = false
			_qte_refresh()
	if not pad or wins.is_empty() or not (ev is InputEventJoypadButton and ev.pressed):
		return
	var k := QTE_KEYS.find(ev.button_index)
	if k < 0:
		return
	var top: Control = wins.back()
	if not top.has_meta("qte"):
		return
	var seq: Array = top.get_meta("qte")
	var at: int = top.get_meta("qte_at")
	if k == int(seq[at]):
		at += 1
		if at >= seq.size():
			close(top)
			return
	else:
		at = 0   # une erreur : on recommence la suite
		Sfx.play("hurt")
	top.set_meta("qte_at", at)
	_qte_draw(top)


## À la manette, seule la fenêtre du dessus porte sa suite de 3 touches.
func _qte_refresh() -> void:
	for w in wins:
		if w.has_meta("qte_strip"):
			(w.get_meta("qte_strip") as Control).queue_free()
			w.remove_meta("qte_strip")
	if not pad or wins.is_empty():
		return
	var top: Control = wins.back()
	if not top.has_meta("qte"):
		top.set_meta("qte", [randi() % 4, randi() % 4, randi() % 4])
		top.set_meta("qte_at", 0)
	_qte_draw(top)


func _qte_draw(w: Control) -> void:
	if w.has_meta("qte_strip"):
		(w.get_meta("qte_strip") as Control).queue_free()
	var strip := UI.panel(Color("1a1423"), Pal.ACCENT, 1)
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	UI.put(w, strip, Vector2((W - 62.0) / 2.0, w.size.y - 9.0), Vector2(62, 18))
	var seq: Array = w.get_meta("qte")
	var at: int = w.get_meta("qte_at")
	for i in seq.size():
		var k := int(seq[i])
		var l := UI.label(QTE_NAMES[k], 10, QTE_COLS[k] if i >= at else Color(0.4, 0.4, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
		UI.put(strip, l, Vector2(4 + i * 19, 2), Vector2(16, 12))
	w.set_meta("qte_strip", strip)
