extends Node
## Steam : les succès et les statistiques envoyés, vérifiés avec un FAUX Steam (aucun appel réseau,
## Steam n'a pas besoin d'être lancé). Vérifie aussi que le jeu ne fait rien sans Steam.
## Godot --headless --path . res://tests/steamtest.tscn

var fails := 0


## Un Steam de test : mêmes fonctions que le singleton de GodotSteam, tout est noté.
class FakeSteam extends RefCounted:
	var ok := true
	var names: Array = []
	var achieved := {}
	var stats := {}
	var stores := 0
	var sets := 0

	func steamInitEx(_app_id: int, _embed: bool) -> Dictionary:
		return {"status": 0 if ok else 1, "verbal": "test"}

	func getNumAchievements() -> int:
		return names.size()

	func getAchievementName(i: int) -> String:
		return names[i]

	func getAchievement(n: String) -> Dictionary:
		return {"ret": names.has(n), "achieved": achieved.has(n)}

	func setAchievement(n: String) -> bool:
		if not names.has(n):
			return false
		achieved[n] = true
		sets += 1
		return true

	func getStatInt(n: String) -> int:
		return int(stats.get(n, 0))

	func setStatInt(n: String, v: int) -> bool:
		stats[n] = v
		return true

	func storeStats() -> bool:
		stores += 1
		return true


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Meta.no_save = true
	Meta.settings = Meta.settings.duplicate()
	Meta.data = Meta.data.duplicate(true)
	Meta.data.item_unlocks = {}
	Meta.data.achievements = {}
	Meta.data.pending_unlocks = []
	Meta.data.counters = {}
	Meta.data.total_kills = 0
	Meta.data.total_elites = 0
	Meta.data.runs = 0
	await get_tree().process_frame

	# --- Sans Steam : rien ne se passe, rien ne plante
	_check(not SteamLink.on, "au lancement d'un test : pas connecté à Steam")
	SteamLink.sync()
	SteamLink.unlock("A_SATELLITE")
	_check(not SteamLink.on, "sans Steam : sync et unlock ne font rien")
	var off := FakeSteam.new()
	off.ok = false
	_check(not SteamLink.connect_api(off) and not SteamLink.on and SteamLink.api == null, "Steam fermé : la connexion échoue proprement")

	# --- Noms d'API
	_check(SteamLink.item_api("a:satellite") == "A_SATELLITE" and SteamLink.item_api("w:plume") == "W_PLUME"
		and SteamLink.item_api("f:pie") == "F_PIE" and SteamLink.atelier_api("victoire") == "ATELIER_VICTOIRE", "noms d'API des succès")
	var missing := []
	for key in ItemUnlockDB.CONDS:
		if not RegEx.create_from_string("^[AWF]_[A-Z0-9_]+$").search(SteamLink.item_api(key)):
			missing.append(key)
	_check(missing.is_empty(), "tous les objets donnent un nom d'API valide (%s)" % str(missing))

	# --- Connexion : rattrapage de ce que la sauvegarde a déjà
	var fake := FakeSteam.new()
	fake.names = ["ATELIER_VICTOIRE", "ATELIER_KILLS", "A_SATELLITE", "A_PELLICULE", "W_PLUME", "F_PIE", "SET_FAMILIERS", "SET_ARMES", "SET_TOUT"]
	Meta.data.item_unlocks = {"w:plume": true, "a:combo": true}
	Meta.data.pending_unlocks = ["a:satellite"]
	Meta.data.achievements = {"victoire": true}
	Meta.data.total_kills = 1234
	Meta.data.runs = 7
	Meta.data.counters = {"bosses": 3.0, "gold_spent": 450.0}
	_check(SteamLink.connect_api(fake) and SteamLink.on, "connexion à Steam")
	_check(SteamLink.known.size() == fake.names.size(), "les succès qui existent sur Steam sont lus (%d)" % SteamLink.known.size())
	_check(fake.achieved.has("W_PLUME") and fake.achieved.has("ATELIER_VICTOIRE"), "rattrapage : objet débloqué et défi d'Atelier déjà réussis")
	_check(fake.achieved.has("A_SATELLITE"), "un défi réussi en cours de partie compte tout de suite (objet encore en attente)")
	_check(not fake.achieved.has("A_COMBO") and not fake.achieved.has("A_PELLICULE") and not fake.achieved.has("F_PIE"), "ni les succès absents de Steam, ni les défis pas réussis")
	_check(fake.stats.get("STAT_KILLS") == 1234 and fake.stats.get("STAT_RUNS") == 7 and fake.stats.get("STAT_BOSSES") == 3 and fake.stats.get("STAT_GOLD_SPENT") == 450, "compteurs envoyés (%s)" % str(fake.stats))
	_check(fake.stats.get("STAT_UNLOCKED_WEAPONS") == 1 and fake.stats.get("STAT_UNLOCKED_LEGENDARY") == 1 and fake.stats.get("STAT_UNLOCKED_COMMON") == 1 and fake.stats.get("STAT_UNLOCKED_ALL") == 3, "collections : 1 arme, 1 légendaire, 1 commune, 3 objets")
	_check(fake.stores == 1, "un seul envoi groupé à Steam (%d)" % fake.stores)

	# --- Rien de nouveau : rien n'est renvoyé
	var sets0 := fake.sets
	SteamLink.sync()
	SteamLink.sync()
	_check(fake.sets == sets0 and fake.stores == 1, "sans rien de nouveau, sync ne renvoie rien")

	# --- Un défi réussi pendant le jeu : le succès tombe par check_achievements
	Run.start(0, 1)
	Run.gold = 600   # (Investisseur : 500 or en poche ; Pinceau de Midas : 300...)
	fake.names.append("A_INVESTISSEUR")
	SteamLink.known["A_INVESTISSEUR"] = true
	Meta.check_achievements(Run.achievement_ctx(1))
	_check(fake.achieved.has("A_INVESTISSEUR") and fake.stores == 2, "défi réussi en jeu : succès Steam accordé aussitôt")
	Run.active = false

	# --- Une statistique ne redescend jamais (autre sauvegarde moins avancée)
	Meta.data.total_kills = 10
	SteamLink.sync()
	_check(fake.stats.get("STAT_KILLS") == 1234, "une statistique ne redescend pas (%d)" % int(fake.stats.get("STAT_KILLS")))

	# --- Collections complètes
	for key in ItemUnlockDB.CONDS:
		if String(key).begins_with("f:"):
			Meta.data.item_unlocks[key] = true
	SteamLink.sync()
	_check(fake.achieved.has("SET_FAMILIERS") and fake.achieved.has("F_PIE") and not fake.achieved.has("SET_ARMES") and not fake.achieved.has("SET_TOUT"), "tous les familiers débloqués : SET_FAMILIERS, pas les autres collections")
	for key in ItemUnlockDB.CONDS:
		Meta.data.item_unlocks[key] = true
	SteamLink.sync()
	_check(fake.achieved.has("SET_ARMES") and fake.achieved.has("SET_TOUT") and int(fake.stats.get("STAT_UNLOCKED_ALL")) == ItemUnlockDB.CONDS.size(), "tout débloqué : SET_ARMES et SET_TOUT (%d objets)" % int(fake.stats.get("STAT_UNLOCKED_ALL")))

	# --- Un succès déjà obtenu sur Steam n'est pas renvoyé
	var fake2 := FakeSteam.new()
	fake2.names = ["W_PLUME"]
	fake2.achieved = {"W_PLUME": true}
	SteamLink.connect_api(fake2)
	_check(fake2.sets == 0, "un succès déjà obtenu sur Steam n'est pas renvoyé")

	SteamLink.on = false
	SteamLink.api = null
	print("STEAMTEST : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
