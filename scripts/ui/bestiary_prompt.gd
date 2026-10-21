class_name BestiaryPrompt
extends Control
## Avant de dessiner QUOI QUE CE SOIT, on propose d'abord un dessin existant.
## À gauche : le dessin choisi (au départ, le dernier dessin utilisé pour cet objet).
## Cliquer un dessin de la galerie (à droite) le met dans le cadre de gauche :
## on peut alors l'utiliser tel quel ou le modifier. Bouton « Bord » pour le contour noir.
## done({"a": "keep"|"redraw", "image", "effect", "outline", "from_carnet"})
## | done({"a": "draw", "outline"}) | done({"a": "cancel"})

signal done(result)

var cfg: Dictionary
var existing          # {image, effect, outline} ou null
var reward := 0
var caption := Loc.t("TON DESSIN DE BASE")

var sel_img: Image
var sel_effect := ""
var from_carnet := false
var outline := false

var frame_cap: Label
var pic: TextureRect
var pic_mat: ShaderMaterial
var keep_btn: Button
var mod_btn: Button
var alt_row: Control      # « Modifier » / « Nouveau » : cachés quand il n'y a encore aucun dessin
var bord_btn: Button
var gallery_btns := []
var pic_el: TextureRect   # icône de l'élément principal du dessin choisi (armes, couleur imposée)
var show_el := false


func _init(draw_cfg: Dictionary, current, pigments_reward := 0, featured_caption := Loc.t("TON DESSIN DE BASE")) -> void:
	cfg = draw_cfg
	existing = current
	reward = pigments_reward
	caption = featured_caption


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	UI.fill_bg(self)
	UI.put(self, UI.label(cfg.title, 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 8), Vector2(640, 24))
	# Pas de texte d'aide ici (il reste sur la toile) ; seule une couleur imposée est rappelée,
	# en grand : l'icône de l'élément et son nom
	if cfg.has("need_el"):
		var el := int(cfg.need_el)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		UI.put(self, row, Vector2(0, 36), Vector2(640, 22))
		row.add_child(_el_icon(el, 20))
		var nl := UI.label(Loc.t("COULEUR IMPOSÉE : %s") % String(Pal.NAMES[el]).to_upper(), 16, Pal.SHADES[el][1].lightened(0.25))
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nl)

	# --- Gauche : le dessin choisi
	frame_cap = UI.label(caption, 10, Pal.DIM)
	UI.put(self, frame_cap, Vector2(24, 64), Vector2(200, 12))
	var frame := UI.panel(Color("b07d1c"), Pal.ACCENT, 2)
	UI.put(self, frame, Vector2(24, 78), Vector2(200, 190))
	var inner := UI.panel(Pal.PAPER, Color("8c6a1a"), 1)
	UI.put(frame, inner, Vector2(8, 8), Vector2(184, 174))
	pic = TextureRect.new()
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(inner, pic, Vector2(7, 7), Vector2(170, 160))

	# L'élément principal du dessin : toujours montré pour une arme (c'est lui qui décide de la
	# synergie et des faiblesses), et quand une couleur est imposée
	show_el = cfg.has("need_el") or String(cfg.kind) in ["melee", "ranged", "bullet"]
	pic_el = _el_icon(0, 20)
	pic_el.visible = false
	UI.put(inner, pic_el, Vector2(160, 4), Vector2(20, 20))

	keep_btn = UI.hotkey(UI.button(Loc.t("Utiliser ce dessin"), _keep, 20), [KEY_ENTER, KEY_KP_ENTER])
	UI.put(self, keep_btn, Vector2(24, 274), Vector2(200, 24))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	UI.put(self, row, Vector2(24, 302), Vector2(200, 16))
	alt_row = row
	mod_btn = UI.hotkey(UI.button(Loc.t("Modifier"), _redraw), [KEY_M])
	mod_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mod_btn)
	var nw := UI.hotkey(UI.button(Loc.t("Nouveau"), func(): done.emit({"a": "draw", "outline": outline})), [KEY_N])
	nw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nw)
	bord_btn = UI.hotkey(UI.button("", _toggle_outline), [KEY_C])
	bord_btn.tooltip_text = Loc.t("Contour noir autour du dessin en jeu")
	UI.put(self, bord_btn, Vector2(24, 322), Vector2(200, 16))

	if existing != null:
		from_carnet = true
		outline = existing.outline
		_select(existing.image, existing.effect)
	else:
		_select(null, "")

	# --- Droite : dessins de la galerie qui conviennent
	var fits := _fitting()
	UI.put(self, UI.label(Loc.t("TA GALERIE"), 10, Pal.DIM), Vector2(248, 64))
	UI.put(self, DrawingGrid.new(fits, 6, Vector2(58, 58), _gallery_cell), Vector2(248, 78), Vector2(380, 252))
	if existing != null:
		UI.put(self, UI.button(Loc.t("< Remettre le dessin de base"), func():
			from_carnet = true
			frame_cap.text = caption
			outline = existing.outline
			_select(existing.image, existing.effect)
			for o in gallery_btns:
				_style_thumb(o, false)), Vector2(248, 338), Vector2(200, 18))
	if cfg.get("cancel", false):
		UI.put(self, UI.hotkey(UI.button(String(cfg.get("cancel_label", Loc.t("Retour"))), func(): done.emit({"a": "cancel"})), [KEY_ESCAPE]), Vector2(528, 338), Vector2(100, 18))


## Une case de la galerie (créée seulement quand sa ligne devient visible). f : [fiche, blocage, couleur].
func _gallery_cell(f: Array) -> Control:
	var e: Dictionary = f[0]
	var block: String = f[1]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(58, 58)
	_style_thumb(b, false)
	var th := UI.drawing_thumb(e.file, Vector2(50, 50))
	th.position = Vector2(4, 4)
	b.add_child(th)
	b.tooltip_text = Loc.t("Encre : %d") % int(e.get("ink", 0))
	if show_el:
		# icône de l'élément de sa couleur dominante, dans le coin
		var gel := Analyzer.dominant_of(e.get("el", []))
		var ic := _el_icon(gel, 13)
		ic.position = Vector2(43, 2)
		b.add_child(ic)
		b.tooltip_text += "\n" + Loc.t("Élément : %s") % Pal.NAMES[maxi(gel, 0)]
	var issue: String = block if block != "" else f[2]
	if issue != "":
		# pas utilisable tel quel (trop grand, couleurs verrouillées, mauvaise couleur) : pâli,
		# mais on peut le prendre pour le MODIFIER ; c'est au joueur de le rendre valide
		th.modulate = Color(1, 1, 1, 0.3)
		b.tooltip_text = Loc.t("%s\n(tu peux le prendre et le modifier)") % issue
	b.pressed.connect(func():
		var gi := Meta.gallery_image(e)
		if gi == null:
			return
		Sfx.play("click")
		from_carnet = false
		frame_cap.text = Loc.t("DESSIN CHOISI DANS TA GALERIE")
		outline = e.get("outline", false)   # le bord choisi dans la galerie
		bord_btn.text = Loc.t("Bord : %s") % (Loc.t("oui") if outline else Loc.t("non"))
		_select(gi, _effect_ok(e.get("effect", "")))
		for o in gallery_btns:
			if is_instance_valid(o):
				_style_thumb(o, o == b))
	gallery_btns.append(b)
	return b


func _style_thumb(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", UI.sbc(Pal.PAPER, Pal.ACCENT if on else Pal.BORDER, 3 if on else 1))
	b.add_theme_stylebox_override("hover", UI.sbc(Pal.PAPER, Pal.ACCENT, 2))
	b.add_theme_stylebox_override("pressed", UI.sbc(Pal.PAPER, Pal.ACCENT, 3))
	b.add_theme_stylebox_override("disabled", UI.sbc(Pal.PAPER, Pal.BORDER, 1))   # (pas de case sombre)


## Icône d'un élément (0 = l'Ombre), agrandie au pixel près.
static func _el_icon(el: int, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UI.element_icon(el if el > 0 else Pal.NOIR)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Met un dessin dans le grand cadre (ou un « ? » si aucun).
func _select(img: Image, effect: String) -> void:
	sel_img = _fit_canvas(img) if img else null   # (un dessin trop grand reste entier : à retoucher)
	sel_effect = effect
	var shown: Image = Analyzer.trim(sel_img) if sel_img else Gfx.icon(Gfx.ICON_UNKNOWN)
	pic.texture = ImageTexture.create_from_image(Gfx.padded(shown))
	pic_mat = Gfx.material(sel_effect, outline and sel_img != null)
	pic.material = pic_mat
	pic_el.visible = show_el and sel_img != null
	if pic_el.visible:
		var sel_el := int(Analyzer.analyze(sel_img).dominant)
		pic_el.texture = UI.element_icon(sel_el if sel_el > 0 else Pal.NOIR)
		pic_el.tooltip_text = Loc.t("Élément : %s") % Pal.NAMES[maxi(sel_el, 0)]
		pic_el.mouse_filter = Control.MOUSE_FILTER_STOP
	var why := _usable(img) if img else Loc.t("Rien pour l'instant : dessine-le !")   # (sur le dessin d'origine)
	keep_btn.disabled = why != ""
	mod_btn.disabled = sel_img == null
	alt_row.visible = sel_img != null   # pas de dessin : seul « Dessiner » (Nouveau ferait pareil)
	mod_btn.text = Loc.t("Modifier") + ("  (+%d ◆)" % reward if reward > 0 and from_carnet else "")
	keep_btn.tooltip_text = why if sel_img else ""   # pourquoi on ne peut pas l'utiliser tel quel
	keep_btn.text = Loc.t("Utiliser ce dessin") if sel_img else Loc.t("Dessiner")
	if sel_img == null:
		keep_btn.disabled = false
	bord_btn.text = Loc.t("Bord : %s") % (Loc.t("oui") if outline else Loc.t("non"))


func _toggle_outline() -> void:
	outline = not outline
	pic_mat.set_shader_parameter("outline", outline and sel_img != null)
	bord_btn.text = Loc.t("Bord : %s") % (Loc.t("oui") if outline else Loc.t("non"))


func _keep() -> void:
	if sel_img == null:
		done.emit({"a": "draw", "outline": outline})
		return
	Sfx.play("buy")
	done.emit({"a": "keep", "image": sel_img, "effect": sel_effect, "outline": outline, "from_carnet": from_carnet})


func _redraw() -> void:
	if sel_img == null:
		return
	done.emit({"a": "redraw", "image": sel_img, "effect": sel_effect, "outline": outline, "from_carnet": from_carnet})


## "" si le dessin est utilisable tel quel, sinon la raison.
func _usable(img: Image) -> String:
	if img == null:
		return Loc.t("Rien")
	var s: Vector2i = cfg.size
	var r := img.get_used_rect()
	if r.size.x > s.x or r.size.y > s.y:
		return Loc.t("Trop grand pour cette toile")
	var cost := Analyzer.ink_cost(img)
	if cost > int(cfg.ink):
		return Loc.t("Trop d'encre (%d / %d)") % [cost, int(cfg.ink)]
	if cost < int(cfg.get("min_ink", 0)):
		return Loc.t("Pas assez d'encre (%d / %d min)") % [cost, int(cfg.min_ink)]
	var lc := Meta.locked_colors(img)
	if not lc.is_empty():
		return Loc.t("Couleurs pas encore débloquées : ") + ", ".join(lc)
	return DrawCfg.color_issue(cfg, img)


## Dessins de la galerie compatibles (taille). L'encre est vérifiée sur le dessin choisi :
## un dessin trop gourmand peut quand même être pris puis modifié.
## TOUS les dessins de la galerie de ce type : [entrée, raison du blocage ou "", souci de couleur ou ""].
## (D'après les infos de chaque fiche : aucune image n'est relue ici.)
## (Avant, les trop grands étaient cachés et la liste s'arrêtait à 48 : des dessins « disparaissaient ».)
func _fitting() -> Array:
	var out := []
	for e in Meta.gallery(cfg.gallery):
		if not Meta.info(e).has("rect"):
			continue   # (fichier introuvable)
		var block := DrawCfg.entry_block(cfg, e)
		out.append([e, block, DrawCfg.entry_color_issue(cfg, e) if block == "" else ""])
	# les utilisables d'abord, puis ceux de la mauvaise couleur, puis les bloqués
	var rank := func(f: Array) -> int: return 2 if f[1] != "" else (1 if f[2] != "" else 0)
	out.sort_custom(func(a, b): return rank.call(a) < rank.call(b))
	return out


func _effect_ok(fx: String) -> String:
	return fx if fx in Meta.effects() else ""


## Recentre le dessin sur une toile de la taille attendue. Un dessin trop grand n'est PAS coupé :
## la toile s'agrandit (il ne pourra pas être utilisé tel quel, seulement modifié).
func _fit_canvas(src: Image) -> Image:
	var t := Analyzer.trim(src)
	var ss := t.get_size()
	var s := Vector2i(maxi(cfg.size.x, ss.x), maxi(cfg.size.y, ss.y))
	var out := Image.create_empty(s.x, s.y, false, Image.FORMAT_RGBA8)
	@warning_ignore("integer_division")
	out.blit_rect(t, Rect2i(Vector2i.ZERO, ss), (s - ss) / 2)
	return out
