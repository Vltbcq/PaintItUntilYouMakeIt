class_name AtelierScreen
extends Control
## L'ATELIER du peintre (améliorations permanentes) :
## - à gauche, l'ÉTABLI : encre et boutique, achetés avec les pigments (des pots sur une étagère) ;
## - à droite, le TABLEAU EN LIÈGE : les DÉFIS épinglés (rangés A→Z), chacun débloque couleurs, outils ou effets.

signal done(result)

const PLANK := Color("6b4428")
const PLANK_DARK := Color("54341d")
const PLANK_LINE := Color("3b2413")
const CORK := Color("b98a55")
const CORK_DOT := Color("a0733f")
const NOTE := Color("f3e9cf")
const NOTE_DONE := Color("dcefcf")
const PIN_ON := Color("4caf50")
const PIN_OFF := Color("d2433a")
## Couleur du pot de chaque amélioration achetable
const POT := {"ink": Color("1a1423"), "canvas": Color("e9dcbc"), "shop_slot": Color("d6ab4f"),
	"free_reroll": Color("3a86ff"), "start_gold": Color("f0c43a")}


var scroll_mem := {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	Meta.atelier_visited()   # (le bouton Atelier du titre arrête de briller)
	_build()
	(func(): Tips.show(self, "atelier")).call_deferred()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var bg := _Workshop.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Enseigne + bocal de pigments
	var sign := UI.panel(UI.WOOD, UI.GOLD, 2)
	UI.put(self, sign, Vector2(12, 6), Vector2(150, 28))
	UI.put(sign, UI.label(Loc.t("ATELIER"), 20, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 2), Vector2(150, 24))
	var jar := UI.panel(Color(0.9, 0.95, 1.0, 0.18), Color(0.85, 0.9, 1.0, 0.6), 1)
	UI.put(self, jar, Vector2(470, 6), Vector2(158, 28))
	UI.put(jar, UI.label(Loc.t("◆ %d pigments") % Meta.pigments(), 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 8), Vector2(158, 14))

	_bench()
	_board()
	UI.put(self, UI.hotkey(UI.button(Loc.t("Retour"), func(): done.emit(null)), [KEY_ESCAPE]), Vector2(12, 336), Vector2(80, 18))


# ------------------------------------------------------------------ Établi (pigments)

func _bench() -> void:
	UI.put(self, UI.label(Loc.t("L'ÉTABLI"), 10, UI.GOLD), Vector2(14, 42))
	# L'établi défile quand il y a trop d'améliorations pour la hauteur de l'écran
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.put(self, sc, Vector2(12, 56), Vector2(300, 276))
	UI.keep_scroll(sc, scroll_mem, "etabli")   # (un achat reconstruit l'écran : l'établi ne remonte pas)
	var shelf := Control.new()
	sc.add_child(shelf)
	var y := 0.0
	for d in _bench_list():
		# La carte prend la hauteur de sa description (rien ne dépasse)
		var dh := UI.font.get_multiline_string_size(d.desc, HORIZONTAL_ALIGNMENT_LEFT, 160, UI.fs(10)).y
		var chh := maxf(50.0, 22.0 + dh)
		var card := UI.panel(Color(0, 0, 0, 0.22), Color(0, 0, 0, 0), 0)
		UI.put(shelf, card, Vector2(0, y), Vector2(288, chh))
		var pot := _Pot.new()
		pot.col = _pot_color(d.id)
		pot.fill = float(Meta.level(d.id)) / float(d.cost.size())
		UI.put(card, pot, Vector2(6, 6), Vector2(30, 38))
		var lv := Meta.level(d.id)
		var mx: int = d.cost.size()
		UI.put(card, UI.label(d.name + ("  %d/%d" % [lv, mx] if mx > 1 else ""), 10, Pal.ACCENT if lv > 0 else Pal.TEXT), Vector2(42, 4), Vector2(170, 12))
		var ds := UI.label(d.desc, 10, Pal.DIM)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.put(card, ds, Vector2(42, 18), Vector2(164, dh))
		var cost := Meta.next_cost(d.id)
		var id: String = d.id
		var b: Button
		if cost < 0:
			b = UI.button(Loc.t("Acquis"), func(): pass)
			b.disabled = true
		elif not Meta.buy_open(id):
			b = UI.button(Loc.t("Verrouillé"), func(): pass)
			b.disabled = true
			b.tooltip_text = _lock_reason(d)
		else:
			b = UI.button("◆ %d" % cost, func():
				if Meta.buy(id):
					Sfx.play("buy")
					_build())
			b.disabled = Meta.pigments() < cost
		UI.put(card, b, Vector2(210, (chh - 18.0) / 2.0), Vector2(72, 18))
		y += chh + 4.0
	shelf.custom_minimum_size = Vector2(288, y)


## Couleur du bocal d'un objet de l'établi : une teinte différente pour chacun (réparties sur tout
## le cercle des couleurs, dans l'ordre du catalogue), sauf les quelques bocaux qui ont la leur.
func _pot_color(id: String) -> Color:
	if POT.has(id):
		return POT[id]
	var others := UnlockDB.LIST.filter(func(u): return not POT.has(u.id))
	for i in others.size():
		if others[i].id == id:
			# (pas de jaune doré ni de bleu vif : ce sont les bocaux de la boutique et de la relance)
			return Color.from_hsv(fmod(0.02 + float(i) / others.size(), 1.0), 0.62 if i % 2 == 0 else 0.42, 0.95 if i % 2 == 0 else 0.78)
	return Pal.ACCENT


## Pourquoi une amélioration de l'établi n'est pas encore achetable.
func _lock_reason(d: Dictionary) -> String:
	var why := []
	if int(Meta.data.get("best_wave", 0)) < int(d.get("best_wave", 0)):
		why.append(Loc.t("Termine la vague %d (une fois suffit).") % int(d.best_wave))
	if int(Meta.data.get("wins", 0)) < int(d.get("wins", 0)):
		why.append(Loc.t("Gagne une partie."))
	if d.has("req") and not Meta.has(String(d.req)):
		why.append(Loc.t("Achète d'abord : ") + UnlockDB.get_def(String(d.req)).name + ".")
	return "\n".join(why)


## Ce qui s'achète à l'établi, rangé par catégorie (dans l'ordre du catalogue) puis A→Z.
func _bench_list() -> Array:
	var cats := []
	for d in UnlockDB.LIST:
		if UnlockDB.for_pigments(d) and not d.cat in cats:
			cats.append(d.cat)
	var out := UnlockDB.LIST.filter(func(d): return UnlockDB.for_pigments(d))
	out.sort_custom(func(a, b):
		var ca := cats.find(a.cat)
		var cb := cats.find(b.cat)
		return ca < cb if ca != cb else CodexScreen._order(0, a.name) < CodexScreen._order(0, b.name))
	return out


# ------------------------------------------------------------------ Tableau des défis

func _board() -> void:
	var frame := UI.panel(CORK, UI.WOOD, 4)
	UI.put(self, frame, Vector2(318, 40), Vector2(310, 290))
	var cork := _Cork.new()
	cork.set_anchors_preset(PRESET_FULL_RECT)
	cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(cork)
	var done_n := 0
	for a in AchievementDB.LIST:
		if Meta.achieved(a.id):
			done_n += 1
	UI.put(frame, UI.label(Loc.t("DÉFIS  %d / %d") % [done_n, AchievementDB.LIST.size()], 10, UI.WOOD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(310, 12))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.put(frame, sc, Vector2(6, 22), Vector2(298, 262))
	UI.keep_scroll(sc, scroll_mem, "succes")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	var i := 0
	var defis := AchievementDB.LIST.duplicate()
	defis.sort_custom(func(a, b): return CodexScreen._order(0, a.name) < CodexScreen._order(0, b.name))   # A→Z
	for a in defis:
		grid.add_child(_note(a, i))
		i += 1


func _note(a: Dictionary, i: int) -> Control:
	var ok := Meta.achieved(a.id)
	var reward: String = UnlockDB.get_def(a.unlock).name
	var wait := ok and Meta.pending(a.id)   # obtenu pendant la partie en cours : arrive à la fin
	var line := ("⌛ " + reward + Loc.t(" (fin de partie)")) if wait else (("✓ " if ok else "→ ") + reward)
	# La note prend la hauteur de son texte (rien ne dépasse ; le tableau défile)
	var mh := func(t: String) -> float: return UI.font.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, 126, UI.fs(10)).y
	var nh: float = mh.call(a.name)
	var dh: float = mh.call(a.desc)
	var lh: float = mh.call(line)
	var hh := 6.0 + nh + dh + lh + 4.0
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(142, hh + 6.0)
	var n := UI.panel(NOTE_DONE if ok else NOTE, Color(0, 0, 0, 0.25), 1)
	n.position = Vector2(2, 4)
	n.size = Vector2(138, hh)
	n.pivot_offset = n.size / 2.0
	n.rotation = deg_to_rad([-1.5, 1.0, 0.5, -1.0, 1.5, -0.5][i % 6])   # notes épinglées un peu de travers
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(n)
	var nl := UI.label(a.name, 10, Pal.INK)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.put(n, nl, Vector2(6, 4), Vector2(126, nh))
	var ds := UI.label(a.desc, 10, Color("5a4a3a"))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.put(n, ds, Vector2(6, 4 + nh), Vector2(126, dh))
	var rl := UI.label(line, 10, Color("b06a10") if wait else (Color("2e7d32") if ok else Color("8a5a2b")))
	rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.put(n, rl, Vector2(6, 4 + nh + dh + 2), Vector2(126, lh))
	var pin := _Pin.new()
	pin.col = Color("f0a030") if wait else (PIN_ON if ok else PIN_OFF)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(holder, pin, Vector2(64, 0), Vector2(12, 12))
	holder.tooltip_text = Loc.t("%s\n%s\nDébloque : %s\n%s") % [a.name, a.desc, reward, UnlockDB.get_def(a.unlock).desc]   # (lignes courtes : l'infobulle tient dans l'écran)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	return holder


# ------------------------------------------------------------------ Décor

## Mur de planches, étagère, sol en bois taché de peinture.
class _Workshop extends Control:
	func _draw() -> void:
		var s := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, s), AtelierScreen.PLANK)
		var x := 0
		var k := 0
		while x < s.x:
			var w := 22 + (k * 7) % 9
			draw_rect(Rect2(x, 0, w, s.y), AtelierScreen.PLANK if k % 2 == 0 else AtelierScreen.PLANK_DARK)
			draw_line(Vector2(x, 0), Vector2(x, s.y), AtelierScreen.PLANK_LINE, 1.0)
			draw_circle(Vector2(x + w / 2.0, 22 + (k * 37) % 30), 1.0, AtelierScreen.PLANK_LINE)   # clous
			x += w
			k += 1
		# Étagère sous l'établi + sol
		draw_rect(Rect2(8, 330, 304, 4), UI.WOOD)
		draw_rect(Rect2(0, s.y - 14, s.x, 14), UI.FLOOR)
		for i in range(0, int(s.x), 40):
			draw_line(Vector2(i, s.y - 14), Vector2(i, s.y), Color(0, 0, 0, 0.2), 1.0)
		# Taches de peinture sur le sol
		var cols := [Color("d2433a"), Color("3a86ff"), Color("f0c43a"), Color("4caf50"), Color("c071f0")]
		for i in 9:
			var p := Vector2(110 + i * 58 + (i * 13) % 20, s.y - 7 + (i % 3) - 1)
			draw_circle(p, 2.0 + (i % 3), Color(cols[i % cols.size()], 0.8))


class _Cork extends Control:
	func _draw() -> void:
		if size.x < 2.0 or size.y < 2.0:
			return
		for i in 140:
			var p := Vector2((i * 53) % int(size.x), (i * 97) % int(size.y))
			draw_rect(Rect2(p, Vector2(1, 1)), AtelierScreen.CORK_DOT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Pot de peinture : se remplit avec le niveau de l'amélioration.
class _Pot extends Control:
	var col := Color.WHITE
	var fill := 0.0

	func _draw() -> void:
		var body := Rect2(3, 8, size.x - 6, size.y - 8)
		draw_rect(body, Color(1, 1, 1, 0.18))
		var h := (body.size.y - 2) * clampf(fill, 0.0, 1.0)
		draw_rect(Rect2(body.position.x + 1, body.end.y - 1 - h, body.size.x - 2, h), col)
		draw_rect(body, Color(0.9, 0.95, 1.0, 0.7), false, 1.0)
		draw_rect(Rect2(1, 3, size.x - 2, 5), UI.GOLD_DARK)   # couvercle
		draw_rect(Rect2(6, 10, 2, body.size.y - 6), Color(1, 1, 1, 0.35))   # reflet


class _Pin extends Control:
	var col := Color.RED

	func _draw() -> void:
		draw_circle(size / 2.0 + Vector2(1, 1), 4.0, Color(0, 0, 0, 0.3))
		draw_circle(size / 2.0, 4.0, col)
		draw_circle(size / 2.0 - Vector2(1.5, 1.5), 1.2, Color(1, 1, 1, 0.7))
