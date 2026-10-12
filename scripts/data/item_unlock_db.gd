class_name ItemUnlockDB
extends RefCounted
## Succès qui DÉBLOQUENT des armes et des amulettes (la moitié du jeu). Un objet verrouillé
## n'apparaît pas en boutique. Les conditions ne sont affichées que dans le Codex.
## Obtenu pendant une partie : l'objet n'est disponible qu'à la fin de la partie.
## Clés : "w:<type d'arme>", "a:<id d'amulette>" ou "f:<id de familier>".
##
## kind : "stat" (stat du perso >= v), "gold" (or en poche >= v), "colors" (couleurs du perso),
## "pixels" (pixels du perso), "solo" (vague v finie avec une seule arme), "wave" (vague finie),
## "win" (partie gagnée, difficulté >= v), "kills" / "elites" (ennemis / élites tués, toutes
## parties), "level", "boss" (boss vaincu), "runs" (parties jouées), "syn" (synergie de
## l'élément el active à la vague v ou plus), "syn2" (v synergies actives en même temps),
## "legends" (v armes légendaires à la fois), "clean" (vague >= v finie sans perdre de PV), "gallery",
## "only" (vague v finie avec uniquement des armes wkind : "melee" ou "ranged").
## v0.12 : "amulets" (v amulettes possédées en même temps), "bare" (vague v finie avec 0 d'armure ou moins).
## "wave", "win" et "clean" acceptent "map" : la condition ne vaut que sur cette carte.
##
## RÈGLE : deux objets n'ont jamais la même condition (ni la même qu'un défi de l'Atelier), et
## les conditions sont réparties sur les 3 cartes (voir tests/itemlocktest).
## v0.8 : "mono6" (vague finie avec 6 armes de la même couleur), "boss_clean" (boss vaincu sans
## perdre de PV), "boss_total" (boss vaincus, toutes parties), "damage" (dégâts infligés, toutes
## parties), "boss_crit" (boss achevé d'un critique), "mono_color" (vague v finie avec un perso
## d'une seule couleur), "spent" (or dépensé, toutes parties), "roulette" (parties gagnées à la
## roulette), "wave_kills" (ennemis tués en une vague), "maps" (vague finie sur v cartes),
## "fast_win" (partie gagnée en moins de v minutes), "legend_buys" (légendaires achetées dans une partie).
## v0.9 : "earned" (or ramassé, toutes parties), "win_pet" (partie gagnée avec un familier),
## "pets" (v familiers en même temps), "pets_wave" (vague v finie avec n familiers).

const CONDS := {
	# --- Armes à ratio : leur stat
	"w:plume": {"kind": "solo", "v": 5},
	"w:rouleau": {"kind": "stat", "stat": "max_hp", "v": 80},
	"w:chevalet_bouclier": {"kind": "stat", "stat": "armor", "v": 15},
	"w:aerographe": {"kind": "stat", "stat": "speed", "v": 40},
	"w:cutter": {"kind": "stat", "stat": "crit", "v": 40},
	"w:compte_gouttes": {"kind": "stat", "stat": "luck", "v": 40},
	"w:pinceau_dore": {"kind": "gold", "v": 150},
	"w:regle": {"kind": "stat", "stat": "range", "v": 50},
	"w:nuancier": {"kind": "colors", "v": 4},
	"w:silhouette": {"kind": "pixels", "v": 450},
	"w:pipette": {"kind": "stat", "stat": "lifesteal", "v": 20},
	# --- Épiques / légendaires
	"w:ciseaux": {"kind": "wave", "v": 6, "map": 3},
	"w:loupe": {"kind": "boss", "boss": "critique"},
	"w:avion": {"kind": "wave", "v": 10, "map": 1},
	"w:eventail": {"kind": "wave", "v": 13, "map": 1},
	"w:crayon_hb": {"kind": "level", "v": 12},
	"w:retouche": {"kind": "win", "v": 1, "map": 1},
	"w:miroir_deformant": {"kind": "boss", "boss": "muse"},
	"w:grande_signature": {"kind": "boss", "boss": "curseur_boss"},
	"w:point_final": {"kind": "boss", "boss": "toile"},
	# --- Amulettes : vol de vie, épines, éléments
	"a:encre_rouge": {"kind": "stat", "stat": "lifesteal", "v": 8},
	"a:encre_carmin": {"kind": "stat", "stat": "lifesteal", "v": 15},
	"a:calice": {"kind": "stat", "stat": "lifesteal", "v": 25},
	"a:chauve_souris": {"kind": "kills", "v": 2000},
	"a:pacte_sang": {"kind": "win", "v": 0, "map": 2},
	"a:carapace": {"kind": "stat", "stat": "armor", "v": 10},
	"a:oursin": {"kind": "stat", "stat": "thorns", "v": 5},
	"a:cactus": {"kind": "stat", "stat": "max_hp", "v": 70},
	"a:ronces": {"kind": "stat", "stat": "thorns", "v": 10},
	"a:herisson": {"kind": "stat", "stat": "thorns", "v": 20},
	"a:allumette": {"kind": "syn", "el": 1, "v": 1},
	"a:braise": {"kind": "syn", "el": 1, "v": 8},
	"a:givre": {"kind": "syn", "el": 2, "v": 1},
	"a:stalactite": {"kind": "syn", "el": 2, "v": 8},
	"a:paratonnerre": {"kind": "syn", "el": 3, "v": 1},
	"a:dynamo": {"kind": "syn", "el": 3, "v": 8},
	"a:fiole": {"kind": "syn", "el": 4, "v": 1},
	"a:champignon": {"kind": "syn", "el": 4, "v": 8},
	"a:grimoire": {"kind": "syn", "el": 5, "v": 1},
	"a:pentacle": {"kind": "syn", "el": 5, "v": 8},
	"a:vitrail": {"kind": "syn", "el": 6, "v": 1},
	"a:aureole": {"kind": "syn", "el": 6, "v": 8},
	"a:cercle_chromatique": {"kind": "colors", "v": 6},
	"a:alchimie": {"kind": "syn2", "v": 2},
	# --- Amulettes : le reste
	"a:spatule": {"kind": "only", "v": 4, "wkind": "melee"},
	"a:viseur": {"kind": "only", "v": 4, "wkind": "ranged"},
	"a:chiffon": {"kind": "wave", "v": 1, "map": 2},
	"a:encre_sympathique": {"kind": "stat", "stat": "luck", "v": 15},
	"a:godet": {"kind": "stat", "stat": "el_power", "v": 20},
	"a:etiquette_prix": {"kind": "gold", "v": 100},
	"a:timbre": {"kind": "stat", "stat": "thorns", "v": 3},
	"a:gommette": {"kind": "level", "v": 6},
	"a:aimant_pepites": {"kind": "boss", "boss": "tableur"},
	"a:crayon_couleur": {"kind": "colors", "v": 3},
	"a:ombre_portee": {"kind": "stat", "stat": "dodge", "v": 30},
	"a:pansement": {"kind": "level", "v": 8},
	"a:cadran_solaire": {"kind": "wave", "v": 9, "map": 3},
	"a:taille_douce": {"kind": "stat", "stat": "armor", "v": 12},
	"a:encre_invisible": {"kind": "elites", "v": 15},
	"a:papier_verre": {"kind": "wave", "v": 6, "map": 1},
	"a:bulle_soin": {"kind": "boss", "boss": "virus"},
	"a:elastique": {"kind": "wave", "v": 7, "map": 3},
	"a:correcteur": {"kind": "wave", "v": 3, "map": 2},
	"a:cachet_cire": {"kind": "elites", "v": 40},
	"a:kaleidoscope": {"kind": "colors", "v": 5},
	"a:lanterne": {"kind": "boss", "boss": "rature"},
	"a:ressort": {"kind": "stat", "stat": "range", "v": 40},
	"a:metronome": {"kind": "stat", "stat": "atk_speed", "v": 50},
	"a:pierre_aiguiser": {"kind": "legends", "v": 2},
	"a:boussole": {"kind": "boss", "boss": "geometre"},
	"a:papillon": {"kind": "stat", "stat": "crit", "v": 50},
	"a:encre_seiche": {"kind": "wave", "v": 8, "map": 2},
	"a:echelle": {"kind": "level", "v": 15},
	"a:accordeon": {"kind": "stat", "stat": "speed", "v": 50},
	"a:bouclier_papier": {"kind": "clean", "v": 10, "map": 1},
	"a:mise_abyme": {"kind": "wave", "v": 12, "map": 3},
	"a:midas": {"kind": "gold", "v": 300},
	"a:palimpseste": {"kind": "level", "v": 20},
	"a:fresque": {"kind": "gallery", "v": 100},
	"a:autographe": {"kind": "boss", "boss": "professeur"},
	"a:nuit_etoilee": {"kind": "win", "v": 1, "map": 3},
	"a:derniere_touche": {"kind": "win", "v": 2},
	# --- v0.8
	"a:accord_parfait": {"kind": "mono6"},
	"a:bache": {"kind": "boss_clean"},
	"a:colle_forte": {"kind": "boss_total", "v": 10},
	"a:grattoir": {"kind": "damage", "v": 100000},
	"a:monocle": {"kind": "boss_crit"},
	"a:pigment_pur": {"kind": "mono_color", "v": 10},
	"a:toile_tendue": {"kind": "boss", "boss": "photocopieuse"},
	"a:carnet_commandes": {"kind": "spent", "v": 1000},
	"a:de_pipe": {"kind": "roulette", "v": 3},
	"a:performance": {"kind": "wave_kills", "v": 150},
	"a:reflet": {"kind": "boss", "boss": "encrier"},
	"a:salle_thematique": {"kind": "maps", "v": 3},
	"a:speed_painting": {"kind": "fast_win", "v": 25},
	"a:vernissage": {"kind": "legend_buys", "v": 3},
	# --- v0.12 : les 18 légendaires, et 8 des 19 communes (les 11 autres sont libres dès le début)
	"a:satellite": {"kind": "amulets", "v": 25},
	"a:talons_aiguilles": {"kind": "stat", "stat": "speed", "v": 60},
	"a:biscuit_gorille": {"kind": "pixels", "v": 600},
	"a:chargeur": {"kind": "stat", "stat": "crit", "v": 60},
	"a:grenade": {"kind": "wave_kills", "v": 200},
	"a:catalyseur": {"kind": "syn2", "v": 3},
	"a:matador": {"kind": "stat", "stat": "dodge", "v": 45},
	"a:bulldozer": {"kind": "stat", "stat": "thorns", "v": 30},
	"a:canon_verre": {"kind": "bare", "v": 8},
	"a:ceinture": {"kind": "clean", "v": 12, "map": 2},
	"a:punching_ball": {"kind": "stat", "stat": "max_hp", "v": 150},
	"a:boisson": {"kind": "stat", "stat": "atk_speed", "v": 80},
	"a:carte_credit": {"kind": "spent", "v": 5000},
	"a:investisseur": {"kind": "gold", "v": 500},
	"a:ticket_entree": {"kind": "runs", "v": 30},
	"a:pellicule": {"kind": "mono_color", "v": 12},
	"a:galerie_musee": {"kind": "legends", "v": 3},
	"a:constellation": {"kind": "win", "v": 3},
	"a:trophee": {"kind": "boss_total", "v": 25},
	"a:avis_recherche": {"kind": "elites", "v": 80},
	"a:combo": {"kind": "kills", "v": 5000},
	"a:sardines": {"kind": "wave_kills", "v": 100},
	"a:coupon": {"kind": "spent", "v": 2500},
	"a:perche_selfie": {"kind": "stat", "stat": "range", "v": 70},
	"a:pouce": {"kind": "clean", "v": 5, "map": 3},
	"a:airbag": {"kind": "runs", "v": 10},
	# --- Familiers : la moitié à débloquer
	"f:pie": {"kind": "earned", "v": 3000},
	"f:pigeon": {"kind": "wave", "v": 3, "map": 1},
	"f:perroquet": {"kind": "win_pet"},
	"f:fantome": {"kind": "boss", "boss": "bug"},
	"f:paon": {"kind": "pets_wave", "v": 10, "n": 3},
	"f:pavel": {"kind": "win", "v": 1, "map": 2},
	"f:teemeo": {"kind": "syn", "el": 4, "v": 12},
	"f:chimere": {"kind": "pets", "v": 5},
}

static var STAT_NAMES := {"max_hp": "PV max", "armor": "d'armure", "speed": "% de vitesse", "crit": "% de critique",
	"luck": "de chance", "range": "% de portée", "lifesteal": "% de vol de vie", "thorns": "d'épines",
	"el_power": "% de puissance élémentaire", "dodge": "% d'esquive", "atk_speed": "% de vitesse d'attaque"}


static func key_weapon(type: String) -> String:
	return "w:" + type


static func key_amulet(id: String) -> String:
	return "a:" + id


static func key_familiar(id: String) -> String:
	return "f:" + id


## Nom lisible d'une clé ("Arme : Plume solitaire").
static func label(key: String) -> String:
	if key.begins_with("w:"):
		return Loc.t("Arme : ") + String(WeaponDB.get_def(key.substr(2)).name)
	if key.begins_with("f:"):
		return Loc.t("Familier : ") + String(FamiliarDB.get_def(key.substr(2)).name)
	return Loc.t("Amulette : ") + String(AmuletDB.get_def(key.substr(2)).name)


## " sur <la carte>" si la condition est liée à une carte, sinon rien.
static func _on(c: Dictionary) -> String:
	return (Loc.t(" sur ") + String(MapDB.MAPS[int(c.map)].name)) if c.has("map") else ""


## La condition vaut-elle sur la carte de ce contexte ? (sans carte dans le contexte : non)
static func _here(c: Dictionary, ctx: Dictionary) -> bool:
	return not c.has("map") or int(ctx.get("map", 0)) == int(c.map)


## Condition en clair (affichée dans le Codex).
static func text(c: Dictionary) -> String:
	match String(c.kind):
		"stat":
			# (« 40 % de vitesse », « 15 d'armure » ; en anglais « 40% speed », « 15 armor »)
			var sn := String(STAT_NAMES.get(c.stat, c.stat))
			if Loc.lang != "fr" and not sn.begins_with("%"):
				sn = " " + sn
			return Loc.t("Atteins %d %s dans une partie.") % [int(c.v), sn]
		"gold":
			return Loc.t("Aie %d or en poche.") % int(c.v)
		"colors":
			return Loc.t("Joue un perso avec %d couleurs différentes.") % int(c.v)
		"pixels":
			return Loc.t("Joue un perso de %d pixels ou plus.") % int(c.v)
		"solo":
			return Loc.t("Termine la vague %d avec une seule arme.") % int(c.v)
		"wave":
			return Loc.t("Termine la vague %d%s.") % [int(c.v), _on(c)]
		"win":
			return Loc.t("Gagne une partie") + _on(c) + (Loc.t(" en %s ou plus dur.") % Meta.DIFFICULTIES[int(c.v)].name if int(c.v) > 0 else ".")
		"only":
			return Loc.t("Termine la vague %d avec uniquement des armes %s.") % [int(c.v), Loc.t("de mêlée") if c.wkind == "melee" else Loc.t("à distance")]
		"kills":
			return Loc.t("Tue %d ennemis (toutes parties).") % int(c.v)
		"elites":
			return Loc.t("Tue %d élites (toutes parties).") % int(c.v)
		"level":
			return Loc.t("Atteins le niveau %d dans une partie.") % int(c.v)
		"boss":
			return Loc.t("Vaincs %s.") % String(EnemyDB.get_def(c.boss).name)
		"runs":
			return Loc.t("Joue %d parties.") % int(c.v)
		"syn":
			var el: String = Pal.NAMES[int(c.el)]
			return (Loc.t("Active la synergie %s (3 armes %s).") % [el, el]) if int(c.v) <= 1 else (Loc.t("Aie la synergie %s active à la vague %d.") % [el, int(c.v)])
		"syn2":
			return Loc.t("Aie %d synergies d'éléments actives en même temps.") % int(c.v)
		"legends":
			return Loc.t("Possède %d armes légendaires en même temps.") % int(c.v)
		"amulets":
			return Loc.t("Possède %d amulettes en même temps.") % int(c.v)
		"bare":
			return Loc.t("Termine la vague %d avec 0 d'armure ou moins.") % int(c.v)
		"clean":
			return Loc.t("Termine une vague %d ou plus%s sans perdre de PV.") % [int(c.v), _on(c)]
		"gallery":
			return Loc.t("Aie %d dessins dans ta galerie.") % int(c.v)
		"mono6":
			return Loc.t("Termine une vague avec 6 armes de la même couleur.")
		"boss_clean":
			return Loc.t("Vaincs un boss sans perdre de PV pendant sa vague.")
		"boss_total":
			return Loc.t("Vaincs %d boss (toutes parties).") % int(c.v)
		"damage":
			return Loc.t("Inflige %d dégâts (toutes parties).") % int(c.v)
		"boss_crit":
			return Loc.t("Achève un boss d'un coup critique.")
		"mono_color":
			return Loc.t("Termine la vague %d avec un perso d'une seule couleur.") % int(c.v)
		"spent":
			return Loc.t("Dépense %d or (toutes parties).") % int(c.v)
		"roulette":
			return Loc.t("Gagne %d fois à la roulette (toutes parties).") % int(c.v)
		"wave_kills":
			return Loc.t("Tue %d ennemis en une seule vague.") % int(c.v)
		"maps":
			return Loc.t("Termine une vague sur %d cartes différentes.") % int(c.v)
		"fast_win":
			return Loc.t("Gagne une partie en moins de %d minutes.") % int(c.v)
		"legend_buys":
			return Loc.t("Achète %d objets légendaires dans une même partie.") % int(c.v)
		"earned":
			return Loc.t("Ramasse %d or (toutes parties).") % int(c.v)
		"win_pet":
			return Loc.t("Gagne une partie avec au moins un familier.")
		"pets":
			return Loc.t("Aie %d familiers en même temps.") % int(c.v)
		"pets_wave":
			return Loc.t("Termine la vague %d avec %d familiers.") % [int(c.v), int(c.n)]
	return "?"


## La condition est-elle remplie ? ctx : voir Run.achievement_ctx() + Meta.check_achievements().
static func met(c: Dictionary, ctx: Dictionary) -> bool:
	match String(c.kind):
		"stat":
			return float((ctx.get("stats", {}) as Dictionary).get(c.stat, 0.0)) >= float(c.v)
		"gold":
			return int(ctx.get("gold", 0)) >= int(c.v)
		"colors":
			return int(ctx.get("colors", 0)) >= int(c.v)
		"pixels":
			return int(ctx.get("pixels", 0)) >= int(c.v)
		"solo":
			return int(ctx.get("cleared", 0)) >= int(c.v) and int(ctx.get("weapons", 99)) <= 1
		"wave":
			return _here(c, ctx) and int(ctx.get("cleared", 0)) >= int(c.v)
		"win":
			return _here(c, ctx) and bool(ctx.get("win", false)) and int(ctx.get("diff", 0)) >= int(c.v)
		"only":
			return int(ctx.get("cleared", 0)) >= int(c.v) and int(ctx.get("weapons", 0)) >= 1 \
				and int(ctx.get("melee" if c.wkind == "melee" else "ranged", 0)) == int(ctx.get("weapons", 0))
		"kills":
			return int(ctx.get("total_kills", 0)) >= int(c.v)
		"elites":
			return int(ctx.get("total_elites", 0)) >= int(c.v)
		"level":
			return int(ctx.get("level", 0)) >= int(c.v)
		"boss":
			return (ctx.get("bosses", {}) as Dictionary).has(c.boss)
		"runs":
			return int(ctx.get("runs", 0)) >= int(c.v)
		"syn":
			return (ctx.get("syn", {}) as Dictionary).has(int(c.el)) and int(ctx.get("cleared", 0)) >= int(c.v) - 1
		"syn2":
			return (ctx.get("syn", {}) as Dictionary).size() >= int(c.v)
		"legends":
			return int(ctx.get("legends", 0)) >= int(c.v)
		"amulets":
			return int(ctx.get("amulets", 0)) >= int(c.v)
		"bare":
			return int(ctx.get("cleared", 0)) >= int(c.v) and ctx.has("stats") and float((ctx.stats as Dictionary).get("armor", 1.0)) <= 0.0
		"clean":
			return _here(c, ctx) and bool(ctx.get("clean", false)) and int(ctx.get("cleared", 0)) >= int(c.v)
		"gallery":
			return int(ctx.get("gallery", 0)) >= int(c.v)
		"mono6":
			return bool(ctx.get("mono6", false))
		"boss_clean":
			return bool(ctx.get("boss_clean", false))
		"boss_total":
			return int((ctx.get("counters", {}) as Dictionary).get("bosses", 0)) >= int(c.v)
		"damage":
			return float((ctx.get("counters", {}) as Dictionary).get("damage", 0.0)) >= float(c.v)
		"boss_crit":
			return bool(ctx.get("boss_crit", false))
		"mono_color":
			return int(ctx.get("colors", 99)) <= 1 and int(ctx.get("cleared", 0)) >= int(c.v)
		"spent":
			return int((ctx.get("counters", {}) as Dictionary).get("gold_spent", 0)) >= int(c.v)
		"roulette":
			return int((ctx.get("counters", {}) as Dictionary).get("roulette_wins", 0)) >= int(c.v)
		"wave_kills":
			return int(ctx.get("wave_kills", 0)) >= int(c.v)
		"maps":
			return int(ctx.get("maps", 0)) >= int(c.v)
		"fast_win":
			return bool(ctx.get("win", false)) and float(ctx.get("play_time", 1e9)) < float(c.v) * 60.0
		"legend_buys":
			return int(ctx.get("legend_buys", 0)) >= int(c.v)
		"earned":
			return int((ctx.get("counters", {}) as Dictionary).get("gold_earned", 0)) >= int(c.v)
		"win_pet":
			return bool(ctx.get("win", false)) and int(ctx.get("pets", 0)) >= 1
		"pets":
			return int(ctx.get("pets", 0)) >= int(c.v)
		"pets_wave":
			return int(ctx.get("pets", 0)) >= int(c.n) and int(ctx.get("cleared", 0)) >= int(c.v)
	return false
