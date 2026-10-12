class_name ShopScreen
extends Control
## Boutique entre les vagues, mise en scène comme une GALERIE D'ART : les offres sont des tableaux
## accrochés au mur (cadre selon la rareté), avec un cartel et une étiquette de prix ;
## une pastille rouge = vendu. En bas : ta collection (armes, vitrine d'amulettes) et ton portrait.
## Les achats qui demandent un dessin sont renvoyés au Main :
## done({"a": "buy", "i": index}) / done({"a": "fuse", ...}) / done({"a": "arrange"}) / done({"a": "next"})

signal done(result)

const WALL := Color("5a2330")
const WALL_STRIPE := Color("50202b")
const GOLD := Color("d6ab4f")
const GOLD_DARK := Color("8c6414")
const WOOD := Color("3a2418")
const WOOD_PANEL := Color("4a2e1f")
const FLOOR := Color("6b4a2a")
const CARTEL := Color("efe6cf")
const CARTEL_DIM := Color("7a6a55")
const STICKER := Color("b8322a")
## Cadres selon la rareté : bois, laque bleue, laque violette, or
const FRAME := [[Color("8a5a2b"), Color("5a3818")], [Color("2f6fe0"), Color("173a7a")],
	[Color("7a3fa6"), Color("3e1d5a")], [Color("e0a830"), Color("8c6414")]]
const FRAME_HEAL := [Color("5d9a6a"), Color("2e5a38")]
const FRAME_ROULETTE := [Color("b8322a"), Color("1d1a1a")]
const FRAME_EVENT := [Color("2a8a8a"), Color("134444")]
const CASE_FRAME := [[Color("8a5a2b"), Color("4a2e14")], [Color("b8c0c8"), Color("5a6068")], [Color("e0a830"), Color("8c6414")], [Color("6ee0f0"), Color("2a8aa0")]]
const AUCTION_BIDS := 3   # Enchères : mises maximum du joueur
const EVENT_TYPES := ["roulette", "scratch", "auction", "restorer", "patron"]
const WHEEL_RED := Color("c8322a")
const WHEEL_BLACK := Color("221e1e")
const WHEEL_GREEN := Color("2f9a4a")
const WALL_BOTTOM := 212.0

var spots: Array = []      # rectangles des tableaux éclairés


var default_cache := {}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	spots = []
	var wall := _Wall.new()
	wall.shop = self
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall)

	# --- En-tête : plaques en laiton
	_plaque(Vector2(210, 4), Vector2(220, 26), (Loc.t("GALERIE · SALLE %d · INFINI") % (Run.wave + 1)) if Run.endless else (Loc.t("GALERIE · SALLE %d / %d") % [Run.wave + 1, Run.WAVES]), 10)
	var hp_col := Color("f06a5d") if Run.hp < Run.stats.max_hp * 0.35 else CARTEL
	_plaque(Vector2(10, 4), Vector2(150, 26), Loc.t("♥ %d / %d  ·  NIV %d") % [ceili(Run.hp), int(Run.stats.max_hp), Run.level], 10, hp_col)
	_plaque(Vector2(480, 4), Vector2(150, 26), Loc.t("BOURSE  ● %d") % Run.gold, 10, Pal.ACCENT)

	# --- Les tableaux accrochés
	var n := Run.shop_offers.size()
	var gap := 10.0 if n <= 4 else 6.0   # 5 offres et plus : on serre pour garder des fiches lisibles
	var fw := minf(120.0, (628.0 - (n - 1) * gap) / n)
	var total := n * fw + (n - 1) * gap
	var x0 := (640.0 - total) / 2.0
	for i in n:
		_artwork(i, Vector2(x0 + i * (fw + gap), 44), fw)

	# --- Ta collection (sur le lambris)
	UI.put(self, UI.label(Loc.t("COLLECTION %d/%d") % [Run.weapons.size(), Run.max_weapons()], 10, GOLD), Vector2(12, 216))
	# Synergies : pastille de l'élément + nombre d'armes (survol : ce que fait CETTE synergie)
	var counts := Run.synergy_counts()
	var sx := 130.0
	for e in counts:
		var on: bool = counts[e] >= Run.synergy_need()
		var txt := "%d/%d%s" % [counts[e], Run.synergy_need(), " ✓" if on else ""]
		var tw := _text_w(txt)
		var it := Control.new()
		it.mouse_filter = Control.MOUSE_FILTER_STOP
		it.tooltip_text = Loc.t("Synergie %s (%d armes %s)%s\n%s") % [Pal.NAMES[e], Run.synergy_need(), Pal.NAMES[e],
			Loc.t(" : ACTIVE") if on else "", Run.SYNERGY_DESC[e]]
		UI.put(self, it, Vector2(sx, 215), Vector2(16 + tw, 14))
		var ic := TextureRect.new()
		ic.texture = UI.element_icon(e)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.put(it, ic, Vector2(0, 0), Vector2(13, 13))
		UI.put(it, UI.label(txt, 10, Pal.ACCENT if on else Pal.DIM), Vector2(16, 0), Vector2(tw + 1, 12))
		sx += 16 + tw + 10
	for i in Run.weapons.size():
		var w: Dictionary = Run.weapons[i]
		# 7 armes (Musée ambulant) : on resserre pour ne pas mordre sur l'autoportrait
		var x := 12 + i * mini(50, 300 / maxi(1, Run.weapons.size()))
		var f := _frame_panel(FRAME[w.rar], 3)
		UI.put(self, f, Vector2(x, 230), Vector2(46, 40))
		UI.put(f, UI.thumb(Run.weapon_image(w), Vector2(36, 30)), Vector2(5, 5), Vector2(36, 30))
		f.tooltip_text = _weapon_tip(w)
		var wart := Run.art_of(w)
		var wc := Pal.color_of(w.st.get("frac", []), 0.3)
		if wc != 0:
			UI.element_badge(self, wc, Vector2(x + 32, 231))
		if wart.get("bullet") != null and not WeaponDB.get_def(w.type).get("nobullet", false):
			_bullet_badge(Vector2(x + 32, 256), 16, Analyzer.trim(wart.bullet))
		if Run.weapons.size() > 1:
			var refund := _refund(w)
			var idx := i
			var sb := UI.button("+%d" % refund, func(): _sell(idx))
			_style_tag(sb)
			sb.icon = _sell_icon()   # étiquette « à vendre »
			sb.tooltip_text = Loc.t("Revendre cette œuvre (+● %d)") % refund
			var sw := minf(44.0, mini(50, 300 / maxi(1, Run.weapons.size())) - 2.0)
			UI.put(self, sb, Vector2(x + 23 - sw / 2.0, 272), Vector2(sw, 13))
	# Fusions : un bouton par paire possible (tu choisis laquelle)
	var pairs := _fusion_pairs()
	if not pairs.is_empty():
		var frow := HBoxContainer.new()
		frow.add_theme_constant_override("separation", 3)
		UI.put(self, frow, Vector2(12, 289), Vector2(300, 14))
		for pr in pairs:
			var fdef := WeaponDB.get_def(pr[0])
			var ftype: String = pr[0]
			var frar: int = pr[1]
			var txt := Loc.t("Fusion : 2× %s → %s") % [fdef.name, Pal.RARITY_NAMES_F[frar + 1].to_lower()]
			var fb := UI.button(txt if pairs.size() == 1 else "2× %s → %s" % [fdef.name, Pal.RARITY_NAMES_F[frar + 1].to_lower()],
				func(): done.emit({"a": "fuse", "type": ftype, "rar": frar}))
			fb.tooltip_text = txt
			fb.clip_text = true
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_museum(fb)
			frow.add_child(fb)
	# Vitrine des amulettes : les doublons s'empilent (×N), et elle défile si elle est pleine
	var vit := UI.panel(Color(0.75, 0.85, 1.0, 0.12), Color(0.8, 0.9, 1.0, 0.5), 1)
	UI.put(self, vit, Vector2(12, 307), Vector2(300, 26))
	if Run.amulets.is_empty() and Run.familiars.is_empty():
		UI.put(vit, UI.label(Loc.t("vitrine des amulettes et familiers (vide)"), 10, CARTEL_DIM), Vector2(6, 5))
	var vsc := ScrollContainer.new()
	vsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.put(vit, vsc, Vector2(1, 1), Vector2(298, 24))
	_style_card_scroll(vsc, true)
	var shelf := Control.new()
	vsc.add_child(shelf)
	var groups := {}    # id -> [amulettes]
	var order := []
	for am in Run.amulets:
		if not groups.has(am.id):
			groups[am.id] = []
			order.append(am.id)
		groups[am.id].append(am)
	var ax := 3
	for aid in order:
		var ams: Array = groups[aid]
		var am: Dictionary = ams[0]
		var def := AmuletDB.get_def(aid)
		var th := UI.thumb(am.image, Vector2(16, 16))
		th.mouse_filter = Control.MOUSE_FILTER_STOP
		var zones := []
		for x in ams:
			zones.append(String(x.zone))
		th.tooltip_text = "%s%s (%s)\n%s" % [def.name, " ×%d" % ams.size() if ams.size() > 1 else "", ", ".join(zones), AmuletDB.describe(def, am.mag)]
		UI.put(shelf, th, Vector2(ax, 2), Vector2(16, 16))
		if ams.size() > 1:
			var nl := UI.label("×%d" % ams.size(), 10, Pal.TEXT)
			nl.add_theme_constant_override("outline_size", 3)
			nl.add_theme_color_override("font_outline_color", Pal.INK)
			UI.put(shelf, nl, Vector2(ax + 9, 7), Vector2(_text_w("×%d" % ams.size()) + 1, 12))
			ax += 6
		ax += 19
	# Familiers : à la suite, dans un petit cadre brun (patte)
	if not Run.familiars.is_empty() and not Run.amulets.is_empty():
		ax += 4
	for fid in Run.familiars:
		var fdef := FamiliarDB.get_def(fid)
		var fr := UI.panel(Color(0.55, 0.35, 0.17, 0.25), Pal.RARITY[int(fdef.rar)], 1)
		fr.mouse_filter = Control.MOUSE_FILTER_STOP
		fr.tooltip_text = Loc.t("Familier : %s (%s)\n%s") % [fdef.name, Pal.RARITY_NAMES[int(fdef.rar)].to_lower(), fdef.desc]
		UI.put(shelf, fr, Vector2(ax - 1, 1), Vector2(18, 18))
		var fth := UI.thumb(Run.familiar_art[fid].image if Run.familiar_art.has(fid) else _kind_icon("familiar"), Vector2(16, 16))
		fth.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.put(fr, fth, Vector2(1, 1), Vector2(16, 16))
		ax += 20
	shelf.custom_minimum_size = Vector2(ax + 2, 20)

	# --- Ton portrait + cartel de stats
	var pf := _frame_panel(FRAME[3], 5)
	UI.put(self, pf, Vector2(322, 218), Vector2(64, 76))
	UI.put(pf, UI.thumb(Run.build_player_image(Run.show_amulets()), Vector2(52, 64)), Vector2(6, 6), Vector2(52, 64))
	pf.tooltip_text = Loc.t("Ton perso\n") + Pal.color_line(Run.char_a.get("frac", []))
	# Sous l'autoportrait : taille du perso (pixels dessinés) et couleurs, utiles pour Silhouette / Nuancier
	var npx := int(Run.char_a.get("pixels", 0))
	var ncol := int(Run.char_a.get("elements", 0))
	var px := UI.label(Loc.t("%d px\n%d couleur%s") % [npx, ncol, "s" if ncol > 1 else ""], 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	px.mouse_filter = Control.MOUSE_FILTER_STOP
	px.tooltip_text = Loc.t("Autoportrait\nTaille de ton perso : %d pixels dessinés\nCouleurs (éléments) sur ton perso : %d\n%s") % [npx, ncol, Pal.color_line(Run.char_a.get("frac", []))]
	UI.put(self, px, Vector2(312, 296), Vector2(84, 26))
	var ct := UI.panel(CARTEL, Color("b9a883"), 1)
	UI.put(self, ct, Vector2(392, 216), Vector2(238, 112))
	var stx := StatText.new(4, Pal.INK)   # icônes des stats (le nom au survol) ; 4 colonnes : tout tient, même avec les 7 résistances
	stx.stretch = true   # les lignes s'écartent pour remplir le cartel
	UI.put(ct, stx, Vector2(5, 4), Vector2(228, 104))
	stx.set_text(Stats.describe_player(Run.stats))

	# --- Actions (plaques de musée)
	var rp := Run.reroll_price()
	var rb := UI.hotkey(UI.button(Loc.t("Actualiser la galerie (%s)") % (Loc.t("gratuit") if rp == 0 else "● %d" % rp), _reroll), [KEY_R])
	_style_museum(rb)
	rb.disabled = Run.cash() < rp
	var odds := Run.rarity_odds()
	rb.tooltip_text = Loc.t("Relancer : de nouvelles œuvres (de plus en plus cher)\nChances par œuvre : rare %d%% · épique %d%% · légendaire %d%%") % [roundi(odds[0]), roundi(odds[1]), roundi(odds[2])]
	UI.put(self, rb, Vector2(12, 336), Vector2(192, 18))
	var ab := UI.hotkey(UI.button(Loc.t("Ranger mes armes"), func(): done.emit({"a": "arrange"})), [KEY_A])
	_style_museum(ab)
	ab.tooltip_text = Loc.t("Déplace, tourne ou retourne tes armes sur ton perso")
	UI.put(self, ab, Vector2(208, 336), Vector2(112, 18))
	var sq := UI.button(Loc.t("Sauvegarder et quitter"), func(): done.emit({"a": "suspend"}))
	_style_museum(sq)
	sq.tooltip_text = Loc.t("Retour au menu : tu reprendras ici, dans cette boutique.")
	UI.put(self, sq, Vector2(324, 336), Vector2(158, 18))
	var nb := UI.hotkey(UI.button(Loc.t("Salle suivante →"), func(): done.emit({"a": "next"})), [KEY_ENTER, KEY_KP_ENTER])
	_style_museum(nb)
	UI.put(self, nb, Vector2(488, 334), Vector2(142, 22))


# ------------------------------------------------------------------ Tableaux

func _artwork(i: int, pos: Vector2, fw: float) -> void:
	var o: Dictionary = Run.shop_offers[i]
	var oname := ""
	var kind := ""
	var desc := ""
	var full := false
	var icon: Image = Gfx.icon(Gfx.ICON_UNKNOWN)   # pas encore dessiné : un point d'interrogation
	var bullet_icon: Image = null   # arme à distance déjà dessinée : ses balles, en médaillon
	var wcolor := 0                 # arme déjà dessinée : sa couleur (cercle des faiblesses)
	var frame_cols: Array = FRAME[o.rar]
	match o.type:
		"weapon":
			var def := WeaponDB.get_def(o.wtype)
			var near := Run.closest_art(o.wtype, o.rar)
			var dflt: Image = _default_img(Run.weapon_key(o.wtype, o.rar))
			if Run.has_art(o.wtype, o.rar):
				icon = Analyzer.trim(near.image)
			elif dflt:
				icon = dflt
			elif not near.is_empty():
				icon = Analyzer.trim(near.image)
			if def.kind == "ranged" and not def.get("nobullet", false):
				if not near.is_empty() and near.get("bullet") != null:
					bullet_icon = Analyzer.trim(near.bullet)
				else:
					bullet_icon = _default_img("balle_" + o.wtype)
			oname = def.name
			kind = "%s · %s" % [Loc.t("Mêlée") if def.kind == "melee" else Loc.t("Distance"), Pal.RARITY_NAMES_F[o.rar].to_lower()]
			desc = def.desc
			wcolor = _offer_color(o.wtype, o.rar, near)
			if wcolor != 0:
				desc += Loc.t("\nCouleur : ") + Pal.color_name(wcolor)
			if Run.has_art(o.wtype, o.rar):
				desc += Loc.t("\n✓ Dessinée")
			elif dflt:
				desc += Loc.t("\nDessin du Codex")
			elif Run.has_any_art(o.wtype):
				desc += Loc.t("\nÀ redessiner")
			else:
				var mult: float = WeaponDB.RAR_INK[o.rar]
				desc += Loc.t("\nEncre %d") % roundi(def.ink * mult) + ("+%d" % roundi(def.bink * mult) if def.kind == "ranged" else "")
			if o.rar > 0:
				desc += " · ×%s" % ["", "1,8", "3,2", "6"][o.rar]
			if def.has("scale"):
				# Arme à ratio : la valeur ACTUELLE d'abord (le cartel est petit)
				desc += Loc.t("\nActuellement : ") + Stats.scale_text(def.scale, o.rar).replace(Loc.t("Ratio : "), "")
			full = Run.weapons.size() >= Run.max_weapons() and Run.fusion_match(o.wtype, o.rar) < 0
			if Run.weapons.size() >= Run.max_weapons() and not full:
				desc += Loc.t("\n→ fusionne !")
		"amulet":
			var def := AmuletDB.get_def(o.id)
			oname = def.name
			kind = Pal.RARITY_NAMES_F[o.rar]
			desc = AmuletDB.describe(def)
			if Run.amulet_art.has(o.id):
				icon = Run.amulet_art[o.id].image
			elif _default_img("amulette_" + o.id):
				icon = _default_img("amulette_" + o.id)
		"heal":
			var h: Dictionary = Run.HEALS[o.id]
			oname = h.name
			kind = Loc.t("Consommable")
			desc = h.desc
			frame_cols = FRAME_HEAL
			full = Run.hp >= Run.stats.max_hp and h.heal > 0.0
			if o.id == "seve":
				full = Run.regen_boost > 0.0
			if Run.amulet_count("pacte_sang") > 0 and o.id != "encre":
				full = true   # Pacte de sang : les potions ne marchent plus
			var liquid: Color = {"grande_potion": Pal.SHADES[1][1], "seve": Pal.main_color(Pal.POISON), "encre": Pal.INK}.get(o.id, Pal.SHADES[4][1])
			icon = Gfx.icon(Gfx.ICON_POTION, liquid)
		"roulette":
			oname = Loc.t("Roulette")
			kind = Loc.t("Jeu de hasard")
			desc = Loc.t("Mise ton or : Rouge ou Noir ×2, Vert ×36.")
			frame_cols = FRAME_ROULETTE
			icon = _wheel_icon()
		"familiar":
			var fdef := FamiliarDB.get_def(o.id)
			oname = fdef.name
			kind = Pal.RARITY_NAMES[o.rar]
			desc = fdef.desc
			if Run.familiar_art.has(o.id):
				icon = Run.familiar_art[o.id].image
			elif _default_img("familier_" + o.id):
				icon = _default_img("familier_" + o.id)
		"case":
			var kname := Loc.t("Armes") if o.kind == "weapon" else Loc.t("Amulettes")
			oname = "%s" % Run.CASE_NAMES[o.tier]
			kind = Loc.t("Caisse · %s") % kname
			var od: Array = Run.CASE_ODDS[o.tier]
			var parts := []
			for r in 4:
				if od[r] > 0.0:
					parts.append("%s %d%%" % [[Loc.t("Com."), Loc.t("Rare"), Loc.t("Épi."), Loc.t("Lég.")][r], roundi(od[r])])
			desc = " · ".join(parts)
			frame_cols = CASE_FRAME[o.tier]
			icon = _case_icon(o.tier, o.kind)
			if o.kind == "weapon" and Run.weapons.size() >= Run.max_weapons():
				full = true
		"scratch":
			oname = Loc.t("Ticket à gratter")
			kind = Loc.t("Jeu de hasard")
			desc = Loc.t("Permet de gagner des prix.")
			frame_cols = FRAME_EVENT
			icon = _event_icon("scratch")
		"auction":
			var it: Dictionary = o.item
			oname = Loc.t("Vente aux enchères")
			kind = "%s · %s" % [_item_name(it), Pal.RARITY_NAMES_F[it.rar].to_lower()]
			desc = Loc.t("Enchéris contre un collectionneur. Départ : ● %d") % int(o.bid)
			frame_cols = FRAME[it.rar]
			icon = _event_icon("auction")
		"restorer":
			oname = Loc.t("Le Restaurateur")
			kind = Loc.t("Visiteur")
			desc = Loc.t("Améliore une de tes amulettes : rareté au-dessus, au hasard.")
			frame_cols = FRAME_EVENT
			icon = _event_icon("restorer")
		"patron":
			oname = Loc.t("Le Mécène")
			kind = Loc.t("Visiteur")
			desc = Loc.t("De l'or tout de suite... contre une vague plus dure.")
			frame_cols = FRAME_EVENT
			icon = _event_icon("patron")

	# Le tableau : cadre + toile
	var frame := _frame_panel(frame_cols, 5)
	UI.put(self, frame, pos, Vector2(fw, 64))
	spots.append(Rect2(pos, Vector2(fw, 64)))
	var pic := UI.thumb(icon, Vector2(fw - 16, 48))
	UI.put(frame, pic, Vector2(8, 8), Vector2(fw - 16, 48))
	if bullet_icon:
		_bullet_badge(pos + Vector2(fw - 20, 44), 18, bullet_icon)
	if wcolor != 0:
		UI.element_badge(self, wcolor, pos + Vector2(fw - 16, 3))
	frame.tooltip_text = kind if o.type in EVENT_TYPES or o.type in ["heal", "case"] else Pal.RARITY_NAMES_F[o.rar]
	# Petite icône : arme ou amulette (aussi pour les caisses et les enchères)
	var ik := ""
	if o.type in ["weapon", "amulet", "familiar"]:
		ik = o.type
	elif o.type == "case":
		ik = o.kind
	elif o.type == "auction":
		ik = o.item.type
	if ik != "":
		var badge := UI.panel(CARTEL, GOLD_DARK, 1)
		badge.tooltip_text = {"weapon": Loc.t("Arme"), "amulet": Loc.t("Amulette"), "familiar": Loc.t("Familier")}[ik]
		UI.put(self, badge, pos + Vector2(2, 2), Vector2(16, 16))
		UI.put(badge, UI.thumb(_kind_icon(ik), Vector2(12, 12)), Vector2(2, 2), Vector2(12, 12))
	if o.get("new", false) and not o.sold:
		var ukey := ItemUnlockDB.key_weapon(o.wtype) if o.type == "weapon" else ItemUnlockDB.key_amulet(o.id)
		if ItemUnlockDB.CONDS.has(ukey):
			_unlock_badge(frame, pos, fw)
		else:
			# Jamais vue : petite pastille « ! » dans le coin du cadre
			var nb := UI.panel(Pal.ACCENT, GOLD_DARK, 1)
			nb.tooltip_text = Loc.t("Nouveau : jamais vu en boutique")
			UI.put(self, nb, pos + Vector2(fw - 10, -4), Vector2(14, 14))
			UI.put(nb, UI.label("!", 10, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 1), Vector2(14, 12))
	if o.type == "weapon" and o.rar > 0:
		frame.tooltip_text += Loc.t("\nDégâts ×%s · vitesse d'attaque +%d%% · critique +%d%%\nAllonge +%d%% (mêlée) · perforation +%d (distance) · effets élémentaires +%d%%") % [
			str(Stats.RAR_DMG[o.rar]), Stats.RAR_ATK[o.rar], Stats.RAR_CRIT[o.rar],
			roundi((Stats.RAR_REACH[o.rar] - 1.0) * 100.0), Stats.RAR_PIERCE[o.rar], roundi(Stats.RAR_PROC[o.rar] * 100.0)]

	# Le cartel
	var ct := UI.panel(CARTEL, Color("b9a883"), 1)
	UI.put(self, ct, pos + Vector2(-2, 70), Vector2(fw + 4, 100))
	ct.tooltip_text = "%s — %s\n%s" % [oname, kind, desc]   # texte complet au survol
	if o.type == "weapon":
		_weapon_card(ct, o, fw)   # fiche détaillée : stats et ratio
	else:
		var nl := UI.label(oname, 10, Pal.INK)
		nl.clip_text = true
		UI.put(ct, nl, Vector2(4, 2), Vector2(fw - 4, 12))
		var kl := UI.label(kind, 10, CARTEL_DIM)
		kl.clip_text = true
		UI.put(ct, kl, Vector2(4, 14), Vector2(fw - 4, 12))
		_scroll_box(ct, fw, [], desc, "", CARTEL_DIM, false)
	if o.sold:
		# Pastille rouge des galeries : œuvre vendue
		var dot := _Dot.new()
		UI.put(ct, dot, Vector2(fw - 14, 83), Vector2(14, 14))
		var sold_txt: String = {"case": Loc.t("OUVERTE"), "roulette": Loc.t("JOUÉ"), "scratch": Loc.t("JOUÉ"), "auction": Loc.t("ADJUGÉ"), "restorer": Loc.t("PARTI"), "patron": Loc.t("PARTI")}.get(o.type, Loc.t("VENDU"))
		UI.put(ct, UI.label(sold_txt, 10, STICKER), Vector2(4, 85), Vector2(fw - 20, 12))
		frame.modulate = Color(1, 1, 1, 0.55)
		return
	var btxt: String = {"roulette": Loc.t("Miser"), "auction": Loc.t("Enchérir"), "restorer": Loc.t("Choisir"), "patron": Loc.t("Écouter")}.get(o.type, "● %d" % o.price)
	var b := UI.button(btxt, func(): _buy(i))
	_style_price(b)
	b.disabled = Run.cash() < o.price or full or (o.type == "roulette" and Run.gold < 1)
	if o.type == "auction":
		b.disabled = Run.gold <= int(o.bid)
	elif o.type == "restorer":
		b.disabled = Run.restorable().is_empty()
	if full and o.type == "heal" and o.id != "encre" and Run.amulet_count("pacte_sang") > 0:
		b.tooltip_text = Loc.t("Pacte de sang : les potions ne marchent plus.")
	elif full and o.type == "case":
		b.tooltip_text = Loc.t("Plus de place pour une arme : revends-en une d'abord.")
	elif full and o.get("id", "") == "seve":
		b.tooltip_text = Loc.t("Tu as déjà un Élixir de sève pour la vague suivante.")
	elif full and o.type == "weapon":
		b.tooltip_text = Loc.t("Tu as déjà %d armes : revends-en une.") % Run.max_weapons()
	elif full:
		b.tooltip_text = Loc.t("Tes PV sont déjà au max.")
	UI.put(ct, b, Vector2(fw - 50, 83), Vector2(52, 15))


## Objet débloqué par un succès, vu pour la première fois : gros « ! » qui pulse,
## halo doré qui clignote autour du cadre et ruban « DÉBLOQUÉ ».
func _unlock_badge(frame: Control, pos: Vector2, fw: float) -> void:
	var halo := UI.panel(Color(1, 0.85, 0.3, 0.0), Color("ffe066"), 3)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(self, halo, pos - Vector2(4, 4), Vector2(fw + 8, 72))
	move_child(halo, frame.get_index())   # derrière le tableau
	var ribbon := UI.panel(Color("e8356b"), Color("ffe066"), 1)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(self, ribbon, pos + Vector2(6, 52), Vector2(fw - 12, 14))
	UI.put(ribbon, UI.label(Loc.t("DÉBLOQUÉ"), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 1), Vector2(fw - 12, 12))
	var nb := UI.panel(Color("e8356b"), Color("ffe066"), 2)
	nb.tooltip_text = Loc.t("Nouveau ! Débloqué grâce à un succès, jamais vu en boutique")
	UI.put(self, nb, pos + Vector2(fw - 16, -9), Vector2(24, 24))
	UI.put(nb, UI.label("!", 20, Color("ffe066"), HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 0), Vector2(24, 24))
	nb.pivot_offset = Vector2(12, 12)
	nb.rotation = 0.2
	var tw := nb.create_tween().set_loops()
	tw.tween_property(nb, "scale", Vector2(1.25, 1.25), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nb, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
	var th := halo.create_tween().set_loops()
	th.tween_property(halo, "modulate:a", 0.25, 0.5)
	th.tween_property(halo, "modulate:a", 1.0, 0.5)


# ------------------------------------------------------------------ Styles « musée »

## Dessin par défaut du Codex (montré en vitrine tant que l'objet n'est pas acheté).
## Arme en vente telle qu'on la connaît : son dessin dans la partie, sinon celui du Codex,
## sinon (average = true) un dessin « moyen » qui utilise la moitié de son encre. {} si inconnue.
func _offer_weapon(wtype: String, rar: int, near: Dictionary, average := false) -> Dictionary:
	var def := WeaponDB.get_def(wtype)
	var img: Image = null
	var effect := ""
	var bullet: Image = null
	if Run.has_art(wtype, rar) or (not near.is_empty() and _default_img(Run.weapon_key(wtype, rar)) == null):
		img = near.image
		effect = near.effect
		bullet = near.get("bullet")
	else:
		var d = Meta.bestiary_get(Run.weapon_key(wtype, rar))
		if d != null:
			img = d.image
			effect = d.get("effect", "")
			var db = Meta.bestiary_get("balle_" + wtype)
			bullet = db.image if db != null else null
		elif average:
			img = _avg_drawing(roundi(def.ink * WeaponDB.RAR_INK[rar]), int(def.canvas))
			if def.kind == "ranged" and not def.get("nobullet", false):
				bullet = _avg_drawing(roundi(def.bink * WeaponDB.RAR_INK[rar]), int(def.bcanvas))
		else:
			return {}
	if def.kind == "ranged" and bullet == null and not def.get("nobullet", false):
		bullet = WeaponDB.orb()
	return {"type": wtype, "rar": rar, "a": Analyzer.analyze(img), "effect": effect,
		"bullet": bullet, "ba": Analyzer.analyze(bullet) if bullet else {}, "beffect": ""}


## Dessin « moyen » : un carré plein dont le contour coûte la moitié de l'encre.
func _avg_drawing(ink: int, canvas: int) -> Image:
	var n := clampi(int(ink / 8.0) + 1, 2, canvas)
	var img := Image.create_empty(canvas, canvas, false, Image.FORMAT_RGBA8)
	@warning_ignore("integer_division")
	var o := (canvas - n) / 2
	img.fill_rect(Rect2i(o, o, n, n), Pal.SHADES[0][1])
	return img


## Couleur d'une arme en vente, si on connaît déjà son dessin (dans la partie ou dans le Codex).
func _offer_color(wtype: String, rar: int, near: Dictionary) -> int:
	var w := _offer_weapon(wtype, rar, near)
	if w.is_empty():
		return 0
	return Pal.color_of(Stats.weapon(w).get("frac", []), 0.3)


## Ratio d'une arme, en court (entre parenthèses sur la ligne de ses dégâts).
static var SCALE_SHORT := {
	"free_slots": "+60 % / place libre", "max_hp": "+15 % PV max", "armor": "+1,5 × armure",
	"speed": "+1 % / % vitesse", "luck": "+0,25 × chance", "gold": "+1 / 12 or",
	"range": "+1,5 % / % portée", "colors": "+35 % / couleur", "pixels": "selon ta taille",
	"lifesteal": "vol de vie ×3",
}
const CARD_LABEL := Color("8c5a14")   # libellés des stats (laiton foncé)
const CARD_RATIO := Color("2c6b3a")   # ratio entre parenthèses (vert)


## Fiche d'une arme en vente (à la place du cartel) : nom, type, puis ses stats
## (Dégâts, Critique, Recharge, Portée / Allonge), avec le ratio entre parenthèses.
## Pas encore dessinée : stats d'un dessin moyen, précédées de « ≈ ».
func _weapon_card(ct: Control, o: Dictionary, fw: float) -> void:
	var def := WeaponDB.get_def(o.wtype)
	var near := Run.closest_art(o.wtype, o.rar)
	var known := not _offer_weapon(o.wtype, o.rar, near).is_empty()
	var st := Stats.weapon(_offer_weapon(o.wtype, o.rar, near, true))
	var approx := "" if known else "≈"
	var scale: String = def.get("scale", "")
	var nl := UI.label(def.name, 10, Pal.INK)
	nl.clip_text = true
	UI.put(ct, nl, Vector2(4, 2), Vector2(fw - 4, 12))
	var tag := "%s · %s" % [Loc.t("Mêlée") if def.kind == "melee" else Loc.t("Distance"), Pal.RARITY_NAMES_F[o.rar].to_lower()]
	var kl := UI.label(tag, 10, CARTEL_DIM)
	kl.clip_text = true
	UI.put(ct, kl, Vector2(4, 14), Vector2(fw - 4, 12))
	# Dégâts d'un coup (ratio compris, comme en jeu) ; à distance : tous les projectiles d'un tir
	var dmg := 0.0
	var shots := ""
	if st.kind == "melee":
		dmg = float(st.damage)
	else:
		for b in st.bullets:
			dmg += float(b.damage)
		if int(st.pellets) > 1:
			shots = " ×%d" % int(st.pellets)
	if scale != "" and scale != "crit" and scale != "lifesteal":
		dmg = Stats.scaled_damage(dmg, scale, o.rar)
	var ratio := ""
	if SCALE_SHORT.has(scale):
		ratio = "(%s)" % SCALE_SHORT[scale]
	var lines := [[Loc.t("Dégâts"), "%s%s%s" % [approx, _num(dmg), shots], ratio]]
	var crit_ratio := Loc.t("(×2 + crit ÷ 35)") if scale == "crit" else ""
	lines.append([Loc.t("Critique"), "%s%d %%" % [approx, roundi(st.crit)], crit_ratio])
	lines.append([Loc.t("Recharge"), "%s%ss" % [approx, _num(st.cooldown, 2)], ""])
	if st.kind == "melee":
		lines.append([Loc.t("Allonge"), "%s%d" % [approx, roundi(st.reach)], ""])
	else:
		lines.append([Loc.t("Portée"), "%s%d" % [approx, roundi(st.range)], ""])
	# Stats + description dans une zone qui défile (barre de défilement si ça déborde du cadre)
	var desc := String(def.get("card", def.desc))   # le ratio est déjà sur la ligne des dégâts
	for pre in [Loc.t("Épique+. "), Loc.t("Légendaire. ")]:
		desc = desc.trim_prefix(pre)
	var foot := ""
	var foot_col := CARTEL_DIM
	if Run.weapons.size() >= Run.max_weapons() and Run.fusion_match(o.wtype, o.rar) >= 0:
		foot = Loc.t("→ fusionne !")
		foot_col = CARD_RATIO
	elif Run.has_art(o.wtype, o.rar):
		foot = Loc.t("✓ dessinée")
	elif not known:
		foot = Loc.t("à dessiner")
	_scroll_box(ct, fw, lines, desc, foot, foot_col)


## Zone du cartel sous le nom : lignes de stats, mention, puis description. Elle défile
## (fine barre) quand tout ne tient pas, et rien ne peut sortir du cadre.
func _scroll_box(ct: Control, fw: float, lines: Array, desc: String, foot: String, foot_col: Color, bullet := true) -> void:
	var box_h := 55.0
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	UI.put(ct, sc, Vector2(2, 26), Vector2(fw + 1, box_h))
	_style_card_scroll(sc)
	var content := _card_content(lines, desc, fw - 2, foot, foot_col, bullet)
	if content.get_meta("h", 0.0) > box_h:
		content.free()
		content = _card_content(lines, desc, fw - 10, foot, foot_col, bullet)   # place pour la barre
	sc.add_child(content)


## Contenu de la fiche (largeur w) : les lignes de stats, puis la description (« • … »).
func _card_content(lines: Array, desc: String, w: float, foot := "", foot_col := CARTEL_DIM, bullet := true) -> Control:
	var box := VBoxContainer.new()   # les lignes (stats, mention), puis la description en texte riche
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.custom_minimum_size.x = w
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(content)
	var y := 0.0
	for ln in lines:
		y = _card_line(content, Vector2(2, y), w - 2, ln[0], ln[1], ln[2])
	for ln in _wrap(foot, w - 4):
		_card_text(content, Vector2(2, y), ln, foot_col)
		y += 11.0
	if desc != "" and not lines.is_empty():
		y += 2.0
	content.custom_minimum_size = Vector2(w, y)
	var h := y
	if desc != "":
		# Description : les quantités de stats en icônes (« +4 » + cœur)
		var txt := ("• " if bullet else "") + desc
		var rl := UI.rich(txt, 10, Pal.INK, 11)
		rl.custom_minimum_size.x = w - 4
		var mc := MarginContainer.new()
		mc.add_theme_constant_override("margin_left", 2)
		mc.mouse_filter = Control.MOUSE_FILTER_PASS
		mc.add_child(rl)
		box.add_child(mc)
		h += UI.font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w - 4, UI.fs(10)).y   # (estimation)
	box.set_meta("h", h + 3.0)
	return box


## Coupe un texte en lignes de largeur w (mot par mot ; un mot trop long est coupé).
func _wrap(text: String, w: float) -> Array:
	var out := []
	if "\n" in text:
		for part in text.split("\n"):
			out.append_array(_wrap(part, w))
		return out
	var cur := ""
	for word in text.split(" ", false):
		var tryl := word if cur == "" else cur + " " + word
		if _text_w(tryl) <= w:
			cur = tryl
			continue
		if cur != "":
			out.append(cur)
		cur = word
		while _text_w(cur) > w and cur.length() > 1:
			var k := cur.length() - 1
			while k > 1 and _text_w(cur.substr(0, k)) > w:
				k -= 1
			out.append(cur.substr(0, k))
			cur = cur.substr(k)
	if cur != "":
		out.append(cur)
	return out


## Barre de défilement fine, aux couleurs du cartel.
func _style_card_scroll(sc: ScrollContainer, horizontal := false) -> void:
	var bar: ScrollBar = sc.get_h_scroll_bar() if horizontal else sc.get_v_scroll_bar()
	if horizontal:
		bar.custom_minimum_size.y = 4
	else:
		bar.custom_minimum_size.x = 6
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("d9ccae")
	bar.add_theme_stylebox_override("scroll", bg)
	var gr := StyleBoxFlat.new()
	gr.bg_color = GOLD_DARK
	bar.add_theme_stylebox_override("grabber", gr)
	var grh := StyleBoxFlat.new()
	grh.bg_color = GOLD
	bar.add_theme_stylebox_override("grabber_highlight", grh)
	bar.add_theme_stylebox_override("grabber_pressed", grh)


## Une ligne de la fiche : « Libellé : valeur (ratio) », le libellé en laiton, le ratio en vert.
## Le ratio passe à la ligne s'il ne tient pas. Retourne le y de la ligne suivante.
func _card_line(ct: Control, pos: Vector2, w: float, lab: String, val: String, ratio: String) -> float:
	var x := pos.x
	var y := pos.y
	var sep := " : " if Loc.lang == "fr" else ": "
	if _text_w(lab + sep + val) > w:
		sep = ": "   # ligne trop longue : on serre un peu
	x = _card_text(ct, Vector2(x, y), lab + sep, CARD_LABEL)
	if x + _text_w(val) > pos.x + w:
		# même serrée, la valeur ne tient pas (fiche étroite) : elle passe à la ligne
		y += 11.0
		x = pos.x + 6.0
	x = _card_text(ct, Vector2(x, y), val, Pal.INK)
	if ratio != "":
		# Le ratio, avec l'icône de la stat dont dépend l'arme (« (+15 % ❤) »)
		if x + _text_w(" " + ratio) <= pos.x + w:
			_card_rich(ct, Vector2(x, y), " " + ratio, w - (x - pos.x))
		else:
			# à la ligne (et sur plusieurs lignes s'il le faut)
			y += 11.0
			y += _card_rich(ct, Vector2(pos.x + 6.0, y), ratio, w - 6.0) - 11.0
	return y + 11.0


## Texte du ratio en vert, les stats en icônes. Retourne sa hauteur.
func _card_rich(ct: Control, pos: Vector2, t: String, w: float) -> float:
	var rl := UI.rich(t, 10, CARD_RATIO, 11)
	rl.custom_minimum_size.x = w
	# hauteur : le texte avec chaque icône comptée comme une lettre large (pas le mot qu'elle remplace)
	var est := UI.stat_bbcode(t)
	var re := RegEx.create_from_string(Loc.t("\\[img[^\\]]*\\][^\\[]*\\[/img\\]"))
	est = re.sub(est, "M", true)
	var h := UI.font.get_multiline_string_size(est, HORIZONTAL_ALIGNMENT_LEFT, w, UI.fs(10)).y
	UI.put(ct, rl, pos + Vector2(0, -1), Vector2(w, h))
	return h


func _text_w(t: String) -> float:
	return UI.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10)).x


func _card_text(ct: Control, pos: Vector2, t: String, col: Color) -> float:
	var w := _text_w(t)
	UI.put(ct, UI.label(t, 10, col), pos, Vector2(w + 1.0, 12))
	return pos.x + w


## Nombre à la française (virgule), sans décimale inutile.
func _num(v: float, dec := 1) -> String:
	if dec == 1 and absf(v - roundf(v)) < 0.05:
		return str(roundi(v))
	return (("%." + str(dec) + "f") % v).replace(".", ",")


## Médaillon des balles d'une arme à distance, posé dans le coin du cadre.
func _bullet_badge(at: Vector2, n: int, img: Image) -> void:
	var badge := UI.panel(CARTEL, GOLD_DARK, 1)
	badge.tooltip_text = Loc.t("Ses balles")
	UI.put(self, badge, at, Vector2(n, n))
	UI.put(badge, UI.thumb(img, Vector2(n - 4, n - 4)), Vector2(2, 2), Vector2(n - 4, n - 4))


func _default_img(key: String) -> Image:
	if not default_cache.has(key):
		var d = Meta.bestiary_get(key)
		default_cache[key] = Analyzer.trim(d.image) if d != null else null
	return default_cache[key]


func _frame_panel(cols: Array, bw: int) -> Panel:
	var s := UI.sb(Pal.PAPER, cols[0], bw, 0, 0)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 3
	s.shadow_offset = Vector2(2, 3)
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", s)
	var inner := Panel.new()
	inner.add_theme_stylebox_override("panel", UI.sb(Color(0, 0, 0, 0), cols[1], 1, 0, 0))
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = bw - 1
	inner.offset_top = bw - 1
	inner.offset_right = -bw + 1
	inner.offset_bottom = -bw + 1
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	return p


func _plaque(pos: Vector2, size: Vector2, text: String, fs: int, col := Pal.INK) -> void:
	var p := UI.panel(WOOD, GOLD, 2)
	UI.put(self, p, pos, size)
	UI.put(p, UI.label(text, fs, col if col != Pal.INK else GOLD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, (size.y - 12) / 2.0), Vector2(size.x, 12))


func _style_museum(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.sb(WOOD, GOLD_DARK, 1))
	b.add_theme_stylebox_override("hover", UI.sb(WOOD_PANEL, GOLD, 1))
	b.add_theme_stylebox_override("pressed", UI.sb(GOLD, GOLD, 1))
	b.add_theme_stylebox_override("disabled", UI.sb(Color("2a1a12"), Color("4a3524"), 1))
	b.add_theme_color_override("font_color", UI.BTN_TEXT)
	b.add_theme_color_override("font_hover_color", Pal.ACCENT)


func _style_price(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.sb(Pal.INK, Pal.INK, 1, 2, 1))
	b.add_theme_stylebox_override("hover", UI.sb(Color("3d3450"), Pal.ACCENT, 1, 2, 1))
	b.add_theme_stylebox_override("pressed", UI.sb(Pal.ACCENT, Pal.ACCENT, 1, 2, 1))
	b.add_theme_stylebox_override("disabled", UI.sb(Color("cfc3a6"), Color("b9a883"), 1, 2, 1))
	b.add_theme_color_override("font_color", Pal.ACCENT)
	b.add_theme_color_override("font_disabled_color", CARTEL_DIM)


## Petite étiquette de prix (bouton « revendre »).
var _sell_tex: Texture2D


func _sell_icon() -> Texture2D:
	if _sell_tex == null:
		var rows := ["...#########", "..#ooooooooo#", ".#ooooooooo#", "#oo##oooooo#", "#oo##oooooo#", ".#ooooooooo#", "..#ooooooooo#", "...#########"]
		var img := Image.create_empty(13, 8, false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				match rows[y][x]:
					"#":
						img.set_pixel(x, y, GOLD_DARK)
					"o":
						img.set_pixel(x, y, Pal.ACCENT)
		_sell_tex = ImageTexture.create_from_image(img)
	return _sell_tex


func _style_tag(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UI.sb(CARTEL, Color("b9a883"), 1, 3, 0))   # (3 px : l'icône respire)
	b.add_theme_stylebox_override("hover", UI.sb(Color.WHITE, Pal.ACCENT, 1, 3, 0))
	b.add_theme_color_override("font_color", Pal.INK)
	b.add_theme_color_override("font_hover_color", Pal.INK)


class _Dot extends Control:
	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, ShopScreen.STICKER)
		draw_circle(size / 2.0 - Vector2(2, 2), 1.5, Color(1, 1, 1, 0.6))


## Mur tapissé, cimaise dorée, spots au-dessus des tableaux, lambris et parquet.
class _Wall extends Control:
	var shop: ShopScreen

	func _draw() -> void:
		var W := 640.0
		var wb := ShopScreen.WALL_BOTTOM
		draw_rect(Rect2(0, 0, W, wb), ShopScreen.WALL)
		for x in range(0, 640, 12):
			draw_rect(Rect2(x, 0, 5, wb), ShopScreen.WALL_STRIPE)
		# cimaise (rail d'accrochage)
		draw_rect(Rect2(0, 36, W, 2), ShopScreen.GOLD_DARK)
		# spots : lampe en laiton + cône de lumière
		for r: Rect2 in shop.spots:
			var cx := r.position.x + r.size.x / 2.0
			var pts := PackedVector2Array([Vector2(cx - 5, 38), Vector2(cx + 5, 38),
				Vector2(r.end.x + 10, r.end.y + 6), Vector2(r.position.x - 10, r.end.y + 6)])
			draw_colored_polygon(pts, Color(1.0, 0.93, 0.7, 0.09))
			draw_rect(Rect2(cx - 6, 34, 12, 4), ShopScreen.GOLD)
			draw_line(Vector2(r.position.x + 6, 38), Vector2(cx, 30), Color(ShopScreen.GOLD_DARK, 0.6), 1.0)
			draw_line(Vector2(r.end.x - 6, 38), Vector2(cx, 30), Color(ShopScreen.GOLD_DARK, 0.6), 1.0)
		# lambris
		draw_rect(Rect2(0, wb, W, 332 - wb), ShopScreen.WOOD)
		draw_rect(Rect2(0, wb, W, 2), ShopScreen.GOLD_DARK)
		for x in range(8, 640, 106):
			draw_rect(Rect2(x, wb + 10, 96, 106), ShopScreen.WOOD_PANEL, false, 1.0)
		# parquet
		draw_rect(Rect2(0, 332, W, 28), ShopScreen.FLOOR)
		for x in range(0, 640, 40):
			draw_line(Vector2(x, 332), Vector2(x, 360), Color(0, 0, 0, 0.2), 1.0)
		draw_rect(Rect2(0, 332, W, 1), Color(0, 0, 0, 0.35))


# ------------------------------------------------------------------ Logique (inchangée)

## Toutes les fusions possibles : [type, rareté] (une par paire différente).
func _fusion_pairs() -> Array:
	var out := []
	var seen := {}
	for i in Run.weapons.size():
		var a: Dictionary = Run.weapons[i]
		if a.rar >= 3 or seen.has("%s#%d" % [a.type, a.rar]):
			continue
		for j in range(i + 1, Run.weapons.size()):
			var b: Dictionary = Run.weapons[j]
			if b.type == a.type and b.rar == a.rar:
				seen["%s#%d" % [a.type, a.rar]] = true
				out.append([a.type, a.rar])
				break
	return out


func _buy(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if o.type == "roulette":
		_open_roulette(i)
		return
	match o.type:
		"case":
			_open_case(i)
			return
		"scratch":
			_open_scratch(i)
			return
		"auction":
			_open_auction(i)
			return
		"restorer":
			_open_restorer(i)
			return
		"patron":
			_open_patron(i)
			return
	if o.type != "heal":
		done.emit({"a": "buy", "i": i})
		return
	if o.id == "encre":
		done.emit({"a": "ink", "i": i})   # retouche du perso : géré par le Main
		return
	if Run.cash() < o.price:
		return
	Run.spend(o.price)
	Run.log_event("buy", Loc.t("Achat : %s (● %d)") % [Run.HEALS[o.id].name, o.price])
	if Run.HEALS[o.id].has("regen"):
		Run.regen_boost = float(Run.HEALS[o.id].regen)   # Élixir de sève : vague suivante
	else:
		Run.heal(Run.stats.max_hp * Run.HEALS[o.id].heal * (1.0 + 0.2 * Run.amulet_count("paille")))   # (Paille)
	o.sold = true
	Sfx.play("level")
	_build()


func _weapon_tip(w: Dictionary) -> String:
	var st: Dictionary = w.st
	var nm: String = WeaponDB.get_def(w.type).name
	var ratio := ("\n" + Stats.scale_text(st.scale, w.rar)) if String(st.get("scale", "")) != "" else ""
	ratio += "\n" + Pal.color_line(st.get("frac", []), 0.3)
	if st.kind == "melee":
		return Loc.t("%s %s\nDégâts %.1f · Recharge %.2fs\nAllonge %d%s") % [nm, Pal.RARITY_NAMES_F[w.rar].to_lower(), st.damage, st.cooldown, roundi(st.reach), ratio]
	var tot := 0.0
	for b in st.bullets:
		tot += b.damage
	return Loc.t("%s %s\n%d projectile(s) · %.1f dégâts/tir\nRecharge %.2fs · Portée %d%s") % [nm, Pal.RARITY_NAMES_F[w.rar].to_lower(), st.bullets.size() * st.pellets, tot * st.pellets, st.cooldown, roundi(st.range), ratio]


func _refund(w: Dictionary) -> int:
	return maxi(3, roundi(w.price * 0.4 * (1.0 + 0.15 * Run.amulet_count("merchandising"))))   # (Merchandising)


func _sell(i: int) -> void:
	Run.log_event("sell", Loc.t("Revendu : %s (+● %d)") % [Run.item_label("weapon", Run.weapons[i].type, int(Run.weapons[i].rar)), _refund(Run.weapons[i])])
	Run.gold += _refund(Run.weapons[i])
	Run.weapons.remove_at(i)
	Sfx.play("buy")
	_build()


func _reroll() -> void:
	var p := Run.reroll_price()
	if Run.cash() < p:
		return
	Run.spend(p)
	Run.rerolls += 1
	Run.roll_shop()
	_build()


# ------------------------------------------------------------------ Roulette

## Case de la roue -> couleur ("vert" pour 0, puis rouge / noir en alternance).
static func wheel_color(slot: int) -> String:
	if slot == 0:
		return "vert"
	return "rouge" if slot % 2 == 1 else "noir"


func _wheel_icon() -> Image:
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5) - c
			var d := v.length()
			if d > 15.0:
				continue
			var col := GOLD_DARK
			if d < 13.5 and d > 5.0:
				var slot := int(fposmod(v.angle() + PI / 2.0, TAU) / TAU * 37.0)
				col = {"vert": WHEEL_GREEN, "rouge": WHEEL_RED, "noir": WHEEL_BLACK}[wheel_color(slot)]
			elif d <= 5.0:
				col = GOLD if d > 2.0 else GOLD_DARK
			img.set_pixel(x, y, col)
	return img


var roul: Control
var roul_bet := 10
var roul_offer := -1


func _open_roulette(i: int) -> void:
	if roul or Run.gold < 1:
		return
	roul_offer = i
	roul_bet = clampi(roul_bet, 1, Run.gold)
	roul = Control.new()
	roul.set_anchors_preset(PRESET_FULL_RECT)
	roul.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(roul)
	UI.fill_bg(roul, Color(0, 0, 0, 0.65))
	var p := _frame_panel(FRAME_ROULETTE, 5)
	UI.put(roul, p, Vector2(120, 24), Vector2(400, 312))
	var inner := UI.panel(WOOD_PANEL, GOLD_DARK, 1)
	UI.put(p, inner, Vector2(6, 6), Vector2(388, 300))
	UI.put(inner, UI.label(Loc.t("ROULETTE"), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(388, 24))
	var wheel := _Wheel.new()
	UI.put(inner, wheel, Vector2(114, 34), Vector2(160, 160))
	var info := UI.label(Loc.t("Choisis ta mise, puis une couleur."), 10, CARTEL, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, info, Vector2(0, 198), Vector2(388, 12))
	# Mise
	var bet_l := UI.label("", 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, bet_l, Vector2(0, 216), Vector2(388, 12))
	var sl := HSlider.new()
	sl.min_value = 1
	sl.max_value = maxi(1, Run.gold)
	sl.step = 1
	sl.value = roul_bet
	sl.focus_mode = Control.FOCUS_NONE
	UI.put(inner, sl, Vector2(60, 232), Vector2(268, 14))
	var upd := func():
		roul_bet = int(sl.value)
		bet_l.text = Loc.t("MISE : ● %d   (bourse ● %d)") % [roul_bet, Run.gold]
	sl.value_changed.connect(func(_v): upd.call())
	upd.call()
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 4)
	UI.put(inner, quick, Vector2(94, 250), Vector2(200, 14))
	for q in [["10%", 0.1], ["25%", 0.25], ["50%", 0.5], [Loc.t("Tout"), 1.0]]:
		var f: float = q[1]
		var qb := UI.button(q[0], func(): sl.value = maxi(1, roundi(Run.gold * f)))
		_style_tag(qb)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.add_child(qb)
	# Couleurs
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	UI.put(inner, row, Vector2(24, 272), Vector2(340, 20))
	var btns := []
	for c in [["rouge", Loc.t("ROUGE ×2"), WHEEL_RED], ["noir", Loc.t("NOIR ×2"), WHEEL_BLACK], ["vert", Loc.t("VERT ×36"), WHEEL_GREEN]]:
		var cid: String = c[0]
		var cb := UI.button(c[1], func(): _spin(cid, wheel, info, btns, sl))
		cb.add_theme_stylebox_override("normal", UI.sb(c[2], GOLD, 1))
		cb.add_theme_stylebox_override("hover", UI.sb(Color(c[2]).lightened(0.2), GOLD, 2))
		cb.add_theme_color_override("font_color", Color.WHITE)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cb)
		btns.append(cb)
	var close := UI.hotkey(UI.button("×", func(): _close_roulette()), [KEY_ESCAPE])
	_style_tag(close)
	UI.put(inner, close, Vector2(366, 6), Vector2(16, 14))
	btns.append(close)


func _spin(color: String, wheel: _Wheel, info: Label, btns: Array, sl: HSlider) -> void:
	var bet := mini(roul_bet, Run.gold)
	if bet < 1 or wheel.spinning:
		return
	for b in btns:
		b.disabled = true
	sl.editable = false
	Run.spend(bet)
	Run.shop_offers[roul_offer].sold = true
	var slot := randi() % 37
	var res := wheel_color(slot)
	info.text = Loc.t("Ça tourne...")
	Sfx.play("click")
	await wheel.spin_to(slot)
	var win := res == color
	var gain: int = bet * int(Run.ROULETTE_PAY[color]) if win else 0
	Run.gold += gain
	if win:
		Meta.count("roulette_wins")   # succès Dé pipé
	Run.log_event("event", Loc.t("Roulette : ● %d sur %s → %s, %s") % [bet, Loc.t(color), Loc.t(res), (Loc.t("gagné ● %d") % gain) if win else Loc.t("perdu")])
	info.add_theme_color_override("font_color", Pal.GOOD if win else Color("f06a5d"))
	info.text = (Loc.t("%s ! Gagné : ● %d") % [Loc.t(res).to_upper(), gain]) if win else (Loc.t("%s... Perdu ● %d") % [Loc.t(res).to_upper(), bet])
	Sfx.play("level" if win else "hurt")
	btns[btns.size() - 1].disabled = false   # fermer
	await get_tree().create_timer(1.6).timeout
	_close_roulette()


func _close_roulette() -> void:
	if roul:
		roul.queue_free()
		roul = null
	_build()


class _Wheel extends Control:
	var angle := 0.0
	var spinning := false

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 4.0
		draw_circle(c, r + 4.0, ShopScreen.GOLD_DARK)
		for k in 37:
			var a0 := angle + TAU * k / 37.0 - PI / 2.0
			var a1 := a0 + TAU / 37.0
			var col: Color = {"vert": ShopScreen.WHEEL_GREEN, "rouge": ShopScreen.WHEEL_RED, "noir": ShopScreen.WHEEL_BLACK}[ShopScreen.wheel_color(k)]
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * r, c + Vector2.from_angle((a0 + a1) / 2.0) * r, c + Vector2.from_angle(a1) * r]), col)
		draw_circle(c, r * 0.35, ShopScreen.WOOD)
		draw_circle(c, r * 0.12, ShopScreen.GOLD)
		# pointeur en haut
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -r - 6), c + Vector2(7, -r - 6), c + Vector2(0, -r + 10)]), Color.WHITE)

	## Tourne quelques tours et s'arrête avec la case « slot » sous le pointeur.
	func spin_to(slot: int) -> void:
		spinning = true
		var target := -TAU * (slot + 0.5) / 37.0
		var end := angle - fposmod(angle, TAU) + TAU * 5.0 + fposmod(target, TAU)
		Sfx.play("whirr", 0.0)   # lancer
		var last := -1
		var tw := create_tween()
		tw.tween_method(func(v: float):
			angle = v
			# un « tic » à chaque case qui passe sous le pointeur : rapide au début, puis de plus en plus espacé
			var c := floori(v / (TAU / 37.0))
			if c != last:
				last = c
				Sfx.play("tick", 0.15)
			queue_redraw(), angle, end, 3.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw.finished
		Sfx.play("clack", 0.05)   # la bille tombe dans sa case
		angle = fposmod(angle, TAU)
		spinning = false


# ------------------------------------------------------------------ Événements (grattage, enchère, restaurateur, mécène)

var ev_layer: Control


## Fenêtre d'événement : voile + cadre ; retourne le panneau intérieur (388 × h).
func _ev_window(title: String, cols: Array, h := 300.0) -> Panel:
	ev_layer = Control.new()
	ev_layer.set_anchors_preset(PRESET_FULL_RECT)
	ev_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ev_layer)
	UI.fill_bg(ev_layer, Color(0, 0, 0, 0.65))
	var y := (360.0 - h - 12.0) / 2.0
	var p := _frame_panel(cols, 5)
	UI.put(ev_layer, p, Vector2(120, y), Vector2(400, h + 12.0))
	var inner := UI.panel(WOOD_PANEL, GOLD_DARK, 1)
	UI.put(p, inner, Vector2(6, 6), Vector2(388, h))
	UI.put(inner, UI.label(title, 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(388, 24))
	return inner


func _ev_close() -> void:
	if ev_layer:
		ev_layer.queue_free()
		ev_layer = null
	_build()


func _ev_button(parent: Control, text: String, pos: Vector2, sz: Vector2, cb: Callable) -> Button:
	var b := UI.button(text, cb)
	_style_museum(b)
	UI.put(parent, b, pos, sz)
	return b


## Objet gagné (diamant, enchère, restaurateur) : ajouté à la boutique et acheté tout de suite
## (dessin / placement habituels). extra : champs en plus (prix, remplacement...).
func _grant(item: Dictionary, price: int, extra := {}) -> void:
	var o := {"type": item.type, "rar": int(item.rar), "price": price, "sold": false, "gift": true}
	if item.type == "weapon":
		o.wtype = item.wtype
	else:
		o.id = item.id
	o.merge(extra)
	Run.shop_offers.append(o)
	if ev_layer:
		ev_layer.queue_free()
		ev_layer = null
	done.emit({"a": "buy", "i": Run.shop_offers.size() - 1})


## Texte d'infobulle d'un objet : nom, type, rareté et ce qu'il fait.
func _item_desc(it: Dictionary) -> String:
	var r: String = String(Pal.RARITY_NAMES_F[int(it.rar)]).to_lower()
	if it.type == "weapon":
		var wd := WeaponDB.get_def(it.wtype)
		var ratio := ("\n" + Stats.scale_text(wd.scale, int(it.rar))) if wd.has("scale") else ""
		return Loc.t("%s — arme %s (%s)\n%s%s") % [wd.name, r, Loc.t("mêlée") if wd.kind == "melee" else Loc.t("distance"), wd.desc, ratio]
	var ad := AmuletDB.get_def(it.id)
	var lines := Array(AmuletDB.describe(ad).split("\n")).filter(func(l): return l != "" and not l.begins_with(Loc.t("Actuellement")))
	return Loc.t("%s — amulette %s\n%s") % [ad.name, r, "\n".join(lines)]


func _item_name(it: Dictionary) -> String:
	return String(WeaponDB.get_def(it.wtype).name) if it.type == "weapon" else String(AmuletDB.get_def(it.id).name)


func _item_icon(it: Dictionary) -> Image:
	if it.type == "weapon":
		if Run.has_art(it.wtype, it.rar):
			return Analyzer.trim(Run.closest_art(it.wtype, it.rar).image)
		var dw: Image = _default_img(Run.weapon_key(it.wtype, it.rar))
		return dw if dw else Gfx.icon(Gfx.ICON_UNKNOWN)
	if Run.amulet_art.has(it.id):
		return Run.amulet_art[it.id].image
	var da: Image = _default_img("amulette_" + it.id)
	return da if da else Gfx.icon(Gfx.ICON_UNKNOWN)


## Petites icônes dessinées au pixel pour les tableaux d'événements.
func _event_icon(kind: String) -> Image:
	var n := 32
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var ink := Pal.INK
	match kind:
		"scratch":
			img.fill_rect(Rect2i(3, 8, 26, 16), Color("efe6cf"))
			for k in 3:
				img.fill_rect(Rect2i(6 + k * 8, 12, 6, 8), Color("9a9a9a") if k < 2 else GOLD)
			for x in range(3, 29):
				img.set_pixel(x, 8, ink)
				img.set_pixel(x, 23, ink)
			for y in range(8, 24):
				img.set_pixel(3, y, ink)
				img.set_pixel(28, y, ink)
		"auction":
			# Marteau de commissaire-priseur, penché à 45°, sur son socle
			var wood := Color("a0692f")
			var dark := Color("5a3818")
			var c := Vector2(11, 11)
			for y in n:
				for x in n:
					var l := (Vector2(x + 0.5, y + 0.5) - c).rotated(-PI / 4.0)   # l.x = long du manche
					if absf(l.x) <= 4.5 and absf(l.y) <= 8.5:
						var edge := absf(l.x) > 3.5 or absf(l.y) > 7.5
						var band := absf(absf(l.y) - 5.5) < 0.8
						img.set_pixel(x, y, dark if edge else (GOLD if band else wood))
					elif l.x > 4.5 and l.x < 21.0 and absf(l.y) <= 1.6:
						img.set_pixel(x, y, dark if absf(l.y) > 0.9 else wood)
			# socle (le « bloc » qu'on frappe)
			img.fill_rect(Rect2i(16, 26, 15, 4), dark)
			img.fill_rect(Rect2i(18, 24, 11, 2), wood)
			img.fill_rect(Rect2i(18, 24, 11, 1), GOLD)
		"restorer":
			# pinceau en diagonale + goutte dorée
			for k in 18:
				img.fill_rect(Rect2i(6 + k, 24 - k, 2, 2), Color("8a5a2b"))
			img.fill_rect(Rect2i(22, 5, 5, 5), Color("d9d0bf"))
			img.fill_rect(Rect2i(25, 3, 4, 4), GOLD)
			img.fill_rect(Rect2i(6, 25, 4, 4), GOLD)
		"patron":
			# chapeau haut-de-forme + pièce
			img.fill_rect(Rect2i(9, 6, 14, 14), ink)
			img.fill_rect(Rect2i(5, 19, 22, 3), ink)
			img.fill_rect(Rect2i(9, 15, 14, 2), Color("b8322a"))
			for y in range(23, 31):
				for x in range(20, 30):
					if Vector2(x - 24.5, y - 26.5).length() < 4.2:
						img.set_pixel(x, y, GOLD)
	return img


# --- Ticket à gratter

const SCRATCH_SYMS := ["or", "etoile", "diamant"]


func _open_scratch(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if Run.cash() < o.price or ev_layer:
		return
	Run.spend(o.price)
	o.sold = true
	# Tirage : 1 chance sur 3 de gagner (or 60 %, étoile 30 %, diamant 10 %)
	var syms := []
	if randf() < 1.0 / 3.0:
		var r := randf()
		var sym: String = "or" if r < 0.6 else ("etoile" if r < 0.9 else "diamant")
		syms = [sym, sym, sym]
	else:
		while syms.is_empty() or (syms[0] == syms[1] and syms[1] == syms[2]):
			syms = [SCRATCH_SYMS.pick_random(), SCRATCH_SYMS.pick_random(), SCRATCH_SYMS.pick_random()]
	var inner := _ev_window(Loc.t("TICKET À GRATTER"), FRAME_EVENT, 250.0)
	var info := UI.label(Loc.t("Gratte les 3 cases avec la souris !"), 10, CARTEL, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, info, Vector2(0, 34), Vector2(388, 12))
	var card := _ScratchCard.new()
	card.syms = syms
	UI.put(inner, card, Vector2(44, 56), Vector2(300, 120))
	var all_b := _ev_button(inner, Loc.t("Tout gratter"), Vector2(84, 190), Vector2(100, 18), func(): card.reveal_all())
	var close := _ev_button(inner, Loc.t("Fermer"), Vector2(204, 190), Vector2(100, 18), func(): _ev_close())
	close.disabled = true
	card.revealed.connect(_scratch_done.bind(syms, info, close, all_b))


func _scratch_done(syms: Array, info: Label, close: Button, all_b: Button) -> void:
	all_b.disabled = true
	close.disabled = false
	var win: bool = syms[0] == syms[1] and syms[1] == syms[2]
	Run.log_event("event", Loc.t("Ticket à gratter : %s") % (("3 × " + String(syms[0])) if win else "perdu"))
	if not win:
		info.text = Loc.t("Perdu... Pas de chance !")
		info.add_theme_color_override("font_color", Color("f06a5d"))
		Sfx.play("hurt")
		return
	Sfx.play("level")
	info.add_theme_color_override("font_color", Pal.GOOD)
	var sym := String(syms[0])
	if sym == "or":
		Run.gold += 25
		info.text = Loc.t("3 PIÈCES ! +25 or")
	elif sym == "etoile":
		Run.star_buff += 15.0
		info.text = Loc.t("3 ÉTOILES ! +15% dégâts à la vague suivante")
	else:
		var pool := Run.amulet_candidates(1)
		if pool.is_empty():
			Run.gold += 40
			info.text = Loc.t("3 DIAMANTS ! +40 or")
			return
		info.text = Loc.t("3 DIAMANTS ! Une amulette rare gratuite")
		close.text = Loc.t("Prendre")
		var am: Dictionary = pool.pick_random()
		for c in close.pressed.get_connections():
			close.pressed.disconnect(c.callable)
		close.pressed.connect(func(): _grant({"type": "amulet", "id": am.id, "rar": 1}, 0))


class _ScratchCard extends Control:
	signal revealed
	var syms: Array = []
	var coats: Array = []      # Image de la couche à gratter, par case
	var texs: Array = []
	var done := false
	const CELL := Vector2i(84, 100)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		for k in 3:
			var im := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
			im.fill(Color("a8a8a8"))
			for y in CELL.y:
				for x in CELL.x:
					if (x + y) % 7 == 0:
						im.set_pixel(x, y, Color("939393"))
			coats.append(im)
			texs.append(ImageTexture.create_from_image(im))

	func _cell_rect(k: int) -> Rect2:
		return Rect2(Vector2(k * 104, 10), Vector2(CELL))

	func _gui_input(ev: InputEvent) -> void:
		if done:
			return
		var pressed: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) \
			or (ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
		if not pressed:
			return
		for k in 3:
			var r := _cell_rect(k)
			if r.grow(6).has_point(ev.position):
				_scratch(k, ev.position - r.position)
		accept_event()

	func _scratch(k: int, at: Vector2) -> void:
		var im: Image = coats[k]
		var rad := 7
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var x := int(at.x) + dx
				var y := int(at.y) + dy
				if dx * dx + dy * dy <= rad * rad and x >= 0 and y >= 0 and x < CELL.x and y < CELL.y:
					im.set_pixel(x, y, Color(0, 0, 0, 0))
		(texs[k] as ImageTexture).update(im)
		queue_redraw()
		if randi() % 3 == 0:
			Sfx.play("paint")
		_check()

	func _cleared(k: int) -> float:
		var im: Image = coats[k]
		var n := 0
		for y in range(0, CELL.y, 4):
			for x in range(0, CELL.x, 4):
				if im.get_pixel(x, y).a < 0.5:
					n += 1
		return n / float((CELL.x / 4) * (CELL.y / 4))

	func _check() -> void:
		for k in 3:
			if _cleared(k) < 0.55:
				return
		reveal_all()

	func reveal_all() -> void:
		if done:
			return
		done = true
		for k in 3:
			(coats[k] as Image).fill(Color(0, 0, 0, 0))
			(texs[k] as ImageTexture).update(coats[k])
		queue_redraw()
		revealed.emit()

	func _draw() -> void:
		for k in 3:
			var r := _cell_rect(k)
			draw_rect(r.grow(3), ShopScreen.GOLD_DARK)
			draw_rect(r, Color("efe6cf"))
			_symbol(String(syms[k]), r.get_center())
			draw_texture(texs[k], r.position)

	func _symbol(sym: String, c: Vector2) -> void:
		match sym:
			"or":
				draw_circle(c, 26.0, ShopScreen.GOLD_DARK)
				draw_circle(c, 21.0, ShopScreen.GOLD)
				draw_rect(Rect2(c - Vector2(3, 12), Vector2(6, 24)), ShopScreen.GOLD_DARK)
			"etoile":
				var pts := PackedVector2Array()
				for q in 10:
					pts.append(c + Vector2.from_angle(-PI / 2.0 + q * PI / 5.0) * (28.0 if q % 2 == 0 else 12.0))
				draw_colored_polygon(pts, Color("f2c230"))
			"diamant":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(22, -6), c + Vector2(0, 28), c + Vector2(-22, -6)]), Color("59c7e0"))
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -26), c + Vector2(22, -6), c + Vector2(-22, -6)]), Color("a8ecf7"))


# --- Vente aux enchères

func _open_auction(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if ev_layer:
		return
	var it: Dictionary = o.item
	var inner := _ev_window(Loc.t("VENTE AUX ENCHÈRES"), FRAME[it.rar], 300.0)
	var fr := _frame_panel(FRAME[it.rar], 4)
	UI.put(inner, fr, Vector2(24, 40), Vector2(96, 80))
	UI.put(fr, UI.thumb(_item_icon(it), Vector2(80, 64)), Vector2(8, 8), Vector2(80, 64))
	UI.put(inner, UI.label(_item_name(it), 20, Pal.RARITY[it.rar]), Vector2(132, 40), Vector2(240, 24))
	var desc: String = WeaponDB.get_def(it.wtype).desc if it.type == "weapon" else " ".join(Array(AmuletDB.describe(AmuletDB.get_def(it.id)).split("\n")).filter(func(l): return l != "" and not l.begins_with(Loc.t("Actuellement"))))
	var dl := UI.label("%s · %s\n%s" % [Loc.t("Arme") if it.type == "weapon" else Loc.t("Amulette"), Pal.RARITY_NAMES_F[it.rar].to_lower(), desc], 10, CARTEL)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.clip_text = true
	UI.put(inner, dl, Vector2(132, 66), Vector2(240, 50))
	UI.put(inner, UI.label(Loc.t("Prix habituel en galerie : ● %d") % int(o.value), 10, CARTEL_DIM), Vector2(132, 120), Vector2(240, 12))
	var bid_l := UI.label("", 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, bid_l, Vector2(0, 146), Vector2(388, 24))
	var log_l := UI.label("", 10, CARTEL, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, log_l, Vector2(0, 174), Vector2(388, 12))
	var blocked := ""
	if it.type == "weapon" and Run.weapons.size() >= Run.max_weapons() and Run.fusion_match(it.wtype, it.rar) < 0:
		blocked = Loc.t("Plus de place pour une arme : revends-en une d'abord.")
	var btns := []
	var st := {"bid": int(o.bid), "mine": false, "busy": false, "n": 0}
	var refresh := func():
		bid_l.text = Loc.t("ENCHÈRE : ● %d  (%s)") % [st.bid, "toi" if st.mine else Loc.t("le collectionneur")]
		for b in btns:
			var add: int = b.get_meta("add", 0)
			if add > 0:
				b.disabled = st.busy or st.mine or blocked != "" or st.n >= AUCTION_BIDS or Run.cash() < st.bid + add
	for k in 3:
		var add: int = [5, 10, 20][k]
		var b := _ev_button(inner, "+%d" % add, Vector2(44 + k * 80, 200), Vector2(70, 20), func():
			st.bid += add
			st.mine = true
			st.busy = true
			st.n += 1
			log_l.text = Loc.t("Tu proposes ● %d... (mise %d/%d)") % [st.bid, st.n, AUCTION_BIDS]
			Sfx.play("click")
			refresh.call()
			await get_tree().create_timer(0.7).timeout
			if not is_instance_valid(bid_l):
				return
			# Le collectionneur suit tant que son plafond secret le permet
			var cap: int = int(o.cap)
			if cap >= st.bid + 3 and randf() < 0.85:
				st.bid = mini(cap, st.bid + randi_range(3, 12))
				st.mine = false
				Sfx.play("enemy_shot")
				if st.n >= AUCTION_BIDS:
					# Plus de mise possible : l'œuvre part chez le collectionneur, tu ne paies rien
					log_l.text = Loc.t("Le collectionneur surenchérit (● %d) et l'emporte...") % st.bid
					log_l.add_theme_color_override("font_color", Color("f06a5d"))
					Run.log_event("event", Loc.t("Enchère : perdue (%s à ● %d)") % [_item_name(it), st.bid])
					o.sold = true
					refresh.call()
					await get_tree().create_timer(1.2).timeout
					if is_instance_valid(bid_l):
						_ev_close()
					return
				log_l.text = Loc.t("Le collectionneur surenchérit : ● %d (encore %d mise%s)") % [st.bid, AUCTION_BIDS - st.n, "s" if AUCTION_BIDS - st.n > 1 else ""]
			else:
				log_l.text = Loc.t("Le collectionneur abandonne... ADJUGÉ !")
				log_l.add_theme_color_override("font_color", Pal.GOOD)
				Sfx.play("level")
				o.sold = true
				await get_tree().create_timer(0.9).timeout
				_grant(it, st.bid)
				return
			st.busy = false
			refresh.call())
		b.set_meta("add", add)
		btns.append(b)
	var quit := _ev_button(inner, Loc.t("Se retirer"), Vector2(284, 200), Vector2(84, 20), func():
		Run.log_event("event", Loc.t("Enchère : retiré (%s à ● %d)") % [_item_name(it), st.bid])
		o.sold = true
		_ev_close())
	quit.tooltip_text = Loc.t("Tu ne paies rien, mais l'œuvre part chez le collectionneur.")
	btns.append(quit)
	if blocked != "":
		log_l.text = blocked
		log_l.add_theme_color_override("font_color", Color("f06a5d"))
	else:
		log_l.text = Loc.t("3 mises maximum. Il a un plafond secret...")
	var back := _ev_button(inner, Loc.t("Plus tard"), Vector2(144, 240), Vector2(100, 18), func(): _ev_close())
	back.tooltip_text = Loc.t("Fermer sans enchérir (la vente reste ouverte)")
	UI.hotkey(back, [KEY_ESCAPE])
	refresh.call()


# --- Le Restaurateur

func _open_restorer(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if ev_layer:
		return
	var inner := _ev_window(Loc.t("LE RESTAURATEUR"), FRAME_EVENT, 250.0)
	var tl := UI.label(Loc.t("« Confiez-moi une amulette : je la rends plus précieuse...\nmais je ne promets pas laquelle. »"), 10, CARTEL, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, tl, Vector2(0, 34), Vector2(388, 26))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	UI.put(inner, grid, Vector2(20, 68), Vector2(348, 140))
	for k in Run.restorable():
		var am: Dictionary = Run.amulets[k]
		var d := AmuletDB.get_def(am.id)
		var cost := roundi(Run.RESTORE_PRICE[int(d.rar)] * Run.price_mult())
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 62)
		b.add_theme_stylebox_override("normal", UI.sb(Pal.PAPER, Pal.RARITY[int(d.rar)], 2))
		b.add_theme_stylebox_override("hover", UI.sb(Color.WHITE, Pal.ACCENT, 2))
		b.add_theme_stylebox_override("disabled", UI.sb(Color("8a8070"), Color("5a5040"), 1))
		b.disabled = Run.cash() < cost
		b.tooltip_text = Loc.t("%s (%s) → une amulette %s au hasard\nPrix : ● %d") % [d.name, Pal.RARITY_NAMES_F[int(d.rar)].to_lower(), Pal.RARITY_NAMES_F[int(d.rar) + 1].to_lower(), cost]
		var th := UI.thumb(am.image, Vector2(36, 36))
		th.position = Vector2(8, 4)
		b.add_child(th)
		var pl := UI.label("● %d" % cost, 10, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER)
		pl.position = Vector2(0, 44)
		pl.size = Vector2(52, 12)
		b.add_child(pl)
		var entry := am
		var rar := int(d.rar)
		b.pressed.connect(func():
			var pool := Run.amulet_candidates(rar + 1)
			if pool.is_empty():
				return
			var nd: Dictionary = pool.pick_random()
			o.sold = true
			Sfx.play("level")
			_grant({"type": "amulet", "id": nd.id, "rar": rar + 1}, cost, {"replace": {"id": entry.id, "pos": entry.pos}}))
		grid.add_child(b)
	UI.put(inner, UI.label(Loc.t("Clique l'amulette à lui confier : elle sera remplacée."), 10, CARTEL_DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 208), Vector2(388, 12))
	UI.hotkey(_ev_button(inner, Loc.t("Non merci"), Vector2(144, 226), Vector2(100, 18), func(): _ev_close()), [KEY_ESCAPE])


# --- Le Mécène

func _open_patron(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if ev_layer:
		return
	var inner := _ev_window(Loc.t("LE MÉCÈNE"), FRAME_EVENT, 220.0)
	var tl := UI.label(Loc.t("« J'aime l'art qui souffre. Je finance...\nsi vous me donnez du spectacle. »"), 10, CARTEL, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, tl, Vector2(0, 34), Vector2(388, 26))
	for k in Run.PATRON_DEALS.size():
		var deal: Array = Run.PATRON_DEALS[k]
		var y := 72.0 + k * 58.0
		var box := UI.panel(CARTEL, Color("b9a883"), 1)
		UI.put(inner, box, Vector2(24, y), Vector2(340, 50))
		UI.put(box, UI.label(Loc.t("CONTRAT %s") % ["I", "II"][k], 10, CARTEL_DIM), Vector2(8, 4), Vector2(200, 12))
		UI.put(box, UI.label(Loc.t("+● %d tout de suite") % Run.patron_gold(k), 10, Color("1e7a3a")), Vector2(8, 18), Vector2(220, 12))
		UI.put(box, UI.label(String(deal[2]), 10, Color("a02a22")), Vector2(8, 32), Vector2(240, 12))
		var did: String = deal[0]
		var amount := Run.patron_gold(k)
		var sb := UI.button(Loc.t("Signer"), func():
			Run.gold += amount
			Run.log_event("event", Loc.t("Mécène : +● %d contre « %s »") % [amount, String(deal[2])])
			Run.patron = did
			o.sold = true
			Sfx.play("buy")
			_ev_close())
		_style_price(sb)
		UI.put(box, sb, Vector2(262, 16), Vector2(70, 18))
	UI.hotkey(_ev_button(inner, Loc.t("Refuser"), Vector2(144, 196), Vector2(100, 18), func():
		o.sold = true
		_ev_close()), [KEY_ESCAPE])


# ------------------------------------------------------------------ Case opening (caisses façon CS:GO)

## Icône d'une caisse (bois, argent, or, diamant × armes / amulettes) : images faites par docs/case_icons.py.
func _case_icon(tier: int, kind: String) -> Image:
	var tex := load("res://assets/ui/cases/case_%d_%s.png" % [tier, "weapon" if kind == "weapon" else "amulet"]) as Texture2D
	return tex.get_image() if tex else Gfx.icon(Gfx.ICON_UNKNOWN)


func _open_case(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if ev_layer or Run.cash() < o.price:
		return
	var won := Run.roll_case_item(int(o.tier), String(o.kind))
	if won.is_empty():
		return
	Run.spend(o.price)
	o.sold = true
	Run.log_event("event", Loc.t("%s (%s) ouverte (● %d) : %s") % [Run.CASE_NAMES[o.tier], "armes" if o.kind == "weapon" else "amulettes", o.price, Run.item_label(won.type, won.get("wtype", won.get("id", "")), int(won.rar))])
	var inner := _ev_window("%s · %s" % [Run.CASE_NAMES[o.tier].to_upper(), Loc.t("ARMES") if o.kind == "weapon" else Loc.t("AMULETTES")], CASE_FRAME[o.tier], 220.0)
	# La bande : objets au hasard de la caisse, le gagnant à la case WIN
	var items := []
	for k in 44:
		items.append(Run.roll_case_item(int(o.tier), String(o.kind)))
	var WIN := 36
	items[WIN] = won
	var strip := _CaseStrip.new()
	strip.shop = self
	strip.items = items
	strip.clip_contents = true
	UI.put(inner, strip, Vector2(14, 44), Vector2(360, 76))
	var res := UI.label("", 20, CARTEL, HORIZONTAL_ALIGNMENT_CENTER)
	res.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.put(inner, res, Vector2(0, 130), Vector2(388, 24))
	var sub := UI.label("", 10, CARTEL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(inner, sub, Vector2(0, 156), Vector2(388, 12))
	var take := _ev_button(inner, Loc.t("Prendre"), Vector2(84, 186), Vector2(100, 20), func(): _grant(won, 0))
	take.disabled = true
	var leave := _ev_button(inner, Loc.t("Laisser"), Vector2(204, 186), Vector2(100, 20), func(): _ev_close())
	leave.tooltip_text = Loc.t("Ne pas prendre cet objet (la caisse est quand même payée)")
	leave.disabled = true
	await strip.spin_to(WIN)
	if not is_instance_valid(res):
		return
	res.text = _item_name(won).to_upper()
	res.tooltip_text = _item_desc(won)   # survole pour savoir ce que fait l'objet
	res.add_theme_color_override("font_color", Pal.RARITY[int(won.rar)])
	sub.text = Loc.t("%s · %s · survole le nom pour voir ce qu'elle fait") % [Loc.t("Arme") if won.type == "weapon" else Loc.t("Amulette"), Pal.RARITY_NAMES_F[int(won.rar)].to_lower()]
	Sfx.play("level" if int(won.rar) >= 2 else "buy")
	if int(won.rar) >= 2:
		shake_flash(inner, Pal.RARITY[int(won.rar)])
	take.disabled = false
	leave.disabled = false
	if won.type == "weapon" and Run.weapons.size() >= Run.max_weapons() and Run.fusion_match(won.wtype, int(won.rar)) < 0:
		take.disabled = true
		sub.text += Loc.t(" · plus de place pour une arme")


## Petit éclat de couleur sur la fenêtre (épique / légendaire sorti).
func shake_flash(node: Control, col: Color) -> void:
	var fl := ColorRect.new()
	fl.color = Color(col, 0.55)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.put(node, fl, Vector2.ZERO, node.size)
	var tw := fl.create_tween()
	tw.tween_property(fl, "color:a", 0.0, 0.6)
	tw.tween_callback(fl.queue_free)


class _CaseStrip extends Control:
	var shop: ShopScreen
	var items: Array = []
	var offset := 0.0          # défilement (px)
	var last_cell := -1
	var icons := {}
	const CELL := 64.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		tooltip_text = " "   # le vrai texte vient de _get_tooltip (objet sous la souris)

	func _get_tooltip(at: Vector2) -> String:
		var k := floori((at.x + offset - size.x / 2.0 + CELL / 2.0) / CELL)
		if k < 0 or k >= items.size():
			return ""
		return shop._item_desc(items[k])

	func _icon(it: Dictionary) -> Texture2D:
		var key := "%s_%s_%d" % [it.type, it.get("wtype", it.get("id", "")), it.rar]
		if not icons.has(key):
			icons[key] = ImageTexture.create_from_image(shop._item_icon(it))
		return icons[key]

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("1d1510"))
		var mid := size.x / 2.0
		for k in items.size():
			var x := k * CELL - offset + mid - CELL / 2.0
			if x < -CELL or x > size.x:
				continue
			var it: Dictionary = items[k]
			var col: Color = Pal.RARITY[int(it.rar)]
			var r := Rect2(Vector2(x + 2, 4), Vector2(CELL - 4, size.y - 8))
			draw_rect(r, Color("efe6cf"))
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 6), Vector2(r.size.x, 6)), col)
			var tex := _icon(it)
			var ts := Vector2(tex.get_size())
			var sc := minf(36.0 / ts.x, 36.0 / ts.y)
			draw_texture_rect(tex, Rect2(r.get_center() - ts * sc / 2.0 - Vector2(0, 9), ts * sc), false)
			# nom de l'objet (utile quand il n'est pas encore dessiné)
			var font := get_theme_default_font()
			draw_string(font, Vector2(r.position.x + 2, r.end.y - 9), shop._item_name(it), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 4, UI.fs(10), Pal.INK)
		# curseur central
		draw_rect(Rect2(Vector2(mid - 1, 0), Vector2(2, size.y)), ShopScreen.GOLD)
		draw_colored_polygon(PackedVector2Array([Vector2(mid - 6, 0), Vector2(mid + 6, 0), Vector2(mid, 8)]), ShopScreen.GOLD)
		draw_colored_polygon(PackedVector2Array([Vector2(mid - 6, size.y), Vector2(mid + 6, size.y), Vector2(mid, size.y - 8)]), ShopScreen.GOLD)

	func spin_to(k: int) -> void:
		var target := k * CELL + randf_range(-CELL * 0.35, CELL * 0.35)
		var tw := create_tween()
		tw.tween_method(func(v: float):
			offset = v
			var c := int(roundf(v / CELL))
			if c != last_cell:
				last_cell = c
				Sfx.play("click")
			queue_redraw(), 0.0, target, 4.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		await tw.finished
		# se recale au centre de la case gagnante
		var tw2 := create_tween()
		tw2.tween_method(func(v: float):
			offset = v
			queue_redraw(), offset, k * CELL, 0.25)
		await tw2.finished


## Icône 12×12 : épée (arme), collier (amulette) ou trace de patte (familier).
func _kind_icon(kind: String) -> Image:
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	if kind == "familiar":
		# trace de patte : 4 doigts + coussinet, roses avec un contour noir
		const PAW := [
			"............",
			"...##..##...",
			"...##..##...",
			".##......##.",
			".##.####.##.",
			"...######...",
			"..########..",
			"..########..",
			"..########..",
			"...##..##...",
			"............",
			"............"]
		for y in 12:
			for x in 12:
				if PAW[y][x] == "#":
					# coussinets roses, avec un reflet en haut à gauche de chaque morceau
					var top: bool = y == 0 or PAW[y - 1][x] != "#"
					var left: bool = x == 0 or PAW[y][x - 1] != "#"
					img.set_pixel(x, y, Color("ffc8d4") if top and left else (Color("f08aa4") if top or left else Color("d85a7a")))
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx >= 0 and ny >= 0 and nx < 12 and ny < 12 and PAW[ny][nx] == "#":
						img.set_pixel(x, y, Pal.INK)   # contour
						break
		return img
	if kind == "weapon":
		# petite épée droite : lame, garde dorée, poignée, pommeau
		img.fill_rect(Rect2i(4, 1, 4, 7), Pal.INK)          # contour de la lame
		img.fill_rect(Rect2i(5, 0, 2, 1), Pal.INK)          # pointe
		img.fill_rect(Rect2i(5, 1, 2, 6), Color("d6dbe2"))  # lame
		img.fill_rect(Rect2i(5, 1, 1, 6), Color.WHITE)      # reflet
		img.fill_rect(Rect2i(1, 7, 10, 2), Pal.INK)         # garde (contour)
		img.fill_rect(Rect2i(2, 7, 8, 1), GOLD)             # garde
		img.fill_rect(Rect2i(5, 9, 2, 2), Color("8a5a2b"))  # poignée
		img.fill_rect(Rect2i(4, 11, 4, 1), GOLD_DARK)       # pommeau
	else:
		# petit collier : une chaîne dorée en U et un pendentif rouge en bas
		var chain := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 5), Vector2i(4, 6),
			Vector2i(10, 0), Vector2i(10, 1), Vector2i(10, 2), Vector2i(9, 3), Vector2i(9, 4), Vector2i(8, 5), Vector2i(7, 6)]
		for k in chain.size():
			img.set_pixelv(chain[k], GOLD if k % 2 == 0 else GOLD_DARK)
		img.fill_rect(Rect2i(5, 6, 2, 1), GOLD_DARK)       # attache
		img.fill_rect(Rect2i(4, 7, 4, 4), Pal.INK)         # pendentif (contour)
		img.fill_rect(Rect2i(5, 11, 2, 1), Pal.INK)
		img.fill_rect(Rect2i(5, 8, 2, 3), Color("e0443a")) # pierre
		img.set_pixel(5, 8, Color("ff9a8a"))               # reflet
	return img
