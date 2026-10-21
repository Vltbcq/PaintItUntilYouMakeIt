class_name Tips
extends RefCounted
## Conseils : chacun n'apparaît qu'une fois. Il n'en reste que deux (fin de partie, Atelier) ;
## le réglage « tips » n'est plus dans les options (les tests s'en servent pour les couper).

static var TEXT := {
	"end": ["Fin de partie",
		"Tu gagnes des PIGMENTS ◆ à chaque partie, même en perdant.\n\nDépense-les dans l'ATELIER (menu principal) : nouvelles couleurs, plus d'encre, outils de dessin, effets animés..."],
	"atelier": ["L'Atelier",
		"Ici tu débloques des choses pour tes prochaines parties.\nConseil : commence par le PACK PRIMAIRE (rouge, bleu, jaune) : les couleurs ouvrent les éléments et les synergies."],
}


static func enabled() -> bool:
	return bool(Meta.setting("tips"))


static func seen(id: String) -> bool:
	return bool(Meta.data.get("tips_seen", {}).get(id, false))


static func mark(id: String) -> void:
	if not Meta.data.has("tips_seen"):
		Meta.data.tips_seen = {}
	Meta.data.tips_seen[id] = true
	Meta.save()


## Affiche un conseil (une seule fois) par-dessus `parent`. Plusieurs conseils s'enchaînent.
## pause_game : met le jeu en pause pendant la lecture (pendant une vague).
static func show(parent: Control, id: String, pause_game := false) -> void:
	if not enabled() or seen(id) or not TEXT.has(id):
		return
	var q: _TipOverlay = parent.get_node_or_null("TipOverlay")
	if q == null:
		q = _TipOverlay.new()
		q.name = "TipOverlay"
		q.pause_game = pause_game
		q.queue_tip(id)          # AVANT add_child : _ready affiche le premier conseil
		parent.add_child(q)
	else:
		q.queue_tip(id)


class _TipOverlay extends Control:
	var queue: Array[String] = []
	var pause_game := false
	var box: Control

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		# Taille de l'écran entier, quel que soit le parent : le conseil bloque TOUS les clics derrière lui
		position = Vector2.ZERO
		size = get_viewport_rect().size
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS
		z_index = 100
		if pause_game:
			get_tree().paused = true
		_next()

	## Les raccourcis clavier de l'écran derrière (chiffres de la boutique...) sont bloqués ;
	## seuls ceux du conseil (Compris !) passent, car ils sont traités avant.
	func _shortcut_input(ev: InputEvent) -> void:
		if ev is InputEventKey:
			get_viewport().set_input_as_handled()

	func _unhandled_input(ev: InputEvent) -> void:
		if ev is InputEventKey:
			get_viewport().set_input_as_handled()

	func queue_tip(id: String) -> void:
		if id in queue:
			return
		queue.append(id)
		if is_inside_tree() and box == null:
			_next()

	func _next() -> void:
		if box:
			box.queue_free()
			box = null
		if queue.is_empty():
			if pause_game:
				get_tree().paused = false
			queue_free()
			return
		var id: String = queue.pop_front()
		Tips.mark(id)
		box = Control.new()
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(box)
		UI.fill_bg(box, Color(0, 0, 0, 0.55))
		var t: Array = Tips.TEXT[id]
		var body := UI.label(t[1], 10, Pal.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var w := 420.0
		body.custom_minimum_size = Vector2(w - 28, 0)
		# Hauteur réelle du texte avec la police pixel (+ interligne), pour que rien ne déborde
		var ts := UI.font.get_multiline_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, w - 28, UI.fs(10))
		var lines := String(t[1]).count("\n") + 1 + int(ts.x > w - 28)
		var text_h := ts.y + lines * 2.0 + 10.0
		var h := minf(340.0, 90.0 + text_h)
		var p := UI.panel(Pal.BG, Pal.ACCENT, 2)
		UI.put(box, p, Vector2((640 - w) / 2.0, (360 - h) / 2.0), Vector2(w, h))
		UI.put(p, UI.label(Loc.t("CONSEIL"), 10, Pal.DIM), Vector2(14, 8))
		UI.put(p, UI.label(t[0], 20, Pal.ACCENT), Vector2(14, 20), Vector2(w - 28, 24))
		UI.put(p, body, Vector2(14, 50), Vector2(w - 28, h - 96))
		var ok := UI.hotkey(UI.button(Loc.t("Compris !"), _next), [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE])
		UI.put(p, ok, Vector2(w - 124, h - 30), Vector2(110, 20))
		var off := UI.button(Loc.t("Plus de conseils"), func():
			Meta.set_setting("tips", false)
			queue.clear()
			_next())
		off.tooltip_text = Loc.t("Réactivables dans les options")
		UI.put(p, off, Vector2(14, h - 28), Vector2(120, 16))
		Sfx.play("click")
