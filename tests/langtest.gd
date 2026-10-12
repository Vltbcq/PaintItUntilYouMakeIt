extends Node
## Traduction anglaise : en anglais, plus aucun texte français ne doit s'afficher (tables de données,
## textes assemblés par le code, écrans), les marques de format sont les mêmes des deux côtés, et
## repasser en français rend tout comme avant.
## Godot --path . res://tests/langtest.tscn [-- <dossier de captures>]

const RESIDUE := "[éèêëàâçîïôöûùœÉÈÊÀÇÔŒ«»]|(?i)\\b(les|des|une|ton|tes|ta|pour|avec|dans|vague|ennemis?|dessins?|armes?|amulettes?|familiers?|sur|ou|et|du|aux?)\\b"
## Textes qui restent français exprès (noms propres, mots identiques)
const ALLOWED := ["Mise en Abyme", "Français", "Trompe-l'œil", "Trompe-l'oeil"]

var fails := 0
var rx := RegEx.new()
var ids := RegEx.create_from_string("^[a-z_0-9]+$")
var shots := ""


func _check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL " + what)
		fails += 1


func _french(s: String) -> bool:
	for a in ALLOWED:
		s = s.replace(a, "")
	return rx.search(s) != null


func _scan(v, where: String, out: Array) -> void:
	match typeof(v):
		TYPE_STRING:
			if _french(v) and not ids.search(v):   # (un identifiant en minuscules n'est pas un texte)
				out.append("%s : %s" % [where, v])
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			for x in v:
				_scan(x, where, out)
		TYPE_DICTIONARY:
			for k in v:
				_scan(k, where, out)
				_scan(v[k], where, out)


func _untranslated(v, seen: Dictionary) -> void:
	match typeof(v):
		TYPE_STRING:
			if not LangEn.D.has(v) and not ids.search(v) and v != "":
				seen[v] = true
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			for x in v:
				_untranslated(x, seen)
		TYPE_DICTIONARY:
			for k in v:
				_untranslated(k, seen)
				_untranslated(v[k], seen)


func _report(found: Array, what: String) -> void:
	for f in found.slice(0, 12):
		print("   reste du français — " + String(f).replace("\n", " ⏎ ").left(170))
	_check(found.is_empty(), "%s : %d texte(s) encore en français" % [what, found.size()])


## Tous les textes visibles d'un écran (étiquettes, boutons, infobulles).
func _texts(n: Node, out: Array) -> void:
	if n is Label or n is Button or n is RichTextLabel or n is LineEdit:
		var t: String = n.placeholder_text if n is LineEdit else n.text
		if n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
			out.append(t)
	if n is Control and n.tooltip_text != "" and n.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		out.append(n.tooltip_text)
	for c in n.get_children():
		_texts(c, out)


func _screen(scr: Control, label: String) -> void:
	scr.size = Vector2(640, 360)
	add_child(scr)
	for k in 4:
		await get_tree().process_frame
	var all := []
	_texts(scr, all)
	var found := []
	for t in all:
		if _french(t):
			found.append(t)
	_report(found, "écran " + label)
	if shots != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/en_%s.png" % [shots, label])
	scr.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.data = Meta.data.duplicate(true)
	Meta.unlock_all()
	rx.compile(RESIDUE)
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	await get_tree().process_frame

	# --- Le catalogue : mêmes marques de format, pas de traduction vide
	var marks := RegEx.new()
	marks.compile("%[-+0-9.]*[dsf]|\\{[a-z0-9_]+\\}")
	var bad := 0
	for k in LangEn.D:
		var a := marks.search_all(String(k).replace("%%", "")).map(func(m): return m.get_string())
		var b := marks.search_all(String(LangEn.D[k]).replace("%%", "")).map(func(m): return m.get_string())
		a.sort()
		b.sort()
		if a != b or String(LangEn.D[k]) == "":
			bad += 1
			print("   marques différentes : %s -> %s" % [k, LangEn.D[k]])
	_check(bad == 0, "catalogue : %d texte(s) aux marques de format différentes" % bad)
	print("catalogue : %d textes" % LangEn.D.size())

	# --- En français : rien ne change
	Loc.ignore_env = true
	Loc.apply("fr")
	var fr_name: String = AmuletDB.LIST[0].name
	var fr_cond := ItemUnlockDB.text(ItemUnlockDB.CONDS["w:avion"])
	_check(Loc.t("Retour") == "Retour" and fr_cond == "Termine la vague 10 sur La Feuille.", "français : textes d'origine (%s)" % fr_cond)

	# (avec « liste » : les textes des tables qui n'ont pas de traduction, pour les passer en revue)
	if "liste" in args:
		var seen := {}
		for row in LangTables.LIST:
			_untranslated((load(row[0]) as Script).get(row[1]), seen)
		print("SANS TRADUCTION : ", " | ".join(seen.keys()))

	# --- Icônes de stats dans les textes : au moins autant en anglais qu'en français, phrase par phrase
	# (l'anglais en a parfois plus : « +3% damage » là où le français écrit « +3% de dégâts »)
	var fr_icons := {}
	for d in AmuletDB.LIST:
		fr_icons["a:" + String(d.id)] = UI.stat_bbcode(AmuletDB.describe(d)).count("[img")
	for t in WeaponDB.TYPES:
		fr_icons["w:" + t] = UI.stat_bbcode(String(WeaponDB.get_def(t).desc)).count("[img")
	for k in Run.UPGRADES.size():
		fr_icons["u:%d" % k] = UI.stat_bbcode(String(Run.UPGRADES[k][2])).count("[img")

	# --- En anglais : les tables de données
	Loc.apply("en")
	_check(Loc.t("Retour") == "Back", "Loc.t traduit")
	_check(String(AmuletDB.LIST[0].name) != fr_name and String(AmuletDB.get_def(AmuletDB.LIST[0].id).name) == String(AmuletDB.LIST[0].name), "les tables sont réécrites sur place (%s -> %s)" % [fr_name, AmuletDB.LIST[0].name])
	var found := []
	for row in LangTables.LIST:
		_scan((load(row[0]) as Script).get(row[1]), "%s.%s" % [String(row[0]).get_file().get_basename(), row[1]], found)
	_report(found, "tables de données")

	var lost := 0
	for d in AmuletDB.LIST:
		var n := UI.stat_bbcode(AmuletDB.describe(d)).count("[img")
		if n < int(fr_icons["a:" + String(d.id)]) and String(d.id) != "pitcoin":   # (Pitcoin : « 1 chance sur 8 » n'est pas la stat Chance)
			lost += 1
			print("   icônes %d (fr %d) : %s" % [n, fr_icons["a:" + String(d.id)], AmuletDB.describe(d).replace("
", " ⏎ ").left(150)])
	for t in WeaponDB.TYPES:
		var n := UI.stat_bbcode(String(WeaponDB.get_def(t).desc)).count("[img")
		if n < int(fr_icons["w:" + t]):
			lost += 1
			print("   icônes %d (fr %d) : %s" % [n, fr_icons["w:" + t], String(WeaponDB.get_def(t).desc).left(150)])
	for k in Run.UPGRADES.size():
		var n := UI.stat_bbcode(String(Run.UPGRADES[k][2])).count("[img")
		if n < int(fr_icons["u:%d" % k]):
			lost += 1
			print("   icônes %d (fr %d) : %s" % [n, fr_icons["u:%d" % k], Run.UPGRADES[k][2]])
	_check(lost == 0, "icônes de stats : %d texte(s) ont moins d'icônes qu'en français" % lost)

	# --- Les textes assemblés par le code
	found = []
	for k in ItemUnlockDB.CONDS:
		_scan(ItemUnlockDB.text(ItemUnlockDB.CONDS[k]), "défi " + k, found)
		_scan(ItemUnlockDB.label(k), "nom " + k, found)
	for d in AmuletDB.LIST:
		_scan(AmuletDB.describe(d), "amulette " + String(d.id), found)
	for t in WeaponDB.TYPES:
		var wd := WeaponDB.get_def(t)
		if wd.has("scale"):
			for rar in 4:
				_scan(Stats.scale_text(wd.scale, rar), "ratio " + t, found)
	for e in ["", "pulse", "shimmer", "rainbow"]:
		for kind in ["character", "melee", "enemy", "amulet"]:
			_scan(Stats.effect_text(e, kind), "encre " + e, found)
	_report(found, "textes assemblés")
	var cond := ItemUnlockDB.text(ItemUnlockDB.CONDS["w:avion"])
	_check(cond == "Finish wave 10 on The Page.", "défi lié à une carte : " + cond)
	cond = ItemUnlockDB.text(ItemUnlockDB.CONDS["w:cutter"])
	_check(cond == "Reach 40% crit in a run.", "défi de stat : " + cond)
	cond = ItemUnlockDB.text(ItemUnlockDB.CONDS["w:chevalet_bouclier"])
	_check(cond == "Reach 15 armor in a run.", "défi de stat sans % : " + cond)
	cond = ItemUnlockDB.text(ItemUnlockDB.CONDS["f:pavel"])
	_check(cond == "Win a run on The Blackboard at Sketch or harder.", "défi de victoire : " + cond)

	# --- Les écrans
	Run.start(0, 1)
	var img := Image.create_empty(24, 24, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(6, 6, 12, 12), Pal.SHADES[1][1])
	Run.set_character(img, "")
	Run.set_weapon_art("epee", 0, img, "", null, "")
	Run.add_weapon("epee", 0, 10, Vector2.ZERO)
	Run.gold = 500
	Run.wave = 3
	Run.roll_shop()
	await _screen(TitleScreen.new(), "titre")
	var op := OptionsPanel.new()
	op.from_title = true
	await _screen(op, "options")
	await _screen(AtelierScreen.new(), "atelier")
	await _screen(StatsScreen.new(), "stats")
	await _screen(GalleryScreen.new(), "galerie")
	await _screen(CodexScreen.new("armes"), "codex_armes")
	await _screen(CodexScreen.new("amulettes"), "codex_amulettes")
	await _screen(CodexScreen.new("ennemis"), "codex_ennemis")
	await _screen(CodexScreen.new("familiers"), "codex_familiers")
	await _screen(ChoiceScreens.map_choice(), "cartes")
	await _screen(ChoiceScreens.difficulty(), "difficulte")
	await _screen(ChoiceScreens.weapon_kind(), "premiere_arme")
	await _screen(ChoiceScreens.end_run(true, 42, ["w:avion", "a:spatule", "maitre"]), "fin")
	await _screen(ShopScreen.new(), "boutique")
	await _screen(ArrangeScreen.new("", 0), "rangement")
	await _screen(RunLogScreen.new("resume"), "journal")
	var cfg := DrawCfg.character()
	cfg.base = img
	await _screen(DrawScreen.new(cfg), "dessin_perso")
	cfg = DrawCfg.weapon("epee", 0)
	cfg.base = img
	var ds := DrawScreen.new(cfg)
	ds.size = Vector2(640, 360)
	add_child(ds)
	for k in 4:
		await get_tree().process_frame
	_check(ds.stats_label.find_children("*", "TextureRect", true, false).size() >= 2, "aperçu d'une arme : les stats gardent leurs icônes en anglais")
	ds.queue_free()
	await get_tree().process_frame
	await _screen(DrawScreen.new(DrawCfg.weapon("pistolet", 0)), "dessin_arme")
	await _screen(DrawScreen.new(DrawCfg.enemy("virus")), "dessin_boss")
	await _screen(LevelUpScreen.new(), "niveau")

	# --- Retour au français : tout redevient comme avant
	Loc.apply("fr")
	_check(String(AmuletDB.LIST[0].name) == fr_name and ItemUnlockDB.text(ItemUnlockDB.CONDS["w:avion"]) == fr_cond, "retour au français : textes d'origine")
	# ... y compris les étiquettes et boutons, que Godot traduit tout seul (langue de secours !)
	_check(tr("Retour") == "Retour" and tr("Nouvelle partie") == "Nouvelle partie", "retour au français : Godot ne retraduit pas les étiquettes (%s)" % tr("Retour"))
	Loc.apply("en")
	_check(tr("Retour") == "Back", "puis de nouveau l'anglais")
	Loc.apply("fr")
	_check(tr("Retour") == "Retour", "et encore le français")
	Run.active = false
	print("LANGTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
