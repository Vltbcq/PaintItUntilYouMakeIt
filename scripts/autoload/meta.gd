extends Node
## Progression permanente entre les parties : pigments, déblocages, galerie de dessins.
## 3 SAUVEGARDES : chacune a sa progression, sa galerie, son Codex et sa partie en cours.
## La sauvegarde 1 garde les emplacements historiques (user://save.json, user://gallery...),
## les 2 et 3 sont dans user://slot2/ et user://slot3/. Les réglages sont communs (settings.json).
## user:// = %APPDATA%/PaintItUntilYouMakeIt (Windows), ~/.local/share/PaintItUntilYouMakeIt (Linux).
## Avant le renommage du jeu c'était « VowelGame » : au premier lancement, tout y est recopié.

const SLOTS := 3
const OLD_USER_DIR := "VowelGame"          # ancien dossier de sauvegarde (le jeu s'appelait Vowel)
const LEGACY_SAVE := "vowel_save.json"     # ancien nom du fichier de sauvegarde
const MIGRATE_SKIP := ["logs", "shader_cache", "objectdb_snapshots"]   # propres à chaque PC : pas recopiés
const RUN_SCRIPT := preload("res://scripts/autoload/run.gd")

static var DIFFICULTIES := [
	{"name": "Esquisse", "desc": "La base. Déjà pas facile.", "hp": 1.0, "dmg": 1.0, "spawn": 1.0, "reward": 1.0},
	{"name": "Croquis", "desc": "Ennemis plus coriaces. NOUVEAU : des ÉLITES à partir de la vague 4.", "hp": 1.3, "dmg": 1.2, "spawn": 1.15, "reward": 1.3},
	{"name": "Aquarelle", "desc": "Plus d'ennemis, plus rapides. NOUVEAU : les tireurs visent où tu vas, et chaque ennemi a une couleur imposée à dessiner.", "hp": 1.65, "dmg": 1.45, "spawn": 1.3, "reward": 1.6},
	{"name": "Huile", "desc": "Les ennemis frappent très fort. NOUVEAU : chaque élite a un pouvoir, et les ennemis tués laissent une flaque qui ralentit.", "hp": 2.0, "dmg": 1.75, "spawn": 1.45, "reward": 2.0},
	{"name": "Chef-d'œuvre", "desc": "Seuls les vrais artistes survivent. NOUVEAU : sous 25 % de PV, les boss entrent en fureur.", "hp": 2.3, "dmg": 2.1, "spawn": 1.6, "reward": 2.5},
]

const DEFAULT_SETTINGS := {"volume": 0.8, "window_mode": "fenetre", "zoom": 1.5, "tips": true, "show_amulets": true, "music_volume": 0.8, "sfx_volume": 0.8, "lang": ""}

var data := {}
var settings := {}
var slot := 1
var root := "user://"       # dossier des sauvegardes (les tests le redirigent vers un dossier temporaire)
var no_save := false        # tests : interdit toute écriture de la sauvegarde / galerie / carnet


func _ready() -> void:
	if root == "user://":
		migrate_old_dir(OS.get_data_dir().path_join(OLD_USER_DIR), OS.get_user_data_dir())
	_rename_legacy_saves()
	_load_settings()
	slot = clampi(int(settings.get("slot", 1)), 1, SLOTS)
	load_data()
	apply_settings()


# ------------------------------------------------------------------ Ancien nom du jeu

## Premier lancement sous le nouveau nom : on recopie l'ancien dossier « VowelGame » (s'il existe et
## que le nouveau n'a encore aucune sauvegarde). L'ancien dossier n'est pas touché (secours).
func migrate_old_dir(old: String, new: String) -> void:
	if old.simplify_path() == new.simplify_path() or not DirAccess.dir_exists_absolute(old):
		return
	for f in ["settings.json", "save.json", LEGACY_SAVE]:
		if FileAccess.file_exists(new.path_join(f)):
			return   # le nouveau dossier a déjà une sauvegarde : on ne l'écrase jamais
	_copy_dir(old, new, true)


func _copy_dir(from: String, to: String, top := false) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var d := DirAccess.open(from)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.copy_absolute(from.path_join(f), to.path_join(f))
	for sub in d.get_directories():
		if top and sub in MIGRATE_SKIP:
			continue
		_copy_dir(from.path_join(sub), to.path_join(sub))


## vowel_save.json -> save.json, dans chaque emplacement (une seule fois).
func _rename_legacy_saves() -> void:
	for n in range(1, SLOTS + 1):
		var old := slot_dir(n) + LEGACY_SAVE
		if FileAccess.file_exists(old) and not FileAccess.file_exists(save_path(n)):
			DirAccess.rename_absolute(old, save_path(n))


# ------------------------------------------------------------------ Emplacements de sauvegarde

func slot_dir(n := -1) -> String:
	n = slot if n < 0 else n
	return root if n == 1 else root + "slot%d/" % n


func settings_path() -> String:
	return root + "settings.json"


func save_path(n := -1) -> String:
	return slot_dir(n) + "save.json"


func run_path(n := -1) -> String:
	return slot_dir(n) + "run_save.dat"


func gallery_dir(n := -1) -> String:
	return slot_dir(n) + "gallery"


func bestiary_dir(n := -1) -> String:
	return slot_dir(n) + "bestiary"


## Change de sauvegarde (et s'en souvient pour le prochain lancement).
func select_slot(n: int) -> void:
	slot = clampi(n, 1, SLOTS)
	settings["slot"] = slot
	_save_settings()
	load_data()


func slot_exists(n: int) -> bool:
	return FileAccess.file_exists(save_path(n))


## Résumé d'une sauvegarde sans la charger : {} si elle est vide.
func slot_summary(n: int) -> Dictionary:
	if not slot_exists(n):
		return {}
	var d := _read_json(save_path(n))
	var out := {"pigments": int(d.get("pigments", 0)), "runs": int(d.get("runs", 0)), "wins": int(d.get("wins", 0)),
		"best_wave": int(d.get("best_wave", 0)), "drawings": (d.get("gallery", []) as Array).size()}
	var r := read_run(n)
	if not r.is_empty():
		out.run = Loc.t("Vague %d · %s") % [int(r.wave), DIFFICULTIES[int(r.difficulty)].name]
	return out


## Efface une sauvegarde : progression, partie en cours, galerie et Codex.
func delete_slot(n: int) -> void:
	if no_save:
		return
	for f in [save_path(n), save_path(n) + ".bak", run_path(n), run_path(n) + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	for dir in [gallery_dir(n), bestiary_dir(n)]:
		var da := DirAccess.open(dir)
		if da == null:
			continue
		for f in da.get_files():
			if f.get_extension() == "png":
				DirAccess.remove_absolute(dir + "/" + f)
	if n == slot:
		load_data()


## Lit un JSON ; s'il manque ou est illisible (coupure pendant une écriture), reprend la version
## précédente gardée en .bak par _store().
func _read_json(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			return parsed
	return {}


## Écrit d'abord à côté (.tmp), puis met le fichier en place : une coupure pendant l'écriture ne
## détruit jamais la version d'avant (gardée en .bak). value : texte, ou Variant si as_var.
func _store(path: String, value, as_var := false) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	if as_var:
		f.store_var(value)
	else:
		f.store_string(value)
	f.close()
	if FileAccess.get_file_as_bytes(tmp).is_empty():
		return   # écriture ratée (disque plein...) : on garde l'ancien fichier
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	DirAccess.rename_absolute(tmp, path)


# ------------------------------------------------------------------ Partie en cours (reprise)

func has_run() -> bool:
	return FileAccess.file_exists(run_path())


## Fichier texte lisible (journal de partie). Jamais pendant les tests.
func write_text(path: String, text: String) -> void:
	if no_save:
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)


func save_run(state: Dictionary) -> void:
	if no_save:
		return
	_store(run_path(), state, true)


func read_run(n := -1) -> Dictionary:
	var p := run_path(n)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var v = f.get_var()
	return v if v is Dictionary else {}


func clear_run() -> void:
	if no_save:
		return
	for f in [run_path(), run_path() + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)


func default_data() -> Dictionary:
	return {"pigments": 0, "unlocks": {}, "gallery": [], "best_wave": 0, "max_diff": 0,
		"runs": 0, "wins": 0, "next_id": 1, "achievements": {}, "total_kills": 0, "pending_unlocks": []}


func load_data() -> void:
	data = default_data()
	var parsed := _read_json(save_path())
	for k in parsed:
		data[k] = parsed[k]
	data.erase("settings")   # les réglages sont communs aux sauvegardes (settings.json)
	# Anciennes sauvegardes : couleurs achetées une par une -> packs
	var u: Dictionary = data.unlocks
	for old in ["col_rouge", "col_bleu", "col_jaune"]:
		if u.has(old):
			u["pack_primaires"] = 1
	for old in ["col_vert", "col_violet", "col_blanc"]:
		if u.has(old):
			u["pack_secondaires"] = 1
	u.erase("tool_fill")
	_retro_achievements()
	data.erase("zoom")
	if not no_save:
		DirAccess.make_dir_recursive_absolute(gallery_dir())
		DirAccess.make_dir_recursive_absolute(bestiary_dir())


# ------------------------------------------------------------------ Réglages

func setting(key: String):
	return settings.get(key, DEFAULT_SETTINGS[key])


func set_setting(key: String, value, persist := true) -> void:
	settings[key] = value
	if persist:
		_save_settings()
	apply_settings()


## Réglages communs. Première fois : on reprend ceux de l'ancienne sauvegarde unique.
func _load_settings() -> void:
	settings = _read_json(settings_path())
	if settings.is_empty():
		var old := _read_json(save_path(1))
		settings = (old.get("settings", {}) as Dictionary).duplicate()
		if old.has("zoom"):
			settings["zoom"] = old.zoom


## Au lancement du jeu : crée settings.json s'il n'existe pas encore (migration des réglages).
func ensure_settings_file() -> void:
	if not FileAccess.file_exists(settings_path()):
		settings["slot"] = slot
		_save_settings()


func _save_settings() -> void:
	if no_save:
		return
	_store(settings_path(), JSON.stringify(settings, "\t"))


## Bus audio : « Musique » et « Bruitages » (sous le volume général, bus 0).
const BUS_MUSIC := "Musique"
const BUS_SFX := "Bruitages"


func _bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


func apply_settings() -> void:
	Loc.apply(String(setting("lang")))   # ("" : la langue du système)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(setting("volume")))))
	AudioServer.set_bus_volume_db(_bus(BUS_MUSIC), linear_to_db(maxf(0.0001, float(setting("music_volume")))))
	AudioServer.set_bus_volume_db(_bus(BUS_SFX), linear_to_db(maxf(0.0001, float(setting("sfx_volume")))))
	# On ne touche à la fenêtre que si le plein écran change : une fenêtre agrandie (maximisée)
	# n'est pas « fenêtrée », et la repasser en fenêtré la rétrécissait (ex. à chaque cran de zoom).
	# Fenêtre : « fenetre », « plein » (plein écran exclusif) ou « sans_bord » (plein écran sans bord :
	# Alt+Tab instantané). Les anciens réglages « fullscreen » deviennent « sans_bord » (même rendu).
	if settings.has("fullscreen"):
		settings.window_mode = "sans_bord" if bool(settings.fullscreen) else "fenetre"
		settings.erase("fullscreen")
	var want := DisplayServer.WINDOW_MODE_WINDOWED
	match String(setting("window_mode")):
		"plein":
			want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		"sans_bord":
			want = DisplayServer.WINDOW_MODE_FULLSCREEN
	var cur := DisplayServer.window_get_mode()
	var cur_fs := cur == DisplayServer.WINDOW_MODE_FULLSCREEN or cur == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want != cur and (want != DisplayServer.WINDOW_MODE_WINDOWED or cur_fs):
		DisplayServer.window_set_mode(want)


func save() -> void:
	if no_save:
		return
	DirAccess.make_dir_recursive_absolute(gallery_dir())
	DirAccess.make_dir_recursive_absolute(bestiary_dir())
	_store(save_path(), JSON.stringify(data, "\t"))


# ------------------------------------------------------------------ Déblocages

func level(id: String) -> int:
	return int(data.unlocks.get(id, 0))


func has(id: String) -> bool:
	return id == "" or level(id) > 0


func next_cost(id: String) -> int:
	var def := UnlockDB.get_def(id)
	var lv := level(id)
	if def.is_empty() or lv >= def.cost.size():
		return -1
	return int(def.cost[lv])


func buy(id: String) -> bool:
	if not UnlockDB.for_pigments(UnlockDB.get_def(id)):
		return false   # se débloque par un succès
	var c := next_cost(id)
	if c < 0 or int(data.pigments) < c:
		return false
	if not buy_open(id):
		return false
	data.pigments = int(data.pigments) - c
	data.unlocks[id] = level(id) + 1
	save()
	return true


## Conditions d'achat remplies (amélioration nécessaire, victoires) ?
func buy_open(id: String) -> bool:
	var d := UnlockDB.get_def(id)
	return has(String(d.get("req", ""))) and int(data.get("wins", 0)) >= int(d.get("wins", 0)) \
		and int(data.get("best_wave", 0)) >= int(d.get("best_wave", 0))


func pigments() -> int:
	return int(data.pigments)


## Ce que tu peux t'offrir tout de suite à l'établi de l'Atelier, du moins cher au plus cher.
func atelier_affordable() -> Array:
	var out := UnlockDB.LIST.filter(func(d): return UnlockDB.for_pigments(d) and buy_open(d.id) \
		and next_cost(d.id) >= 0 and next_cost(d.id) <= pigments())
	out.sort_custom(func(a, b): return next_cost(a.id) < next_cost(b.id))
	return out


## Achats possibles (« id:niveau ») : le bouton Atelier du titre brille tant que l'un d'eux
## n'était pas encore possible à ta dernière visite.
func _atelier_keys() -> Array:
	return atelier_affordable().map(func(d): return "%s:%d" % [d.id, level(d.id)])


func atelier_new() -> bool:
	var seen: Array = data.get("atelier_seen", [])
	return _atelier_keys().any(func(k): return not k in seen)


## Ouverture de l'Atelier : ce qui est achetable maintenant est « vu », le bouton s'éteint.
func atelier_visited() -> void:
	data.atelier_seen = _atelier_keys()
	save()


func base_ink() -> int:
	return 120 + 25 * level("ink")


## Pigments minimum gagnés par partie : on débloque vite le pack primaire.
const MIN_PIGMENTS := 6


func weapon_ink_bonus() -> int:
	return 10 * level("ink")


## Encrier : encre en plus pour les amulettes et les balles (plus petites que les armes).
func amulet_ink_bonus() -> int:
	return 5 * level("ink")


func bullet_ink_bonus() -> int:
	return 3 * level("ink")


func canvas_bonus() -> int:
	return 8 * level("canvas")


## Éléments (couleurs) disponibles. Le noir est toujours là.
func elements() -> Array:
	var out := [0]
	for e in range(1, Pal.COUNT):
		if has(Pal.UNLOCK[e]):
			out.append(e)
	return out


func effects() -> Array:
	var out := [""]
	for fx in Stats.EFFECT_UNLOCK:
		if has(Stats.EFFECT_UNLOCK[fx]):
			out.append(fx)
	return out


# ------------------------------------------------------------------ Succès

## OUTIL DE DEV : débloque tout sur la sauvegarde (objets, succès, Atelier au max, cartes, difficultés).
func unlock_all() -> void:
	if not data.has("item_unlocks"):
		data.item_unlocks = {}
	for key in ItemUnlockDB.CONDS:
		data.item_unlocks[key] = true
	if not data.has("achievements"):
		data.achievements = {}
	for a in AchievementDB.LIST:
		data.achievements[a.id] = true
	for u in UnlockDB.LIST:
		data.unlocks[u.id] = (u.cost as Array).size()
	var top := DIFFICULTIES.size() - 1
	var m: Dictionary = data.get("max_diff_map", {})
	for id in MapDB.MAPS:
		data.unlocks["map%d" % id] = 1
		m[str(id)] = top
	data.max_diff_map = m
	data.max_diff = top
	data.pending_unlocks = []
	save()


## Arme / amulette disponible ? (pas de condition, ou succès obtenu et partie terminée)
func item_open(key: String) -> bool:
	return not ItemUnlockDB.CONDS.has(key) or bool(data.get("item_unlocks", {}).get(key, false))


## Arme / amulette déjà croisée en boutique (sinon : « ! » sur son tableau).
func item_seen(key: String) -> bool:
	return bool(data.get("seen_items", {}).get(key, false))


func mark_seen(key: String) -> void:
	if not data.has("seen_items"):
		data.seen_items = {}
	data.seen_items[key] = true


func achieved(id: String) -> bool:
	return bool(data.get("achievements", {}).get(id, false))


## Succès obtenu pendant la partie en cours : son amélioration n'arrive qu'à la fin.
func pending(id: String) -> bool:
	return id in data.get("pending_unlocks", [])


## Fin de partie (victoire, défaite, abandon, partie remplacée) : applique les améliorations
## des succès obtenus pendant la partie. Retourne leurs ids (pour le récapitulatif).
func apply_pending_unlocks() -> Array:
	var out: Array = (data.get("pending_unlocks", []) as Array).duplicate()
	for id in out:
		if String(id).begins_with("w:") or String(id).begins_with("a:") or String(id).begins_with("f:"):
			if not data.has("item_unlocks"):
				data.item_unlocks = {}
			data.item_unlocks[id] = true
			continue
		var a := AchievementDB.get_def(id)
		if not a.is_empty() and level(a.unlock) == 0:
			data.unlocks[a.unlock] = 1
	data.pending_unlocks = []
	if not out.is_empty():
		save()
	return out


## Anciennes sauvegardes : les succès déjà mérités (record, victoires, galerie) ou dont
## l'amélioration a déjà été achetée sont cochés, sans notification.
func _retro_achievements() -> void:
	if not data.has("achievements"):
		data.achievements = {}
	var wins := int(data.get("wins", 0))
	# (Run est chargé après Meta : on lit la constante dans le script, pas sur le nœud)
	var ctx := {"cleared": mini(int(data.get("best_wave", 0)), RUN_SCRIPT.WAVES), "win": wins > 0,
		"diff": int(data.get("max_diff", 0)) - 1, "gallery": own_gallery_size(),
		"total_kills": int(data.get("total_kills", 0))}
	if wins > 0:
		data.unlocks["map2"] = 1   # déjà gagné une partie : Le Tableau noir est ouvert
	if not data.has("item_unlocks"):
		data.item_unlocks = {}
	var ictx := {"cleared": ctx.cleared, "win": wins > 0, "diff": ctx.diff, "gallery": ctx.gallery,
		"total_kills": ctx.total_kills, "runs": int(data.get("runs", 0)), "bosses": data.get("bosses_beaten", {}),
		"total_elites": int(data.get("total_elites", 0))}
	for key in ItemUnlockDB.CONDS:
		if ItemUnlockDB.met(ItemUnlockDB.CONDS[key], ictx):
			data.item_unlocks[key] = true
	for a in AchievementDB.LIST:
		if achieved(a.id):
			continue
		if level(a.unlock) > 0 or AchievementDB.met(a, ctx):
			data.achievements[a.id] = true
			if level(a.unlock) == 0:
				data.unlocks[a.unlock] = 1
	# Succès déjà obtenus dont la récompense a changé (ex. « Sans rature » → Triangle) : on la donne
	for a in AchievementDB.LIST:
		if achieved(a.id) and not pending(a.id) and level(a.unlock) == 0:
			data.unlocks[a.unlock] = 1


## Compteurs de toutes les parties (dégâts, or dépensé, boss vaincus, roulette...).
func count(key: String, n := 1.0) -> void:
	if Run.seeded and Run.active:
		return   # partie avec seed : rien ne compte
	if not data.has("counters"):
		data.counters = {}
	data.counters[key] = float(data.counters.get(key, 0.0)) + n


## Vague finie sur cette carte (succès « les deux cartes »).
func map_cleared(map_id: int) -> void:
	if not data.has("maps_cleared"):
		data.maps_cleared = {}
	data.maps_cleared[str(map_id)] = true


## Vérifie tous les succès avec ce contexte. Pendant une partie, l'amélioration gagnée est mise
## de côté et n'est appliquée qu'à la fin (apply_pending_unlocks) ; hors partie, tout de suite.
func check_achievements(ctx: Dictionary) -> void:
	if Run.seeded and Run.active:
		return   # partie avec seed : elle ne débloque rien
	if not data.has("achievements"):
		data.achievements = {}
	if not data.has("pending_unlocks"):
		data.pending_unlocks = []
	ctx = ctx.duplicate()
	ctx.total_kills = int(data.get("total_kills", 0)) + int(ctx.get("kills", 0))
	ctx.total_elites = int(data.get("total_elites", 0)) + int(ctx.get("elites", 0))
	var bosses: Dictionary = (data.get("bosses_beaten", {}) as Dictionary).duplicate()
	bosses.merge(ctx.get("bosses", {}))
	ctx.bosses = bosses
	ctx.runs = int(data.get("runs", 0)) + (1 if Run.active else 0)
	ctx.gallery = own_gallery_size()
	ctx.counters = data.get("counters", {})
	ctx.maps = (data.get("maps_cleared", {}) as Dictionary).size()
	var changed := false
	# Succès d'objets (armes / amulettes) : conditions visibles dans le Codex
	if not data.has("item_unlocks"):
		data.item_unlocks = {}
	var fresh := []
	for key in ItemUnlockDB.CONDS:
		if item_open(key) or key in data.pending_unlocks or not ItemUnlockDB.met(ItemUnlockDB.CONDS[key], ctx):
			continue
		changed = true
		fresh.append(key)
		if Run.active:
			data.pending_unlocks.append(key)
		else:
			data.item_unlocks[key] = true
	# Une seule notification, même si plusieurs objets tombent d'un coup
	if not fresh.is_empty():
		var head := Loc.t("DÉBLOQUÉ À LA FIN DE LA PARTIE") if Run.active else Loc.t("DÉBLOQUÉ")
		UI.toast(head + "\n" + (ItemUnlockDB.label(fresh[0]) if fresh.size() == 1 else Loc.t("%d nouveaux objets") % fresh.size()))
	for a in AchievementDB.LIST:
		if achieved(a.id) or not AchievementDB.met(a, ctx):
			continue
		data.achievements[a.id] = true
		var reward: String = UnlockDB.get_def(a.unlock).name
		if Run.active:
			data.pending_unlocks.append(a.id)
			UI.toast(Loc.t("DÉFI RÉUSSI : %s\n%s : débloqué à la fin de la partie") % [a.name, reward])
		else:
			if level(a.unlock) == 0:
				data.unlocks[a.unlock] = 1
			UI.toast(Loc.t("DÉFI RÉUSSI : %s\nDébloque : %s") % [a.name, reward])
		changed = true
		Sfx.play("level")
	if changed:
		save()
		SteamLink.sync()   # un défi vient d'être réussi : le succès Steam tombe tout de suite


# ------------------------------------------------------------------ Galerie

## Ajoute un dessin à la galerie (sans limite : la galerie ne supprime jamais rien toute seule).
## imported : dessin reçu d'un autre joueur (il ne compte pas dans tes pixels peints).
## Retourne true si le dessin a été ajouté (false : vide, caché, ou déjà là).
func add_to_gallery(kind: String, img: Image, effect: String, imported := false, outline := false) -> bool:
	if kind in GALLERY_HIDDEN:
		return false
	if no_save:
		return false
	if Analyzer.count_pixels(img) == 0:
		return false
	var h := str(hash(img.get_data()))
	if not imported:
		data.pixels_painted = int(data.get("pixels_painted", 0)) + Analyzer.count_pixels(img)   # (statistiques)
	if gallery_has(kind, h):
		return false
	var id := int(data.next_id)
	data.next_id = id + 1
	var path := "%s/%s_%d.png" % [gallery_dir(), kind, id]
	img.save_png(path)
	var entry := {"id": id, "kind": kind, "file": path, "effect": effect, "hash": h,
		"w": img.get_width(), "h": img.get_height(), "px": Analyzer.count_pixels(img)}
	if outline:
		entry.outline = true
	if imported:
		entry.imported = true   # (reçu d'un ami : ne compte pas pour les succès de galerie)
	data.gallery.append(entry)
	save()
	if not imported:
		check_achievements({})
	return true


## Nombre de dessins de la galerie faits par TOI (pour les succès : les dessins importés ne comptent pas).
func own_gallery_size() -> int:
	return (data.gallery as Array).filter(func(e): return not e.get("imported", false)).size()


## Couleurs (éléments) de ce dessin que tu n'as pas encore débloquées (pack primaire / secondaire).
## Un dessin importé peut en contenir : il reste dans la galerie, mais inutilisable jusque-là.
func locked_colors(img: Image) -> Array:
	var out := []
	var frac: Array = Analyzer.analyze(img).get("frac", [])
	for e in range(1, mini(frac.size(), Pal.COUNT)):
		if float(frac[e]) > 0.0 and not has(Pal.UNLOCK[e]):
			out.append(Pal.COLOR_NAMES[e])
	return out


## Ce dessin (même type, mêmes pixels) est-il déjà dans la galerie ?
func gallery_has(kind: String, h: String) -> bool:
	for e in data.gallery:
		if e.kind == kind and e.get("hash", "") == h:
			return true
	return false


# ------------------------------------------------------------------ Partage de dessins (.zip)
## Un fichier .zip : les PNG dans « dessins/ » + une fiche « paintit_galerie.json »
## {version, items: [{file, kind, effect, outline}]}. Rien n'est jamais écrasé à l'import :
## chaque dessin reçoit un nouveau numéro, les doublons sont ignorés.
const SHARE_MANIFEST := "paintit_galerie.json"
const SHARE_KINDS := ["character", "melee", "ranged", "bullet", "amulet", "familiar", "enemy", "boss"]
const SHARE_MAX_PX := 256   # (un dessin plus grand qu'une toile du jeu est refusé)
const SHARE_MAX_ITEMS := 500


## Exporte ces entrées de galerie dans un .zip. Retourne le nombre de dessins écrits (-1 : erreur).
func export_gallery(entries: Array, path: String) -> int:
	var zp := ZIPPacker.new()
	if zp.open(path) != OK:
		return -1
	var items := []
	var n := 0
	for e in entries:
		var bytes := FileAccess.get_file_as_bytes(String(e.file))
		if bytes.is_empty():
			continue
		n += 1
		var name := "dessins/%03d_%s.png" % [n, e.kind]
		zp.start_file(name)
		zp.write_file(bytes)
		zp.close_file()
		items.append({"file": name, "kind": e.kind, "effect": e.get("effect", ""), "outline": e.get("outline", false)})
	zp.start_file(SHARE_MANIFEST)
	zp.write_file(JSON.stringify({"version": 1, "game": Loc.t("Paint It Until You Make It"), "items": items}, "\t").to_utf8_buffer())
	zp.close_file()
	zp.close()
	return n


## Lit un .zip de dessins. Retourne {ok, error, items: [{image, kind, effect, outline, dup}]}.
func read_share(path: String) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(path) != OK:
		return {"ok": false, "error": Loc.t("Impossible d'ouvrir ce fichier."), "items": []}
	var files := zr.get_files()
	if not SHARE_MANIFEST in files:
		zr.close()
		return {"ok": false, "error": Loc.t("Ce n'est pas un partage de dessins de Paint It."), "items": []}
	var man = JSON.parse_string(zr.read_file(SHARE_MANIFEST).get_string_from_utf8())
	var out := []
	if man is Dictionary:
		for it in (man.get("items", []) as Array).slice(0, SHARE_MAX_ITEMS):
			if not it is Dictionary or not String(it.get("kind", "")) in SHARE_KINDS or not String(it.get("file", "")) in files:
				continue
			var buf := zr.read_file(String(it.file))
			# Largeur et hauteur dans l'en-tête du PNG (octets 16-23) : une image géante (fichier piégé)
			# est refusée avant d'être décodée en mémoire
			if buf.size() < 24 or _be32(buf, 16) > SHARE_MAX_PX or _be32(buf, 20) > SHARE_MAX_PX:
				continue
			var img := Image.new()
			if img.load_png_from_buffer(buf) != OK:
				continue
			if img.get_width() > SHARE_MAX_PX or img.get_height() > SHARE_MAX_PX or Analyzer.count_pixels(img) == 0:
				continue
			img.convert(Image.FORMAT_RGBA8)
			var fx := String(it.get("effect", ""))
			if not fx in Stats.EFFECTS:
				fx = ""
			out.append({"image": img, "kind": String(it.kind), "effect": fx, "outline": bool(it.get("outline", false)),
				"dup": gallery_has(String(it.kind), str(hash(img.get_data())))})
	zr.close()
	if out.is_empty():
		return {"ok": false, "error": Loc.t("Aucun dessin lisible dans ce fichier."), "items": []}
	return {"ok": true, "error": "", "items": out}


static func _be32(b: PackedByteArray, i: int) -> int:
	return (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3]


## Ajoute ces dessins reçus (les doublons sont ignorés). Retourne le nombre ajouté.
func import_share(items: Array) -> int:
	var n := 0
	for it in items:
		if add_to_gallery(String(it.kind), it.image, String(it.effect), true, bool(it.get("outline", false))):
			n += 1
	return n


## Galerie : à quoi ce dessin sert-il de dessin de base dans le Codex ? (noms lisibles)
func gallery_uses(img: Image) -> Array:
	var out := []
	var target := Analyzer.trim(img).get_data()
	var b: Dictionary = data.get("bestiary", {})
	for key in b:
		var e = bestiary_get(key)
		if e != null and Analyzer.trim(e.image).get_data() == target:
			out.append(bestiary_label(String(key)))
	return out


## Nom lisible d'une case du Codex (« Épée (rare) », « Balles : Arc », « Ton perso »...).
func bestiary_label(key: String) -> String:
	if key == "perso":
		return Loc.t("Ton perso")
	if key.begins_with("amulette_"):
		return Loc.t("Amulette : ") + String(AmuletDB.get_def(key.substr(9)).get("name", key))
	if key.begins_with("familier_"):
		return Loc.t("Familier : ") + String(FamiliarDB.get_def(key.substr(9)).get("name", key))
	if key.begins_with("balle_"):
		return Loc.t("Balles : ") + String(WeaponDB.get_def(key.substr(6)).get("name", key))
	if key.begins_with("arme_"):
		var rest := key.substr(5)
		var rar := -1
		var m := rest.rfind("_r")
		if m > 0 and rest.substr(m + 2).is_valid_int():
			rar = int(rest.substr(m + 2))
			rest = rest.substr(0, m)
		var wd := WeaponDB.get_def(rest)
		if rar < 0:
			rar = int(wd.get("min_rar", 0))
		return "%s (%s)" % [wd.get("name", rest), Pal.RARITY_NAMES_F[rar].to_lower()]
	var elite := key.ends_with("_elite")
	var id := key.trim_suffix("_elite")
	var ed := EnemyDB.get_def(id)
	return (Loc.t("Élite : ") if elite else (Loc.t("Boss : ") if ed.has("boss") else Loc.t("Ennemi : "))) + String(ed.get("name", id))


## Galerie : active / désactive le bord d'un dessin (utilisé quand on le réutilise).
func gallery_set_outline(entry: Dictionary, on: bool) -> void:
	for e in data.gallery:
		if e.file == entry.file:
			e.outline = on
	entry.outline = on
	save()


## Dessins qu'on ne garde plus dans la galerie (marques, tirs ennemis : plus utiles).
const GALLERY_HIDDEN := ["mark", "eproj"]


func gallery(kind: String) -> Array:
	var out: Array = data.gallery.filter(func(e): return (e.kind == kind or (kind == "all" and not e.kind in GALLERY_HIDDEN)) and FileAccess.file_exists(e.file))
	out.reverse()
	return out


# ------------------------------------------------------------------ Codex (carnet des ennemis)

## Dessin du carnet pour un ennemi (clé = id, ou id + "_elite"), ou null.
func bestiary_get(key: String):
	var b: Dictionary = data.get("bestiary", {})
	if not b.has(key):
		return null
	var e: Dictionary = b[key]
	if not FileAccess.file_exists(e.file):
		return null
	var img := Image.load_from_file(e.file)
	if img == null:
		return null
	return {"image": img, "effect": e.get("effect", ""), "outline": e.get("outline", false)}


func bestiary_set(key: String, img: Image, effect: String, outline: bool) -> void:
	if no_save:
		return
	if not data.has("bestiary"):
		data.bestiary = {}
	var path := "%s/%s.png" % [bestiary_dir(), key]
	img.save_png(path)
	data.bestiary[key] = {"file": path, "effect": effect, "outline": outline}
	save()


func bestiary_remove(key: String) -> void:
	if no_save:
		return
	var b: Dictionary = data.get("bestiary", {})
	if b.has(key):
		DirAccess.remove_absolute(b[key].file)
		b.erase(key)
		save()


func add_pigments(n: int) -> void:
	if no_save:
		return
	data.pigments = int(data.pigments) + n
	save()


## Retire un dessin de la galerie (et son fichier).
func remove_from_gallery(entry: Dictionary) -> void:
	if no_save:
		return
	for e in data.gallery:
		if e.file == entry.file:
			DirAccess.remove_absolute(e.file)
			data.gallery.erase(e)
			break
	save()


func gallery_image(entry: Dictionary) -> Image:
	return Image.load_from_file(entry.file)


# ------------------------------------------------------------------ Fin de partie

## Difficulté maximale débloquée SUR CETTE CARTE (chaque carte a sa propre progression).
## Anciennes sauvegardes : l'ancienne progression globale compte pour La Feuille.
func max_diff(map_id: int) -> int:
	var m: Dictionary = data.get("max_diff_map", {})
	if m.has(str(map_id)):
		return int(m[str(map_id)])
	return int(data.get("max_diff", 0)) if map_id == 1 else 0


## Carte jouable ? La 1re toujours ; la 2e après une victoire sur la 1re.
func map_unlocked(id: int) -> bool:
	return id == 1 or level("map%d" % id) > 0


## Retourne le numéro de la carte que cette partie vient de débloquer (0 : aucune).
## Fin d'une partie en mode infini (la victoire a déjà été comptée) : record de vague infinie.
func record_endless(wave_reached: int, earned: int, kills: int, elites: int) -> void:
	data.total_elites = int(data.get("total_elites", 0)) + maxi(0, elites)
	var bb: Dictionary = data.get("bosses_beaten", {})
	bb.merge(Run.boss_ids)
	data.bosses_beaten = bb
	data.total_kills = int(data.get("total_kills", 0)) + maxi(0, kills)
	data.pigments = int(data.pigments) + earned
	data.best_wave = maxi(int(data.best_wave), wave_reached)
	data.best_endless = maxi(int(data.get("best_endless", 0)), wave_reached)
	data.play_time = float(data.get("play_time", 0.0)) + Run.play_time - float(Run.endless_base.get("time", 0.0))
	# l'historique garde UNE fiche par partie : celle de la victoire est complétée
	var h: Array = data.get("history", [])
	if not h.is_empty() and bool(h[-1].get("win", false)):
		var e: Dictionary = Run.history_entry(true)
		e.endless = true
		e.killer = Run.killer
		h[-1] = e
	save()


const HISTORY_MAX := 300   # parties gardées pour les statistiques


func record_run(wave_reached: int, win: bool, difficulty: int, earned: int, kills := 0, map_id := 1) -> int:
	var new_map := 0   # numéro de la carte que cette partie vient de débloquer (0 : aucune)
	data.total_elites = int(data.get("total_elites", 0)) + Run.elite_kills
	var bb: Dictionary = data.get("bosses_beaten", {})
	bb.merge(Run.boss_ids)
	data.bosses_beaten = bb
	# Gagner sur une carte ouvre la suivante (La Feuille → Le Tableau noir → L'Écran)
	if win and MapDB.MAPS.has(map_id + 1) and not map_unlocked(map_id + 1):
		data.unlocks["map%d" % (map_id + 1)] = 1
		new_map = map_id + 1
	data.total_kills = int(data.get("total_kills", 0)) + kills
	data.runs = int(data.runs) + 1
	data.pigments = int(data.pigments) + earned
	data.best_wave = maxi(int(data.best_wave), wave_reached)
	data.play_time = float(data.get("play_time", 0.0)) + Run.play_time
	if not data.has("history"):
		data.history = []
	data.history.append(Run.history_entry(win))
	if data.history.size() > HISTORY_MAX:
		data.history = data.history.slice(data.history.size() - HISTORY_MAX)
	if win:
		data.wins = int(data.wins) + 1
		var next := mini(difficulty + 1, DIFFICULTIES.size() - 1)
		var m: Dictionary = data.get("max_diff_map", {})
		m[str(map_id)] = maxi(max_diff(map_id), next)
		if not m.has("1"):
			m["1"] = max_diff(1)
		data.max_diff_map = m
		data.max_diff = maxi(int(data.max_diff), next)   # meilleure difficulté toutes cartes (succès)
	save()
	return new_map
