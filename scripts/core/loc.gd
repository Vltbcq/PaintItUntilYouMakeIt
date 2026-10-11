class_name Loc
extends RefCounted
## Langues. Le jeu est ÉCRIT en français : chaque texte affiché passe par Loc.t("texte français"),
## qui rend sa traduction (scripts/data/lang_en.gd) ou le texte lui-même en français.
##
## Les tables de données (noms et descriptions des objets, des ennemis...) ne passent pas par
## Loc.t à chaque lecture : ce sont des `static var`, listées dans LangTables, qu'apply() réécrit
## SUR PLACE dans la langue choisie (valeurs ET clés qui sont des textes affichés).
## Conséquence : un texte affiché ne doit jamais servir de clé de sauvegarde.
##
## Ajouter un texte : l'écrire en français avec Loc.t(...), puis lancer docs/i18n/build.py, qui
## signale ce qui manque dans docs/i18n/en.json.

const LANGS := ["fr", "en"]
const LANG_NAMES := {"fr": "Français", "en": "English"}

static var lang := "fr"
static var ignore_env := false   # (tests de traduction : la langue demandée, pas PAINTIT_LANG)
static var _d: Dictionary = {}
static var _orig: Dictionary = {}    # "chemin:NOM" -> copie française de la table
static var _server: Translation      # filet de sécurité : les Label / Button se traduisent seuls


## Le texte dans la langue du jeu.
static func t(s) -> String:
	if lang == "fr":
		return String(s)
	return String(_d.get(s, s))


## Accord du pluriel d'un ADJECTIF ou d'un participe (« exportés ») : n'existe qu'en français.
## (Le pluriel des noms, lui, prend un « s » dans les deux langues.)
static func agr(n: int, mark := "s") -> String:
	return mark if lang == "fr" and n > 1 else ""


## Langue du système : français si le PC est en français, anglais sinon.
static func system_lang() -> String:
	return "fr" if OS.get_locale_language() == "fr" else "en"


## Change la langue ("" = celle du système) et réécrit les tables de données.
static func apply(to: String) -> void:
	# (PAINTIT_LANG force la langue : les tests tournent en français quel que soit le PC)
	var forced := OS.get_environment("PAINTIT_LANG")
	if forced in LANGS and not ignore_env:
		to = forced
	if not to in LANGS:
		to = system_lang()
	var first := _orig.is_empty()
	if first:
		for row in LangTables.LIST:
			var v = (load(row[0]) as Script).get(row[1])
			_orig["%s:%s" % row] = v.duplicate(true) if (v is Array or v is Dictionary) else v
	if to == lang and not first:
		return
	lang = to
	_d = LangEn.D if lang == "en" else {}
	for row in LangTables.LIST:
		var sc := load(row[0]) as Script
		var src = _orig["%s:%s" % row]
		var live = sc.get(row[1])
		if live is Array:
			live.clear()
			live.append_array(_any(src))
		elif live is Dictionary:
			live.clear()
			live.merge(_any(src))
		else:
			sc.set(row[1], _any(src))
	# Le filet de sécurité n'est branché QU'EN anglais : en français, Godot se rabat sur la langue
	# de secours (l'anglais) dès qu'une traduction anglaise est enregistrée, et tout repasse en anglais.
	if _server == null:
		_server = Translation.new()
		_server.locale = "en"
		for k in LangEn.D:
			_server.add_message(k, LangEn.D[k])
	TranslationServer.remove_translation(_server)
	if lang == "en":
		TranslationServer.add_translation(_server)
	TranslationServer.set_locale(lang)


## Copie traduite d'une valeur (chaînes, tableaux et dictionnaires imbriqués).
static func _any(v):
	match typeof(v):
		TYPE_STRING:
			return _d.get(v, v)
		TYPE_ARRAY:
			var a: Array = v.duplicate()
			for k in a.size():
				a[k] = _any(a[k])
			return a
		TYPE_PACKED_STRING_ARRAY:
			var p := PackedStringArray()
			for s in v:
				p.append(_d.get(s, s))
			return p
		TYPE_DICTIONARY:
			var d: Dictionary = v.duplicate()
			d.clear()
			for k in v:
				d[_d.get(k, k) if k is String else k] = _any(v[k])
			return d
	return v
