extends Node
## Thème pixel art global + petites fonctions pour construire l'interface en code.

## DA « galerie d'art » (la même que la boutique) : mur bordeaux rayé, boiseries, laiton, cartels.
const WALL := Color("5a2330")
const WALL_STRIPE := Color("50202b")
const GOLD := Color("d6ab4f")
const GOLD_DARK := Color("8c6414")
const WOOD := Color("3a2418")
const WOOD_PANEL := Color("4a2e1f")
const FLOOR := Color("6b4a2a")
const CARTEL := Color("efe6cf")
const SELECTED := Color("7a5214")   # onglet / choix sélectionné

## Police du jeu : Yoster Island (codeman38, libre dans un jeu), complétée par docs/yoster_glyphs.py.
var font: FontFile
var font_menu: FontFile   # (même police : gardé pour l'écran titre)
var theme: Theme

## Couleurs du logo : texte crème des boutons (« paint »), contour sombre des titres.
const BTN_TEXT := Color("e9dcbc")
const TITLE_OUTLINE := Color("2a1015")

## Yoster Island : ses pixels font 85/1024 de la taille, donc 12 ≈ 1 pixel de jeu (net), 24 = 2.
const MENU_FONT_PATH := "res://assets/fonts/YosterIsland.ttf"
const MENU_SIZE := 12
const MENU_BIG := 18   # 1,5 pixel de jeu par pixel de police (24 dépassait du menu)
const MENU_TITLE := 36   # 3 pixels de jeu par pixel de police
const MENU_MARGIN := 2   # marge verticale dans les boutons du menu


## Taille réelle pour une taille « historique » (10 = texte normal) : ×1,2, arrondie au demi-pixel
## de police (6) pour rester net.
func fs(size: int) -> int:
	return maxi(12, roundi(size * 1.2 / 6.0) * 6)


func _ready() -> void:
	font_menu = (load(MENU_FONT_PATH) as FontFile).duplicate()
	font_menu.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font_menu.hinting = TextServer.HINTING_NONE
	font_menu.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font_menu.generate_mipmaps = false
	font_menu.allow_system_fallback = false
	font_menu.fallbacks = [PixelFont.build()]   # au cas où un caractère manquerait encore
	font = font_menu
	theme = _build_theme()
	# Appliqué au thème par défaut : l'héritage de thème est coupé par les Node/CanvasLayer.
	var dt := ThemeDB.get_default_theme()
	dt.merge_with(theme)
	dt.default_font = font
	dt.default_font_size = fs(PixelFont.SIZE)
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = fs(PixelFont.SIZE)
	get_tree().root.theme = theme


func sb(bg: Color, border: Color = Color.TRANSPARENT, bw := 0, mx := 6, my := 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = false
	return s


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = fs(PixelFont.SIZE)

	t.set_stylebox("normal", Loc.t("Button"), _shadowed(sb(WOOD, GOLD_DARK, 1)))
	t.set_stylebox("hover", Loc.t("Button"), _shadowed(sb(WOOD_PANEL, GOLD, 1)))
	t.set_stylebox("pressed", Loc.t("Button"), sb(GOLD, GOLD, 1))
	t.set_stylebox("hover_pressed", Loc.t("Button"), sb(GOLD, GOLD, 1))
	t.set_stylebox("disabled", Loc.t("Button"), sb(Color("2a1a12"), Color("4a3524"), 1))
	t.set_stylebox("focus", Loc.t("Button"), StyleBoxEmpty.new())
	t.set_color("font_color", Loc.t("Button"), BTN_TEXT)
	t.set_color("font_hover_color", Loc.t("Button"), Pal.ACCENT)
	t.set_color("font_pressed_color", Loc.t("Button"), Pal.INK)
	t.set_color("font_hover_pressed_color", Loc.t("Button"), Pal.INK)
	t.set_color("font_focus_color", Loc.t("Button"), Pal.TEXT)
	t.set_color("font_disabled_color", Loc.t("Button"), Pal.DISABLED)

	t.set_color("font_color", Loc.t("Label"), Pal.TEXT)
	t.set_constant("line_spacing", Loc.t("Label"), 1)

	t.set_stylebox("panel", Loc.t("Panel"), _shadowed(sb(Pal.PANEL, Pal.BORDER, 2)))
	t.set_stylebox("panel", Loc.t("PanelContainer"), _shadowed(sb(Pal.PANEL, Pal.BORDER, 2, 6, 6)))

	t.set_stylebox("background", Loc.t("ProgressBar"), sb(Pal.INK, Pal.BORDER, 1, 0, 0))
	t.set_stylebox("fill", Loc.t("ProgressBar"), sb(Pal.ACCENT, Color.TRANSPARENT, 0, 0, 0))

	t.set_stylebox("panel", Loc.t("TooltipPanel"), sb(WOOD, GOLD, 1, 4, 3))
	t.set_color("font_color", Loc.t("TooltipLabel"), Pal.TEXT)

	t.set_stylebox("slider", Loc.t("HSlider"), sb(WOOD, GOLD_DARK, 1, 0, 3))
	t.set_stylebox("grabber_area", Loc.t("HSlider"), sb(GOLD_DARK, GOLD_DARK, 1, 0, 3))
	t.set_stylebox("grabber_area_highlight", Loc.t("HSlider"), sb(GOLD, GOLD, 1, 0, 3))
	for bar in [Loc.t("VScrollBar"), Loc.t("HScrollBar")]:
		t.set_stylebox("scroll", bar, sb(Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0, 2, 2))
		t.set_stylebox("grabber", bar, sb(GOLD_DARK))
		t.set_stylebox("grabber_highlight", bar, sb(Pal.ACCENT))
		t.set_stylebox("grabber_pressed", bar, sb(Pal.ACCENT))
	return t


## Petite ombre portée, comme les cadres accrochés au mur.
func _shadowed(s: StyleBoxFlat) -> StyleBoxFlat:
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 1
	s.shadow_offset = Vector2(1, 2)
	return s


# ------------------------------------------------------------------ Notification (succès...)

var _toasts: CanvasLayer


## Petit bandeau en haut de l'écran, par-dessus tout, qui disparaît tout seul.
func toast(text: String) -> void:
	if _toasts == null:
		_toasts = CanvasLayer.new()
		_toasts.layer = 50
		_toasts.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_toasts)
	var p := panel(WOOD, GOLD, 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _toasts.get_child_count()
	p.position = Vector2(170, 6 + n * 40)
	p.size = Vector2(300, 34)
	var l := label(text, 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, 4)
	l.size = Vector2(300, 28)
	p.add_child(l)
	_toasts.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ Helpers

func label(text: String, size := 10, color := Pal.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if size >= 20:
		# grands titres : contour sombre, comme les lettres du logo
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", TITLE_OUTLINE)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func button(text: String, cb: Callable, size := 10) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", fs(size))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


## Raccourci clavier sur un bouton (rappelé dans l'infobulle). Les chiffres utilisent la
## touche physique (1 à 9 marchent en AZERTY sans Maj) et le pavé numérique.
func hotkey(b: Button, keys: Array) -> Button:
	var evs := []
	for k in keys:
		var ev := InputEventKey.new()
		if k >= KEY_0 and k <= KEY_9:
			ev.physical_keycode = k
			var kp := InputEventKey.new()
			kp.keycode = KEY_KP_0 + (k - KEY_0)
			evs.append(kp)
		else:
			ev.keycode = k
		evs.append(ev)
	var sc := Shortcut.new()
	sc.events = evs
	b.shortcut = sc
	b.shortcut_in_tooltip = true
	return b


func panel(color := Pal.PANEL, border := Pal.BORDER, bw := 2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _shadowed(sb(color, border, bw)) if color.a >= 1.0 else sb(color, border, bw))
	return p


## Garde la position de défilement d'une liste qu'on reconstruit (clic sur un élément...) :
## elle est mémorisée dans store[key] et remise en place une fois la liste affichée.
func keep_scroll(sc: ScrollContainer, store: Dictionary, key: String) -> void:
	var v := int(store.get(key, 0))
	_restore_scroll(sc, v, store, key)


func _restore_scroll(sc: ScrollContainer, v: int, store: Dictionary, key: String) -> void:
	# Attendre que la liste ait sa taille (sinon le défilement est ramené à 0)
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(sc):
		return
	sc.scroll_vertical = v
	sc.get_v_scroll_bar().value_changed.connect(func(x: float): store[key] = int(x))


## Cartel de musée (papier crème, texte encre) : pour les textes posés sur le mur.
func cartel() -> Panel:
	return panel(CARTEL, Color("b9a883"), 1)


## Style « sélectionné » (onglets, choix actifs).
func selected(b: Button) -> void:
	b.add_theme_stylebox_override("normal", sb(SELECTED, Pal.ACCENT, 1))
	b.add_theme_color_override("font_color", Pal.ACCENT)


## Place un contrôle à une position/taille fixe dans un parent (layout 640x360).
func put(parent: Node, c: Control, pos: Vector2, size := Vector2.ZERO) -> Control:
	parent.add_child(c)
	c.position = pos
	if size != Vector2.ZERO:
		c.size = size
		fit(c, size.x)
	return c


## Texte trop large pour sa case : on réduit sa taille jusqu'à ce qu'il tienne (au plus jusqu'à 9).
## (want = largeur voulue : un Label s'élargit tout seul à la taille de son texte.)
func fit(c: Control, want := -1.0) -> void:
	var text := ""
	var room := want if want > 0.0 else c.size.x
	if c is Button:
		text = (c as Button).text
		room -= 14.0   # marges du bouton
	elif c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
		text = (c as Label).text
	if text == "" or room <= 0.0:
		return
	var sz := c.get_theme_font_size("font_size")
	var widest := func(n: int) -> float:
		var w := 0.0
		for line in text.split("\n"):
			w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x)
		return w
	var n := sz
	while n > 9 and widest.call(n) > room:
		n -= 1
	if n != sz:
		c.add_theme_font_size_override("font_size", n)
		c.size = Vector2(want if want > 0.0 else c.size.x, c.size.y)


## Fond d'écran. Sans couleur : le mur de la galerie (papier peint rayé, cimaise, parquet).
## Avec une couleur : un voile uni (menus par-dessus le jeu, confirmations...).
func fill_bg(parent: Control, color := Color(0, 0, 0, 0)) -> Control:
	var r: Control
	if color.a == 0.0:
		r = _Wall.new()
	else:
		r = _Veil.new()
		(r as _Veil).color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Voile uni : couvre son parent, ou tout l'écran si le parent n'a pas de taille.
class _Veil extends Control:
	var color := Color.BLACK

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var s := size if size.x > 0.0 and size.y > 0.0 else get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, s), color)


class _Wall extends Control:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		# Taille de l'écran (les écrans posés sous un Node n'ont pas de taille propre)
		var s := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, s), UI.WALL)
		for x in range(0, int(s.x), 12):
			draw_rect(Rect2(x, 0, 5, s.y - 14), UI.WALL_STRIPE)
		# cimaise en haut, plinthe et parquet en bas
		draw_rect(Rect2(0, 2, s.x, 1), UI.GOLD_DARK)
		draw_rect(Rect2(0, s.y - 14, s.x, 14), UI.FLOOR)
		for x in range(0, int(s.x), 40):
			draw_line(Vector2(x, s.y - 14), Vector2(x, s.y), Color(0, 0, 0, 0.2), 1.0)
		draw_rect(Rect2(0, s.y - 16, s.x, 2), UI.WOOD)
		draw_rect(Rect2(0, s.y - 16, s.x, 1), UI.GOLD_DARK)
		# léger vignettage
		draw_rect(Rect2(0, 0, s.x, 6), Color(0, 0, 0, 0.15))


## Vignette d'un dessin (TextureRect pixel-perfect).
func thumb(img: Image, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.size = size
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Police du menu (Yoster Island) sur tous les textes d'un bloc : normal → MENU_SIZE,
## gros (≥ 20) → MENU_BIG, très gros titre (≥ 40) → MENU_TITLE. Marges verticales des boutons : MENU_MARGIN.
func fs_title() -> int:
	return 40


func use_menu_font(root: Node) -> void:
	for c in root.get_children():
		if c is Button or c is Label:
			var cur := (c as Control).get_theme_font_size("font_size")
			var n := MENU_TITLE if cur >= fs_title() else (MENU_BIG if cur >= 20 else MENU_SIZE)
			(c as Control).add_theme_font_override("font", font_menu)
			(c as Control).add_theme_font_size_override("font_size", n)
			if c is Button:
				(c as Button).clip_text = true   # un texte trop long ne doit jamais élargir le bouton
			if c is Button:
				for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
					var sbx := (c as Button).get_theme_stylebox(st).duplicate() as StyleBox
					sbx.content_margin_top = MENU_MARGIN
					sbx.content_margin_bottom = MENU_MARGIN
					(c as Button).add_theme_stylebox_override(st, sbx)
		use_menu_font(c)


## Le logo du jeu (assets/logo.png), centré, avec une ombre portée. Largeur en pixels de jeu.
func logo(parent: Node, center_x: float, y: float, w := 230.0) -> TextureRect:
	var tex: Texture2D = load("res://assets/logo.png")
	var h := w * tex.get_height() / tex.get_width()
	var sh := TextureRect.new()
	sh.texture = tex
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sh.modulate = Color(0, 0, 0, 0.35)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(parent, sh, Vector2(center_x - w / 2.0 + 2, y + 3), Vector2(w, h))
	var tr := sh.duplicate() as TextureRect
	tr.modulate = Color.WHITE
	put(parent, tr, Vector2(center_x - w / 2.0, y), Vector2(w, h))
	return tr


# ------------------------------------------------------------------ Cercle des faiblesses

static var CERCLE_TEXT := "Chaque couleur fait ×1,5 de dégâts à celle que vise sa flèche, et ×0,75 à celle d'avant. La Lumière et l'Ombre se battent l'un l'autre.\nCe qui compte : la couleur principale de ton perso, de chaque arme et de chaque ennemi (au moins un quart du dessin)."


## Image du cercle (assets/ui/cercle.png, ou la petite version sans les noms).
func cercle(parent: Node, pos: Vector2, mini := false) -> TextureRect:
	var tex: Texture2D = load("res://assets/ui/cercle_mini.png" if mini else "res://assets/ui/cercle.png")
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	put(parent, tr, pos, tex.get_size())
	return tr


## Icônes de stats dans un texte : « +4 PV max » -> « +4 » + l'icône du cœur (BBCode). Voir stat_bbcode.
static var STAT_WORDS := [["vit. d'attaque", "atk_speed"], ["vitesse d'attaque", "atk_speed"], ["PV max", "max_hp"],
	["régénération", "regen"], ["armure", "armor"], ["esquive", "dodge"], ["vitesse", "move"], ["dégâts", "dmg"],
	["dégât", "dmg"], ["critique", "crit"], ["portée", "range"], ["vol de vie", "lifesteal"], ["chance", "luck"],
	["pourboire", "harvest"], ["épines", "thorns"], ["épine", "thorns"], ["Épines", "thorns"], ["Épine", "thorns"], ["puissance élémentaire", "el_power"],
	["effets élémentaires", "el_power"]]
var _stat_re: RegEx


func stat_bbcode(text: String, px := 12) -> String:
	if _stat_re == null:
		var alt := []
		for w in STAT_WORDS:
			alt.append(String(w[0]).replace(".", "\\."))
		# Le mot de la stat devient son icône quand il désigne TA stat :
		# - après un nombre (« +4 PV max ») ;
		# - après « tes / ton / ta / le / la / les », après « = », « × » ou « % », ou en début de phrase (« Tes épines... »).
		# Sauf si un mot précise que c'est autre chose (« dégâts de mêlée », « des familiers », « contre les boss »).
		var num := "([+\\-−×]?\\d+(?:[.,]\\d+)?\\s?%?)\\s+"
		var art := Loc.t("((?:^|\\b)(?:tes|ton|ta|le|la|les)\\s+|=\\s*|×\\s*|%\\s*|\\(|^)")   # (« × armure », « / % vitesse » : ratios)
		var word := "(" + "|".join(alt) + Loc.t(")(?![\\wàâéèêëîïôûùç])")
		var other := Loc.t("(?!\\s*(?:d['’]|de |des |du |à |À |au |aux |contre ))")
		_stat_re = RegEx.create_from_string("(?i)(?:" + num + "|" + art + ")" + word + other)
	var out := ""
	var pos := 0
	for m in _stat_re.search_all(text):
		out += text.substr(pos, m.get_start() - pos)
		var w := m.get_string(3).to_lower()
		var key := ""
		for sw in STAT_WORDS:
			if String(sw[0]).to_lower() == w:
				key = sw[1]
				break
		var icon := Loc.t("[img=%dx%d]res://assets/ui/stats/%s.png[/img]") % [px, px, key]
		if m.get_string(1) != "":
			out += "%s %s" % [m.get_string(1), icon]   # « +4 » + icône
		else:
			out += m.get_string(2) + icon              # « tes » + icône, « = » + icône...
		pos = m.get_end()
	return out + text.substr(pos)


## Étiquette de texte riche : les quantités de stats deviennent leurs icônes.
func rich(text: String, size := 10, color := Pal.TEXT, px := 12, center := false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", font)
	r.add_theme_font_size_override("normal_font_size", fs(size))
	r.add_theme_color_override("default_color", color)
	var t := stat_bbcode(text, px)
	r.text = (Loc.t("[center]%s[/center]") % t) if center else t
	return r


## Pastille d'une couleur du cercle (comme sur l'image du cercle) : disque ombré + symbole, 13×13.
const _EL_ICON := {
	Pal.FEU: ["...#...", "..##...", "..###..", ".#####.", ".##o##.", "##ooo##", ".#####."],
	Pal.FOUDRE: ["...###.", "..###..", ".###...", "#######", "...###.", "..###..", ".##...."],
	Pal.POISON: [".#####.", "#######", "#..#..#", "#######", ".##.##.", "..###..", "..#.#.."],   # crâne
	Pal.GLACE: ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	Pal.ARCANE: ["...#...", "...#...", ".#####.", "#######", ".#####.", "...#...", "...#..."],
	Pal.LUMIERE: ["#..#..#", ".#...#.", "...#...", "#.###.#", "...#...", ".#...#.", "#..#..#"],
	Pal.NOIR: [".#####.", "##...##", "#.....#", "#..#..#", "#.....#", "##...##", ".#####."],
}
var _el_icons := {}


func element_icon(c: int) -> Texture2D:
	if _el_icons.has(c):
		return _el_icons[c]
	var sh: Array = Pal.SHADES[0 if c == Pal.NOIR else c]
	var img := Image.create_empty(13, 13, false, Image.FORMAT_RGBA8)
	for y in 13:
		for x in 13:
			var dx := x - 6
			var dy := y - 6
			var d := sqrt(dx * dx + dy * dy)
			if d <= 6.5:
				var col: Color = sh[1]
				if dx + dy < -3:
					col = sh[2]
				elif dx + dy > 4:
					col = sh[0]
				img.set_pixel(x, y, Pal.INK if d > 5.3 else col)
	var light := c in [Pal.LUMIERE, Pal.FOUDRE]
	var rows: Array = _EL_ICON[c]
	for j in 7:
		for i in 7:
			var ch: String = rows[j][i]
			if ch == "#":
				img.set_pixel(3 + i, 3 + j, Pal.INK if light else Color.WHITE)
			elif ch == "o":
				img.set_pixel(3 + i, 3 + j, sh[2])
	_el_icons[c] = ImageTexture.create_from_image(img)
	return _el_icons[c]


## Pastille de couleur posée sur un écran (infobulle : le nom de la couleur).
func element_badge(parent: Node, c: int, pos: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = element_icon(c)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.tooltip_text = Loc.t("Couleur : ") + Pal.color_name(c)
	put(parent, tr, pos, Vector2(13, 13))
	return tr


## Fenêtre « Cercle des faiblesses » par-dessus un écran (Échap ou Fermer pour la fermer).
## extra : une ligne en plus (ex. la couleur de ton perso).
## with_text = false : juste l'image du cercle, sans l'explication (Codex).
func cercle_popup(parent: Node, extra := "", with_text := true) -> Control:
	var ov := Control.new()
	ov.process_mode = Node.PROCESS_MODE_ALWAYS
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	put(parent, ov, Vector2.ZERO, Vector2(640, 360))
	fill_bg(ov, Color(0, 0, 0, 0.6))
	var p := panel(Pal.PANEL, Pal.BORDER, 2)
	var ph := 328.0 if with_text else 232.0
	put(ov, p, Vector2(150, (360.0 - ph) / 2.0), Vector2(340, ph))
	put(p, label(Loc.t("CERCLE DES FAIBLESSES"), 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(340, 24))
	cercle(p, Vector2(52, 32))
	if with_text:
		var t := label(CERCLE_TEXT + ("\n" + extra if extra != "" else ""), 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		put(p, t, Vector2(12, 202), Vector2(316, 98))
	var close := hotkey(button(Loc.t("Fermer"), func(): ov.queue_free()), [KEY_ESCAPE])
	put(p, close, Vector2(120, ph - 24.0), Vector2(100, 16))
	return ov
