extends Node
## Manette. Le jeu est fait pour la souris : plutôt que de refaire chaque écran, la manette pilote
## un CURSEUR qui se comporte exactement comme elle (survol, clic, clic maintenu, molette).
## Tout écran, présent ou futur, marche donc à la manette sans rien ajouter.
##
## Dans les menus, la boutique, la toile...
##   stick gauche : déplacer le curseur (LT : lentement, RT : vite) · croix : pas à pas (1 pixel sur la toile)
##   A : clic gauche (maintenu : dessiner, glisser) · X : clic droit (gommer) · B : Échap (retour)
##   Y : Entrée (valider) · LB / RB : molette (sur la toile : défaire / refaire ; en posant ou
##   rangeant une arme / amulette : tourner / miroir)
##   stick droit : molette (faire défiler)
## En combat (vague en cours, pas en pause) : pas de curseur, le stick déplace le perso (player.gd),
##   LB / RB et le stick droit zooment, Start met en pause (hud.gd).
##
## Le curseur est le même à la souris et à la manette : une flèche dorée bordée d'encre (cursor_image),
## posée comme curseur de la souris à l'échelle de la fenêtre, et dessinée par le jeu à la manette.
##
## La manette prend la main dès qu'on y touche ; bouger la vraie souris la lui reprend.
## Tant qu'elle a la main, les indications de touches affichées (« Échap : pause », « Défaire
## (Ctrl+Z) »...) sont remplacées par celles de la manette : voir keys() et txt().

const SPEED := 240.0          # px/s (écran de 640×360), stick à fond
const SLOW := 0.3             # LT
const FAST := 2.2             # RT
const DEAD := 0.22
const REPEAT_FIRST := 0.28    # croix maintenue : délai avant répétition, puis cadence
const REPEAT_NEXT := 0.07
const WHEEL_EVERY := 0.09     # stick droit : un cran de molette toutes les...
const IDLE_HIDE_MS := 2000    # pendant une vague, la souris immobile aussi longtemps cache son curseur

var active := false           # la manette a la main
var pos := Vector2(320, 180)  # le curseur (coordonnées de l'écran 640×360)
var canvas: CanvasView        # la toile de dessin à l'écran (elle s'inscrit elle-même), sinon null

var _axes := {}
var _held := {}               # boutons de la manette enfoncés
var mouse_hidden := false    # le curseur de la souris est caché (vague en cours, souris immobile)
var _mouse_mask := 0
var _mouse_ms := 0            # dernière fois que la vraie souris a bougé ou cliqué
var _repeat_t := 0.0
var _wheel_t := 0.0
var _swaps := {}              # texte clavier (dans la langue du jeu) -> texte manette
var _swaps_lang := "?"
var _tip_t := 0.0
var _layer: CanvasLayer
var _cursor: Control
var _cursor_tex: ImageTexture   # la flèche, 1 pixel du jeu = 1 pixel d'image
var _cursor_scale := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_cursor = Control.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	_layer.add_child(_cursor)
	_cursor_tex = ImageTexture.create_from_image(cursor_image())
	_show(false)
	# La souris porte la même flèche, agrandie comme le jeu l'est dans la fenêtre
	if DisplayServer.get_name() != "headless":
		get_window().size_changed.connect(_mouse_cursor)
		_mouse_cursor()


## Une vague est en cours et le jeu tourne : la manette joue, elle ne pointe pas.
func in_play() -> bool:
	if get_tree().paused:
		return false
	var a := get_tree().get_first_node_in_group("arena")
	return a != null and a.is_inside_tree() and not a.is_queued_for_deletion()


func _show(on: bool) -> void:
	_cursor.visible = on


func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	if on:
		_tip_t = 0.0
	else:
		_release_mouse()
		_restore_tips()
		_show(false)


func _input(ev: InputEvent) -> void:
	if ev is InputEventJoypadMotion:
		_axes[ev.axis] = ev.axis_value
		if absf(ev.axis_value) > 0.5:
			_set_active(true)
	elif ev is InputEventJoypadButton:
		_set_active(true)
		if ev.pressed:
			_held[ev.button_index] = true
			_press(ev.button_index)
		else:
			_held.erase(ev.button_index)
			_release(ev.button_index)
	elif ev is InputEventMouse and not ev.has_meta("pad"):
		# la vraie souris : elle reprend la main (un simple tremblement ne compte pas)
		if ev is InputEventMouseButton or (ev as InputEventMouseMotion).relative.length() > 1.5:
			pos = (ev as InputEventMouse).position
			_mouse_ms = Time.get_ticks_msec()
			_set_active(false)


func _process(delta: float) -> void:
	if not active:
		# Souris : pendant une vague, son curseur disparaît si on n'y touche pas (il gêne la vue),
		# et revient au moindre mouvement. Hors vague, il est toujours là.
		mouse_hidden = in_play() and Time.get_ticks_msec() - _mouse_ms > IDLE_HIDE_MS
		var mode := Input.MOUSE_MODE_HIDDEN if mouse_hidden else Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != mode:
			Input.mouse_mode = mode
		return
	var play := in_play()
	_show(not play)
	# Stick droit : molette (zoom en combat, défilement ailleurs)
	var ry := float(_axes.get(JOY_AXIS_RIGHT_Y, 0.0))
	_wheel_t -= delta
	if absf(ry) > 0.5 and _wheel_t <= 0.0:
		_wheel_t = WHEEL_EVERY / absf(ry)
		_wheel(ry < 0.0)
	if play:
		_release_mouse()
		return
	# Stick gauche : le curseur
	var v := Vector2(float(_axes.get(JOY_AXIS_LEFT_X, 0.0)), float(_axes.get(JOY_AXIS_LEFT_Y, 0.0)))
	if v.length() > DEAD:
		var k := (v.length() - DEAD) / (1.0 - DEAD)
		var sp := SPEED * k * k
		sp *= lerpf(1.0, SLOW, clampf(float(_axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0)), 0.0, 1.0))
		sp *= lerpf(1.0, FAST, clampf(float(_axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0)), 0.0, 1.0))
		_move_to(pos + v.normalized() * sp * delta)
	# Croix : pas à pas, répété si on la maintient
	var d := _dpad()
	if d != Vector2i.ZERO:
		_repeat_t -= delta
		if _repeat_t <= 0.0:
			_repeat_t = REPEAT_NEXT
			_step(d)
	_cursor.queue_redraw()
	# Indications de touches et infobulles : celles du clavier laissent la place à celles de la manette
	_tip_t -= delta
	if _tip_t <= 0.0:
		_tip_t = 0.5
		_pad_tips(get_tree().root)


# ------------------------------------------------------------------ Boutons

func _press(b: int) -> void:
	if in_play():
		if b == JOY_BUTTON_LEFT_SHOULDER or b == JOY_BUTTON_RIGHT_SHOULDER:
			_wheel(b == JOY_BUTTON_RIGHT_SHOULDER)   # zoom
		return
	match b:
		JOY_BUTTON_A:
			_mouse(MOUSE_BUTTON_LEFT, true)
		JOY_BUTTON_X:
			_mouse(MOUSE_BUTTON_RIGHT, true)
		JOY_BUTTON_B:
			_key(KEY_ESCAPE)
		JOY_BUTTON_Y:
			_key(KEY_ENTER)
		JOY_BUTTON_START:
			# (en pause, c'est le HUD qui reprend la partie : pas de double Échap)
			if get_tree().get_first_node_in_group("arena") == null:
				_key(KEY_ESCAPE)
		JOY_BUTTON_LEFT_SHOULDER:
			if is_instance_valid(canvas):
				_key(KEY_Z, true)
			elif turning():
				_key(KEY_R)
			else:
				_wheel(true)
		JOY_BUTTON_RIGHT_SHOULDER:
			if is_instance_valid(canvas):
				_key(KEY_Y, true)
			elif turning():
				_key(KEY_M)
			else:
				_wheel(false)
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			_step(_dpad())
			_repeat_t = REPEAT_FIRST


func _release(b: int) -> void:
	if b == JOY_BUTTON_A:
		_mouse(MOUSE_BUTTON_LEFT, false)
	elif b == JOY_BUTTON_X:
		_mouse(MOUSE_BUTTON_RIGHT, false)


func _dpad() -> Vector2i:
	return Vector2i(int(_held.has(JOY_BUTTON_DPAD_RIGHT)) - int(_held.has(JOY_BUTTON_DPAD_LEFT)),
		int(_held.has(JOY_BUTTON_DPAD_DOWN)) - int(_held.has(JOY_BUTTON_DPAD_UP)))


## Un pas de croix : une case de la toile si le curseur est dessus, sinon quelques pixels.
func _step(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	if is_instance_valid(canvas) and canvas.is_visible_in_tree():
		var to = canvas.pad_step(pos, d)
		if to != null:
			_move_to(to)
			return
	_move_to(pos + Vector2(d) * 6.0)


# ------------------------------------------------------------------ Faux événements de souris et de clavier

func _move_to(p: Vector2) -> void:
	var size := get_viewport().get_visible_rect().size
	p = p.clamp(Vector2.ZERO, size - Vector2.ONE)
	var ev := InputEventMouseMotion.new()
	ev.relative = p - pos
	ev.position = p
	ev.global_position = p
	ev.button_mask = _mouse_mask
	ev.set_meta("pad", true)
	pos = p
	get_viewport().push_input(ev, true)


func _mouse(button: int, pressed: bool) -> void:
	var bit := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	if pressed == ((_mouse_mask & bit) != 0):
		return
	_mouse_mask = (_mouse_mask | bit) if pressed else (_mouse_mask & ~bit)
	if pressed:
		_move_to(pos)   # (le survol est à jour avant le clic, même si le curseur n'a pas bougé)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = _mouse_mask
	ev.set_meta("pad", true)
	get_viewport().push_input(ev, true)


func _release_mouse() -> void:
	if _mouse_mask & MOUSE_BUTTON_MASK_LEFT:
		_mouse(MOUSE_BUTTON_LEFT, false)
	if _mouse_mask & MOUSE_BUTTON_MASK_RIGHT:
		_mouse(MOUSE_BUTTON_RIGHT, false)


func _wheel(up: bool) -> void:
	var at := get_viewport().get_visible_rect().size / 2.0 if in_play() else pos
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		ev.pressed = pressed
		ev.factor = 1.0
		ev.position = at
		ev.global_position = at
		ev.set_meta("pad", true)
		get_viewport().push_input(ev, true)


func _key(code: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.ctrl_pressed = ctrl
		ev.pressed = pressed
		get_viewport().push_input(ev)


# ------------------------------------------------------------------ Indications de touches

## [indication clavier / souris, la même à la manette] ("" : rien à dire à la manette).
## Tout texte AFFICHÉ égal à la première est remplacé par la seconde tant que la manette a la main.
static var KEYS := [
	[Loc.t("Échap : pause"), Loc.t("Start : pause")],
	[Loc.t("Molette / + - : zoom"), Loc.t("LB / RB : zoom")],
	[Loc.t("(en jeu : molette ou + / -)"), Loc.t("(en jeu : LB / RB)")],
	[Loc.t("Défaire (Ctrl+Z)"), Loc.t("Défaire (LB)")],
	[Loc.t("Refaire (Ctrl+Y)"), Loc.t("Refaire (RB)")],
	[Loc.t("Tout effacer (se défait avec Ctrl+Z)"), Loc.t("Tout effacer (se défait avec LB)")],
	[Loc.t("Contour noir autour du dessin en jeu (touche C)"), Loc.t("Contour noir autour du dessin en jeu")],
	[Loc.t("Contour noir quand tu réutilises ce dessin (touche C)"), Loc.t("Contour noir quand tu réutilises ce dessin")],
	[Loc.t("Touche V"), ""],
	[Loc.t("Tourner (R)"), Loc.t("Tourner (LB)")],   # (sur la toile, LB défait : voir keys())
	[Loc.t("Miroir (M)"), Loc.t("Miroir (RB)")],
	[Loc.t("Miroir (F)"), Loc.t("Miroir")],
	[Loc.t("Tout ce que tu as fait pendant la partie (J)"), Loc.t("Tout ce que tu as fait pendant la partie")],
	[Loc.t("Clique pour poser (clic droit pour reprendre).  R : tourner · M : miroir"), Loc.t("A : poser · X : reprendre · LB : tourner · RB : miroir")],
	[Loc.t("Clique pour poser · une fois posée, clique une ancienne amulette pour la décaler · R : tourner · M : miroir"), Loc.t("A : poser · une fois posée, A sur une ancienne amulette pour la décaler · LB : tourner · RB : miroir")],
	[Loc.t("Clique une arme ou une amulette pour la prendre, reclique pour la poser.  R : tourner · M : miroir (pose au repos)"), Loc.t("A sur une arme ou une amulette pour la prendre, A de nouveau pour la poser.  LB : tourner · RB : miroir")],
	[Loc.t("R : tourner · F : miroir · Suppr : effacer"), Loc.t("Tourner et Miroir : boutons à gauche · X : poser la sélection")],
	[Loc.t("Fais d'abord une sélection (outil S)"), Loc.t("Fais d'abord une sélection (outil Sélection)")],
	[Loc.t("Sélection (S) : trace un rectangle, glisse-le pour le déplacer,\nSuppr pour l'effacer, clic à côté (ou clic droit) pour le poser"), Loc.t("Sélection : trace un rectangle avec A, glisse-le pour le déplacer,\nX pour le poser")],
	[Loc.t("Symétrie haut / bas (H) : ce que tu dessines en haut se dessine aussi en bas"), Loc.t("Symétrie haut / bas : ce que tu dessines en haut se dessine aussi en bas")],
	[Loc.t("Dégradé (G) : chaque trait passe de la couleur de début à celle de fin,\nsur toute sa longueur (choisis-les avec les pastilles Début / Fin)"), Loc.t("Dégradé : chaque trait passe de la couleur de début à celle de fin,\nsur toute sa longueur (choisis-les avec les pastilles Début / Fin)")],
	[Loc.t("ATTRAPÉ ! SECOUE LES TOUCHES !"), Loc.t("ATTRAPÉ ! SECOUE LE STICK !")],
	[Loc.t("Clique « PaintIt » dans la barre des tâches (manette : un bouton)"), Loc.t("Appuie sur un bouton pour rouvrir le jeu")],
	[Loc.t("Clic : choisir cette couleur (en dégradé : pour la pastille active)"), Loc.t("A : choisir cette couleur (en dégradé : pour la pastille active)")],
]


## Un écran où l'on pose ou range une arme / amulette est affiché : LB tourne, RB retourne.
func turning() -> bool:
	for n in get_tree().get_nodes_in_group("pad_turn"):
		if n.is_inside_tree() and not n.is_queued_for_deletion() and (n as CanvasItem).is_visible_in_tree():
			return true
	return false


## Table clavier -> manette, dans la langue du jeu (et selon l'écran : sur la toile LB / RB défont
## et refont, donc « Tourner (R) » y perd juste sa lettre).
func keys() -> Dictionary:
	var ctx := Loc.lang + ("/toile" if is_instance_valid(canvas) else "")
	if _swaps_lang != ctx:
		_swaps_lang = ctx
		_swaps = {}
		for row in KEYS:
			_swaps[Loc.t(row[0])] = Loc.t(row[1])
		if is_instance_valid(canvas):
			_swaps[Loc.t("Tourner (R)")] = Loc.t("Tourner")
	return _swaps


## Pour les textes dessinés à la main (HUD, textes flottants) : la version manette si elle a la main.
func txt(s: String) -> String:
	return String(keys().get(s, s)) if active else s


## Les boutons qui ont un raccourci Entrée ou Échap l'annoncent avec le bouton de la manette.
func _pad_tips(n: Node) -> void:
	var k := keys()
	if (n is Label or n is Button) and k.has(n.text):
		n.set_meta("pad_text", [n.text, k[n.text]])
		n.text = k[n.text]
	if n is Control and k.has((n as Control).tooltip_text):
		n.set_meta("pad_tooltip", [(n as Control).tooltip_text, k[(n as Control).tooltip_text]])
		(n as Control).tooltip_text = k[(n as Control).tooltip_text]
	if n is Button and (n as Button).shortcut != null and not n.has_meta("pad_tip"):
		var b := n as Button
		n.set_meta("pad_tip", [b.tooltip_text, b.shortcut_in_tooltip])
		var tag := ""
		for ev in b.shortcut.events:
			if ev is InputEventKey and (ev.keycode == KEY_ENTER or ev.keycode == KEY_KP_ENTER):
				tag = "Y"
			elif ev is InputEventKey and ev.keycode == KEY_ESCAPE and tag == "":
				tag = "B"
		b.shortcut_in_tooltip = false
		if tag != "":
			b.tooltip_text = (b.tooltip_text + "  " if b.tooltip_text != "" else "") + "(%s)" % tag
	for c in n.get_children():
		_pad_tips(c)


func _restore_tips(n: Node = null) -> void:
	if n == null:
		n = get_tree().root
	# (seulement si le texte n'a pas été changé depuis par l'écran lui-même)
	if n.has_meta("pad_text"):
		var st: Array = n.get_meta("pad_text")
		if n.text == st[1]:
			n.text = st[0]
		n.remove_meta("pad_text")
	if n.has_meta("pad_tooltip"):
		var tt: Array = n.get_meta("pad_tooltip")
		if (n as Control).tooltip_text == tt[1]:
			(n as Control).tooltip_text = tt[0]
		n.remove_meta("pad_tooltip")
	if n is Button and n.has_meta("pad_tip"):
		var saved: Array = n.get_meta("pad_tip")
		(n as Button).tooltip_text = saved[0]
		(n as Button).shortcut_in_tooltip = saved[1]
		n.remove_meta("pad_tip")
	for c in n.get_children():
		_restore_tips(c)


## La flèche du curseur, dessinée pixel par pixel (# : bord d'encre, o : doré) : la flèche classique
## d'un pointeur, bord gauche droit et queue en biais. La pointe est en (0, 0) : c'est elle qui clique.
const CURSOR_ART := [
	"#.......",
	"##......",
	"#o#.....",
	"#oo#....",
	"#ooo#...",
	"#oooo#..",
	"#ooooo#.",
	"#oooooo#",
	"#oooo###",
	"#oo#oo#.",
	"#o#.#oo#",
	"##..#oo#",
	".....##.",
]


static func cursor_image() -> Image:
	var img := Image.create_empty(String(CURSOR_ART[0]).length(), CURSOR_ART.size(), false, Image.FORMAT_RGBA8)
	for y in CURSOR_ART.size():
		var row: String = CURSOR_ART[y]
		for x in row.length():
			if row[x] == "#":
				img.set_pixel(x, y, Pal.INK)
			elif row[x] == "o":
				img.set_pixel(x, y, Pal.ACCENT)
	return img


## Pose la flèche comme curseur de la souris (toutes les formes : flèche, main, croix de la toile).
func _mouse_cursor() -> void:
	var win := Vector2(get_window().size)
	var k := clampi(roundi(minf(win.x / 640.0, win.y / 360.0)), 1, 12)
	if k == _cursor_scale:
		return
	_cursor_scale = k
	var img := cursor_image()
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_CROSS, Input.CURSOR_IBEAM]:
		Input.set_custom_mouse_cursor(tex, shape, Vector2.ZERO)


func _draw_cursor() -> void:
	_cursor.draw_texture(_cursor_tex, pos.round())
