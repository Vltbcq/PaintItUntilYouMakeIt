class_name CodexScreen
extends Control
## Codex : toutes les armes, amulettes et ennemis, avec leurs stats et leur DESSIN PAR DÉFAUT.
## Le dessin par défaut est proposé en premier quand on achète / rencontre l'objet en partie
## (on peut toujours le redessiner à ce moment-là). Les armes ont un dessin PAR RARETÉ.
## done(null) pour revenir au titre, done({"a": "draw", "key", "cfg", "tab", "sel"}) pour dessiner.

signal done(result)

static var TABS := [["armes", "Armes"], ["amulettes", "Amulettes"], ["familiers", "Familiers"], ["ennemis", "Ennemis"]]

var tab := "armes"
var sel := ""
var picker: Control
var _detail: Control       # panneau de droite : seul refait quand on clique dans la liste
var _list_btns := {}       # id -> bouton de la liste
static var scroll_mem := {}  # position de défilement de la liste, par onglet (gardée quand on revient d'un dessin)


func _init(start_tab := "armes", start_sel := "") -> void:
	tab = start_tab
	sel = start_sel
	if start_sel == "":
		scroll_mem = {}   # ouvert depuis le titre : la liste repart du haut


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()


# ------------------------------------------------------------------ Données

func _items() -> Array:
	# par rareté (minimum pour une arme), puis ordre alphabétique ; clé de tri calculée une fois par objet
	var key := {}
	match tab:
		"armes":
			for id in WeaponDB.TYPES:
				key[id] = _order(int(WeaponDB.TYPES[id].get("min_rar", 0)), WeaponDB.TYPES[id].name)
		"amulettes":
			for d in AmuletDB.LIST:
				key[d.id] = _order(int(d.rar), d.name)
		"familiers":
			for d in FamiliarDB.LIST:
				key[d.id] = _order(int(d.rar), d.name)
		"ennemis":
			return EnemyDB.TYPES.keys()
	var out := key.keys()
	out.sort_custom(func(a, b): return key[a] < key[b])
	return out


## Clé de tri : rareté, puis nom sans accents ni majuscules (« Écu » se range avec les E).
static func _order(rar: int, name: String) -> String:
	var n := name.to_lower()
	for pair in [["é", "e"], ["è", "e"], ["ê", "e"], ["ë", "e"], ["à", "a"], ["â", "a"], ["î", "i"], ["ï", "i"],
			["ô", "o"], ["ù", "u"], ["û", "u"], ["ç", "c"], ["œ", "oe"], ["'", ""], ["’", ""], ["-", " "]]:
		n = n.replace(pair[0], pair[1])
	return "%d %s" % [rar, n]


## Ennemi / boss d'une carte pas encore débloquée : on ne sait pas ce que c'est.
## Cet objet a-t-il quelque chose à débloquer ? (sinon il ne compte pas dans le % débloqué)
func _lockable(id: String) -> bool:
	if tab == "ennemis":
		return true   # chaque ennemi se « débloque » en le rencontrant
	return ItemUnlockDB.CONDS.has(_item_key(id))


func _locked(id: String) -> bool:
	if tab != "ennemis":
		return not Meta.item_open(_item_key(id))   # arme / amulette pas encore débloquée : « ??? »
	return Meta.bestiary_file(id) == ""   # ennemi jamais rencontré (on dessine chaque ennemi la 1re fois qu'il arrive)


func _name(id: String) -> String:
	if _locked(id):
		return "???"
	match tab:
		"armes":
			return WeaponDB.get_def(id).name
		"amulettes":
			return AmuletDB.get_def(id).name
		"familiers":
			return FamiliarDB.get_def(id).name
	return EnemyDB.get_def(id).name


## Emplacements de dessin d'un objet : [clé du carnet, libellé, config de dessin]
func _slots(id: String) -> Array:
	match tab:
		"armes":
			var def := WeaponDB.get_def(id)
			var out := []
			for r in range(int(def.get("min_rar", 0)), 4):
				out.append([Run.weapon_key(id, r), Pal.RARITY_NAMES_F[r], DrawCfg.weapon(id, r, true), Pal.RARITY[r]])
			if def.kind == "ranged" and not def.get("nobullet", false):
				var wa := Analyzer.analyze(_default_or_blank("arme_" + id, Vector2i(def.canvas, def.canvas)))
				out.append(["balle_" + id, Loc.t("Balles"), DrawCfg.bullet(id, wa, "", 0)])
			return out
		"amulettes":
			var ad := AmuletDB.get_def(id)
			return [["amulette_" + id, Loc.t("Amulette %s") % Pal.RARITY_NAMES_F[int(ad.rar)].to_lower(), DrawCfg.amulet(ad), Pal.RARITY[int(ad.rar)]]]
		"familiers":
			var fd := FamiliarDB.get_def(id)
			return [["familier_" + id, Loc.t("Familier %s") % Pal.RARITY_NAMES_F[int(fd.rar)].to_lower(), DrawCfg.familiar(fd), Pal.RARITY[int(fd.rar)]]]
	var ed := EnemyDB.get_def(id)
	if ed.has("boss"):
		return [[id, Loc.t("Boss"), DrawCfg.enemy(id)]]
	var out := [[id, Loc.t("Ennemi"), DrawCfg.enemy(id)]]
	# Élite : on part de son dessin de base du Codex (comme les raretés d'une arme)
	var base = Meta.bestiary_get(id)
	if base != null:
		out.append([id + "_elite", Loc.t("Élite"), DrawCfg.elite(id, base.image, base.effect, base.outline), Pal.ACCENT])
	return out


## Clés du carnet d'un objet (comme _slots, sans préparer les dessins : rapide).
func _slot_keys(id: String) -> Array:
	if tab == "ennemis" and not EnemyDB.get_def(id).has("boss"):
		return [id, id + "_elite"]
	match tab:
		"armes":
			var def := WeaponDB.get_def(id)
			var out := []
			for r in range(int(def.get("min_rar", 0)), 4):
				out.append(Run.weapon_key(id, r))
			if def.kind == "ranged" and not def.get("nobullet", false):
				out.append("balle_" + id)
			return out
		"amulettes":
			return ["amulette_" + id]
		"familiers":
			return ["familier_" + id]
	return [id]


## Complétion d'un onglet (ou de tout le Codex) : [% dessiné, % débloqué].
func _completion(only := "") -> Array:
	return _pct(_completion_counts(), only)


## Comptes de chaque onglet, en un seul passage : {onglet: [cases dessinées, cases, débloqués, à débloquer]}.
func _completion_counts() -> Dictionary:
	var keep := tab
	var b: Dictionary = Meta.data.get("bestiary", {})
	var out := {}
	for t in TABS:
		tab = t[0]
		var c := [0, 0, 0, 0]
		for id in _items():
			if _lockable(id):   # seulement ce qui se débloque (succès, nouvelle carte)
				c[3] += 1
				if not _locked(id):
					c[2] += 1
			for k in _slot_keys(id):
				c[1] += 1
				if b.has(k):
					c[0] += 1
		out[tab] = c
	tab = keep
	return out


static func _pct(counts: Dictionary, only := "") -> Array:
	var c := [0, 0, 0, 0]
	for t in counts:
		if only == "" or t == only:
			for i in 4:
				c[i] += counts[t][i]
	return [100.0 * c[0] / maxi(1, c[1]), 100.0 * c[2] / c[3] if c[3] > 0 else 100.0]


func _default_or_blank(key: String, size: Vector2i) -> Image:
	var b = Meta.bestiary_get(key)
	if b != null:
		return b.image
	return Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)


# ------------------------------------------------------------------ Interface

func _build() -> void:
	for c in get_children():
		c.queue_free()
	picker = null
	UI.fill_bg(self)
	UI.put(self, UI.label(Loc.t("CODEX"), 20, Pal.ACCENT), Vector2(12, 8))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	UI.put(self, tabs, Vector2(12, 34), Vector2(250, 16))
	var counts := _completion_counts()
	for t in TABS:
		var tid: String = t[0]
		var b := UI.button(t[1], func():
			tab = tid
			sel = ""
			_build())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tid == tab:
			b.add_theme_stylebox_override("normal", UI.sb(UI.SELECTED, Pal.ACCENT, 1))
		var tc := _pct(counts, tid)
		b.tooltip_text = Loc.t("%s : %d%% dessiné · %d%% débloqué") % [t[1], roundi(tc[0]), roundi(tc[1])]
		tabs.add_child(b)
	# Complétion du Codex (tout confondu) et de l'onglet ouvert
	var all := _pct(counts)
	var cl := UI.label(Loc.t("COMPLÉTION  %d%% dessiné · %d%% débloqué") % [roundi(all[0]), roundi(all[1])], 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
	cl.mouse_filter = Control.MOUSE_FILTER_STOP
	cl.tooltip_text = Loc.t("Dessiné : cases du Codex qui ont un dessin par défaut (chaque rareté d'arme compte)\nDébloqué : armes, amulettes et ennemis disponibles")
	UI.put(self, cl, Vector2(270, 36), Vector2(358, 12))

	if UI.has_elements():
		var cb := UI.button(Loc.t("Cercle des faiblesses"), func(): UI.cercle_popup(self, "", false))
		cb.tooltip_text = Loc.t("Les faiblesses entre couleurs (éléments)")
		UI.put(self, cb, Vector2(100, 334), Vector2(130, 18))   # (aligné sur « Retour »)

	var items := _items()
	if sel == "" or not sel in items:
		sel = items[0]

	# --- Liste
	var sc := ScrollContainer.new()
	UI.put(self, sc, Vector2(12, 56), Vector2(250, 272))
	UI.keep_scroll(sc, scroll_mem, tab)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.custom_minimum_size = Vector2(238, 0)
	sc.add_child(vb)
	_list_btns.clear()
	var unknown := ImageTexture.create_from_image(Gfx.icon(Gfx.ICON_UNKNOWN))
	for id in items:
		var iid: String = id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(236, 24)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var locked := _locked(iid)
		var bf := "" if locked else Meta.bestiary_file(_slot_keys(iid)[0])
		var has_default := bf != ""
		b.text = "      " + _name(iid) + ("  ✓" if has_default else "")
		if iid == sel:
			b.add_theme_stylebox_override("normal", UI.sbc(UI.SELECTED, Pal.ACCENT, 1))
		if tab == "amulettes":
			b.add_theme_color_override("font_color", Pal.RARITY[AmuletDB.get_def(iid).rar])
		elif tab == "familiers":
			b.add_theme_color_override("font_color", Pal.RARITY[int(FamiliarDB.get_def(iid).rar)])
		elif tab == "armes":
			# couleur de la rareté minimum de l'arme (commune blanc, rare bleu, épique violet, légendaire orange)
			b.add_theme_color_override("font_color", Pal.RARITY[int(WeaponDB.TYPES[iid].get("min_rar", 0))])
		if locked:
			b.add_theme_color_override("font_color", Pal.DISABLED)
		var th := UI.drawing_thumb(bf, Vector2(18, 18), true) if has_default else UI.thumb(null, Vector2(18, 18))
		if not has_default:
			th.texture = unknown
		th.position = Vector2(4, 3)
		b.add_child(th)
		b.pressed.connect(func():
			Sfx.play("click")
			_select(iid))
		vb.add_child(b)
		_list_btns[iid] = b
	UI.put(self, UI.hotkey(UI.button(Loc.t("Retour"), func(): done.emit(null)), [KEY_ESCAPE]), Vector2(12, 334), Vector2(80, 18))
	_show_detail()


## Clic dans la liste : seuls la surbrillance et le panneau de droite changent (la liste reste).
func _select(id: String) -> void:
	sel = id
	for k in _list_btns:
		if k == sel:
			_list_btns[k].add_theme_stylebox_override("normal", UI.sbc(UI.SELECTED, Pal.ACCENT, 1))
		else:
			_list_btns[k].remove_theme_stylebox_override("normal")
	_show_detail()


func _show_detail() -> void:
	if is_instance_valid(_detail):
		_detail.queue_free()
	var p := UI.panel()
	_detail = p
	UI.put(self, p, Vector2(270, 56), Vector2(358, 272))
	UI.put(p, UI.label(_name(sel), 20, Pal.ACCENT), Vector2(10, 6), Vector2(338, 24))
	if _locked(sel):
		var fr := UI.panel(Pal.PAPER, Pal.BORDER, 2)
		UI.put(p, fr, Vector2(10, 36), Vector2(76, 76))
		UI.put(fr, UI.thumb(Gfx.icon(Gfx.ICON_UNKNOWN), Vector2(68, 68)), Vector2(4, 4), Vector2(68, 68))
		var why := ""
		if tab == "ennemis":
			why = Loc.t("Tu n'as pas encore rencontré cette créature.")
		else:
			var ik := _item_key(sel)
			why = {"armes": Loc.t("Cette arme"), "familiers": Loc.t("Ce familier")}.get(tab, Loc.t("Cette amulette")) + Loc.t(" n'apparaît pas encore en boutique.\n\nSuccès : ") + ItemUnlockDB.text(ItemUnlockDB.CONDS[ik])
			if ik in Meta.data.get("pending_unlocks", []):
				why += Loc.t("\n\n⌛ Obtenu : disponible à la fin de la partie.")
		var lk := UI.label(Loc.t("VERROUILLÉ\n\n") + why, 10, Pal.DIM)
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.put(p, lk, Vector2(96, 36), Vector2(250, 120))
		return
	var slots := _slots(sel)
	var compact := slots.size() > 2
	for i in slots.size():
		if compact:
			_slot_small(p, slots[i], Vector2(10 + i * 68, 32))
		else:
			_slot_ui(p, slots[i], Vector2(10 + i * 172, 34))
	var info := UI.rich(_stats_text(sel), 10, Pal.TEXT, 11)   # quantités de stats en icônes
	info.custom_minimum_size.x = 338
	UI.put(p, info, Vector2(10, 146 if compact else 128), Vector2(338, 120))


## Version compacte (armes : une case par rareté + balles).
func _slot_small(parent: Control, slot: Array, pos: Vector2) -> void:
	var key: String = slot[0]
	var cfg: Dictionary = slot[2]
	var d = Meta.bestiary_get(key)
	var col: Color = slot[3] if slot.size() > 3 else Pal.DIM
	UI.put(parent, UI.label(String(slot[1]).to_upper(), 10, col, HORIZONTAL_ALIGNMENT_CENTER), pos, Vector2(64, 12))
	var frame := UI.panel(Pal.PAPER, col, 2)   # cadre de la couleur de la rareté, dessiné ou non
	UI.put(parent, frame, pos + Vector2(4, 12), Vector2(56, 56))
	var img: Image = ((Gfx.baked_outline(Analyzer.trim(d.image)) if d.outline else Analyzer.trim(d.image)) if d != null else Gfx.icon(Gfx.ICON_UNKNOWN))
	UI.put(frame, UI.thumb(img, Vector2(48, 48)), Vector2(4, 4), Vector2(48, 48))
	var g := UI.button(Loc.t("Galerie"), func(): _open_picker(key, cfg))
	UI.put(parent, g, pos + Vector2(0, 72), Vector2(64, 16))
	var m := UI.button(Loc.t("Modifier") if d != null else Loc.t("Dessiner"), func():
		done.emit({"a": "draw", "key": key, "cfg": cfg, "tab": tab, "sel": sel}))
	UI.put(parent, m, pos + Vector2(0, 90), Vector2(64, 16))
	if d != null:
		var x := UI.button("×", func():
			Meta.bestiary_remove(key)
			Sfx.play("click")
			_build())
		x.tooltip_text = Loc.t("Retirer ce dessin par défaut")
		UI.put(parent, x, pos + Vector2(50, 12), Vector2(14, 14))


func _slot_ui(parent: Control, slot: Array, pos: Vector2) -> void:
	var key: String = slot[0]
	var cfg: Dictionary = slot[2]
	var d = Meta.bestiary_get(key)
	var rcol: Color = slot[3] if slot.size() > 3 else Color(0, 0, 0, 0)
	UI.put(parent, UI.label(String(slot[1]).to_upper(), 10, rcol if slot.size() > 3 else Pal.DIM), pos)
	# armes / amulettes : cadre de la couleur de la rareté ; ennemis : couleur du titre « ENNEMI »
	var frame := UI.panel(Pal.PAPER, rcol if slot.size() > 3 else Pal.DIM, 2)   # cadre de la couleur de son titre
	UI.put(parent, frame, pos + Vector2(0, 12), Vector2(76, 76))
	var img: Image = ((Gfx.baked_outline(Analyzer.trim(d.image)) if d.outline else Analyzer.trim(d.image)) if d != null else Gfx.icon(Gfx.ICON_UNKNOWN))
	UI.put(frame, UI.thumb(img, Vector2(68, 68)), Vector2(4, 4), Vector2(68, 68))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	UI.put(parent, col, pos + Vector2(82, 12), Vector2(76, 76))
	col.add_child(UI.button(Loc.t("Galerie"), func(): _open_picker(key, cfg)))
	col.add_child(UI.button(Loc.t("Modifier") if d != null else Loc.t("Dessiner"), func():
		done.emit({"a": "draw", "key": key, "cfg": cfg, "tab": tab, "sel": sel})))
	if d != null:
		col.add_child(UI.button(Loc.t("Retirer"), func():
			Meta.bestiary_remove(key)
			Sfx.play("click")
			_build()))


## Clé de succès d'objet de cet élément ("" pour les ennemis).
func _item_key(id: String) -> String:
	match tab:
		"armes":
			return ItemUnlockDB.key_weapon(id)
		"amulettes":
			return ItemUnlockDB.key_amulet(id)
		"familiers":
			return ItemUnlockDB.key_familiar(id)
	return ""


func _stats_text(id: String) -> String:
	var L := []
	# Succès qui débloque cet objet (uniquement affiché ici, dans le Codex)
	var ik := _item_key(id)
	if ItemUnlockDB.CONDS.has(ik):
		var cond := ItemUnlockDB.text(ItemUnlockDB.CONDS[ik])
		if Meta.item_open(ik):
			L.append(Loc.t("✓ Débloqué · ") + cond)
		elif ik in Meta.data.get("pending_unlocks", []):
			L.append(Loc.t("⌛ Obtenu : disponible à la fin de la partie · ") + cond)
		else:
			L.append(Loc.t("VERROUILLÉ · Succès : ") + cond)
		L.append("")
	match tab:
		"armes":
			var def := WeaponDB.get_def(id)
			L.append("%s — %s" % [Loc.t("Corps à corps") if def.kind == "melee" else Loc.t("À distance"), def.desc])
			var ink := Loc.t("Encre %d") % def.ink
			if def.kind == "ranged" and not def.get("nobullet", false):
				ink += Loc.t(" + balles %d") % def.bink
			L.append(ink + Loc.t("  ·  Rareté : puissance ×1,8 / ×3,2 / ×6"))
			var d = Meta.bestiary_get("arme_" + id)
			if d != null:
				var mr := int(def.get("min_rar", 0))
				var w := {"type": id, "rar": mr, "a": Analyzer.analyze(d.image), "effect": d.effect, "beffect": ""}
				if def.kind == "ranged":
					var b := _default_or_blank("balle_" + id, Vector2i(def.bcanvas, def.bcanvas))
					if Analyzer.count_pixels(b) == 0:
						b.set_pixel(1, 1, Pal.INK)
					w.bullet = b
					w.ba = Analyzer.analyze(b)
					w.beffect = ""
				var st := Stats.weapon(w)
				var hit: float = st.get("damage", 0.0)
				if st.kind == "ranged":
					hit = 0.0
					for bl in st.bullets:
						hit += bl.damage
					hit *= st.pellets
				L.append(Loc.t("Avec ton dessin (%s) : %.1f dégâts / %.2fs = %.1f dégâts/s, critique %d%%") % [Pal.RARITY_NAMES_F[mr].to_lower(), hit, st.cooldown, hit / st.cooldown, roundi(st.crit)])
		"amulettes":
			var def := AmuletDB.get_def(id)
			L.append(Loc.t("%s — encre %d") % [Pal.RARITY_NAMES_F[def.rar], AmuletDB.ink(def)])
			L.append(AmuletDB.describe(def))
		"familiers":
			var fdef := FamiliarDB.get_def(id)
			L.append(Loc.t("Familier %s (unique) — encre %d") % [Pal.RARITY_NAMES_F[int(fdef.rar)].to_lower(), FamiliarDB.ink(fdef)])
			L.append(String(fdef.desc))
		"ennemis":
			var def := EnemyDB.get_def(id)
			var kind := Loc.t("Boss") if def.get("boss", 0) == 2 else (Loc.t("Mini-boss") if def.has("boss") else Loc.t("Ennemi"))
			L.append(Loc.t("%s — %s, vague %d.") % [kind, MapDB.get_def(int(def.get("map", 1))).name, def.wave])
			L.append(Loc.t("PV de base %d · dégâts %s · vitesse %d · encre %d%s") % [roundi(def.hp), str(def.dmg), roundi(def.spd), def.ink,
				Loc.t(" (95 % minimum)") if def.has("boss") else ""])
			var d = Meta.bestiary_get(id)
			if d != null:
				var m := Stats.enemy_art(Analyzer.analyze(d.image), def.ink, d.get("effect", ""))
				L.append(Loc.t("Avec ton dessin : PV ×%.2f, vitesse ×%.2f, esquive %d%%, armure %d%%, dégâts +%d%%, butin ×%.2f, élément %s") % [
					m.hp, m.speed, roundi(m.dodge), roundi(m.armor), roundi(m.dmg), m.loot, Pal.NAMES[m.element]])
	return "\n".join(L)


# ------------------------------------------------------------------ Choix dans la galerie

func _open_picker(key: String, cfg: Dictionary) -> void:
	picker = UI.panel(Color(Pal.BG, 0.97), Pal.ACCENT)
	UI.put(self, picker, Vector2(20, 20), Vector2(600, 320))
	UI.put(picker, UI.label(Loc.t("Choisis le dessin par défaut"), 10, Pal.ACCENT), Vector2(10, 8))
	UI.put(picker, UI.hotkey(UI.button(Loc.t("Fermer"), func():
		picker.queue_free()
		picker = null), [KEY_ESCAPE]), Vector2(530, 6), Vector2(60, 16))
	var s: Vector2i = cfg.size
	# (seulement ceux qui rentrent dans la toile, d'après leurs infos : sans relire les images)
	var fits := Meta.gallery(cfg.gallery).filter(func(e):
		return Meta.info(e).has("rect") and int(e.rect[2]) <= s.x and int(e.rect[3]) <= s.y)
	UI.put(picker, DrawingGrid.new(fits, 10, Vector2(52, 52), func(e): return _picker_cell(e, key, cfg)), Vector2(10, 30), Vector2(580, 280))
	if fits.is_empty():
		UI.put(picker, UI.label(Loc.t("Aucun dessin de ta galerie n'a la bonne taille."), 10, Pal.DIM), Vector2(10, 40))


func _picker_cell(e: Dictionary, key: String, cfg: Dictionary) -> Control:
	var s: Vector2i = cfg.size
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 52)
	b.add_theme_stylebox_override("normal", UI.sbc(Pal.PAPER, Pal.BORDER, 1))
	b.add_theme_stylebox_override("hover", UI.sbc(Pal.PAPER, Pal.ACCENT, 2))
	var th := UI.drawing_thumb(e.file, Vector2(44, 44))
	th.position = Vector2(4, 4)
	b.add_child(th)
	b.tooltip_text = Loc.t("Encre : %d / %d") % [int(e.get("ink", 0)), int(cfg.ink)]
	var fx: String = e.get("effect", "")
	b.pressed.connect(func():
		var gi := Meta.gallery_image(e)
		if gi == null:
			return
		var out := Image.create_empty(s.x, s.y, false, Image.FORMAT_RGBA8)
		var t := Analyzer.trim(gi)
		@warning_ignore("integer_division")
		out.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i((s.x - t.get_width()) / 2, (s.y - t.get_height()) / 2))
		Meta.bestiary_set(key, out, fx, e.get("outline", false))   # bord : celui choisi dans la galerie
		Sfx.play("buy")
		_build())
	return b
