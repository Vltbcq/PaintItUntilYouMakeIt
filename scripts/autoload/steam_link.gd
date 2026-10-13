extends Node
## Steam : succès et statistiques. Le jeu marche SANS Steam (build de test, version hors Steam, Steam
## fermé) : dans ce cas rien n'est envoyé, et tous les défis restent ceux du jeu.
##
## Un défi réussi dans le jeu = un succès Steam, quand ce succès existe sur la page Steamworks :
##   objet débloqué "a:satellite"  -> A_SATELLITE   (w: arme -> W_..., f: familier -> F_...)
##   défi de l'Atelier "victoire"  -> ATELIER_VICTOIRE
##   collections                   -> SET_AMULETTES_COMMUNES / _RARES / _EPIQUES / _LEGENDAIRES, SET_ARMES,
##                                    SET_FAMILIERS, SET_TOUT (tous les objets d'un groupe débloqués)
## Seuls les succès qui EXISTENT côté Steam sont envoyés (la liste est lue au démarrage) : en ajouter
## plus tard dans Steamworks suffit, sans toucher au code. sync() rattrape aussi tout ce que le joueur
## avait déjà réussi avant.
##
## Le plugin GodotSteam (addons/godotsteam) n'est jamais nommé directement : s'il manque (le .exe seul,
## sans ses .dll), le jeu démarre quand même.

const APP_ID := 5398060

## Compteurs du jeu -> statistiques Steam (barres de progression des succès)
const COUNTERS := {"STAT_BOSSES": "bosses", "STAT_GOLD_SPENT": "gold_spent", "STAT_GOLD_EARNED": "gold_earned",
	"STAT_DAMAGE": "damage", "STAT_ROULETTE_WINS": "roulette_wins"}
const RARITY_SETS := ["COMMUNES", "RARES", "EPIQUES", "LEGENDAIRES"]
const RARITY_STATS := ["STAT_UNLOCKED_COMMON", "STAT_UNLOCKED_RARE", "STAT_UNLOCKED_EPIC", "STAT_UNLOCKED_LEGENDARY"]

var api: Object      # le singleton Steam de GodotSteam (ou un faux, dans les tests)
var on := false      # Steam est là et le jeu y est connecté
var known := {}      # noms d'API des succès qui existent sur Steam
var _given := {}     # succès déjà accordés (pour ne pas les renvoyer)
var _sent := {}      # dernière valeur envoyée de chaque statistique
var _dirty := false


## Appelé une fois au lancement du jeu (jamais par les tests).
func start() -> void:
	# (PAINTIT_NO_STEAM : le test de démarrage de la release tourne sur une machine sans Steam)
	if on or not Engine.has_singleton("Steam") or OS.get_environment("PAINTIT_NO_STEAM") != "":
		return
	connect_api(Engine.get_singleton("Steam"))


## Se connecte à Steam par cette interface. Faux si Steam n'est pas lancé ou refuse le jeu.
func connect_api(a: Object) -> bool:
	var r: Dictionary = a.steamInitEx(APP_ID, true)   # (true : GodotSteam traite lui-même les retours de Steam)
	on = int(r.get("status", 1)) == 0
	if not on:
		print("Steam : pas connecté (%s)" % String(r.get("verbal", "?")))
		return false
	api = a
	known = {}
	_given = {}
	_sent = {}
	sync()
	return true


## Lit la liste des succès qui existent sur Steam (vide tant que rien n'est publié dans Steamworks).
func _read_known() -> void:
	for i in int(api.getNumAchievements()):
		known[String(api.getAchievementName(i))] = true


## Nom d'API du succès d'un objet : "a:satellite" -> "A_SATELLITE".
static func item_api(key: String) -> String:
	return ("%s_%s" % [key[0], key.substr(2)]).to_upper()


static func atelier_api(id: String) -> String:
	return "ATELIER_" + id.to_upper()


## Accorde un succès (s'il existe sur Steam et n'est pas déjà obtenu).
func unlock(api_name: String) -> void:
	if not on or not known.has(api_name) or _given.has(api_name):
		return
	_given[api_name] = true
	if bool((api.getAchievement(api_name) as Dictionary).get("achieved", false)):
		return
	if api.setAchievement(api_name):
		_dirty = true


func _stat(stat_name: String, value: int) -> void:
	if not _sent.has(stat_name):
		_sent[stat_name] = int(api.getStatInt(stat_name))
	if value > int(_sent[stat_name]):   # (une statistique ne redescend jamais : autre sauvegarde, autre PC...)
		_sent[stat_name] = value
		if api.setStatInt(stat_name, value):
			_dirty = true


## Un objet compte comme débloqué dès que son défi est réussi (même si l'objet n'arrive qu'en fin de partie).
func _has(key: String) -> bool:
	return Meta.item_open(key) or key in Meta.data.get("pending_unlocks", [])


## Envoie à Steam tout ce que la sauvegarde sait : succès mérités, compteurs, collections.
func sync() -> void:
	if not on:
		return
	if known.is_empty():
		_read_known()   # (relu tant que la liste est vide : succès pas encore publiés, ou pas encore chargés)
		_given = {}
	var by_rar := [0, 0, 0, 0]
	var by_rar_total := [0, 0, 0, 0]
	var weapons := [0, 0]
	var pets := [0, 0]
	for key in ItemUnlockDB.CONDS:
		var k := String(key)
		var got := _has(k)
		if got:
			unlock(item_api(k))
		if k.begins_with("w:"):
			weapons[1] += 1
			weapons[0] += int(got)
		elif k.begins_with("f:"):
			pets[1] += 1
			pets[0] += int(got)
		else:
			var rar := int(AmuletDB.get_def(k.substr(2)).get("rar", 0))
			by_rar_total[rar] += 1
			by_rar[rar] += int(got)
	for a in AchievementDB.LIST:
		if Meta.achieved(a.id):
			unlock(atelier_api(a.id))
	# Collections
	var all := [weapons[0] + pets[0], weapons[1] + pets[1]]
	for r in 4:
		all[0] += by_rar[r]
		all[1] += by_rar_total[r]
		_stat(RARITY_STATS[r], by_rar[r])
		if by_rar[r] >= by_rar_total[r]:
			unlock("SET_AMULETTES_" + RARITY_SETS[r])
	_stat("STAT_UNLOCKED_WEAPONS", weapons[0])
	_stat("STAT_UNLOCKED_PETS", pets[0])
	_stat("STAT_UNLOCKED_ALL", all[0])
	if weapons[0] >= weapons[1]:
		unlock("SET_ARMES")
	if pets[0] >= pets[1]:
		unlock("SET_FAMILIERS")
	if all[0] >= all[1]:
		unlock("SET_TOUT")
	# Compteurs de toutes les parties
	var d: Dictionary = Meta.data
	var c: Dictionary = d.get("counters", {})
	_stat("STAT_KILLS", int(d.get("total_kills", 0)))
	_stat("STAT_ELITES", int(d.get("total_elites", 0)))
	_stat("STAT_RUNS", int(d.get("runs", 0)))
	_stat("STAT_GALLERY", Meta.own_gallery_size())
	for stat_name in COUNTERS:
		_stat(stat_name, int(c.get(COUNTERS[stat_name], 0)))
	if _dirty:
		_dirty = false
		api.storeStats()
