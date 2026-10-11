class_name MapDB
extends RefCounted
## Cartes (lieux d'une partie). Chaque carte a ses propres ennemis, ses boss et son décor.
## La 2e se débloque en gagnant une partie sur la 1re (Esquisse ou plus dur), la 3e en gagnant sur la 2e.

const MAPS := {
	1: {"name": "La Feuille", "floor": "paper",
		"desc": "La page blanche du début : taches, gribouillis, ratures... et la Toile Blanche au bout.",
		"bosses": {5: ["rature"], 10: ["critique", "muse"], 15: ["toile"]}},
	2: {"name": "Le Tableau noir", "floor": "board", "events": true,
		"desc": "Une salle de classe hantée. Punaises, trombones, gommes... et des événements surprises en pleine vague.",
		"unlock": "Gagne une partie sur La Feuille (Esquisse ou plus dur).",
		"bosses": {5: ["professeur"], 10: ["photocopieuse", "geometre"], 15: ["encrier"]}},
	3: {"name": "L'Écran", "floor": "screen", "bugs": true,
		"desc": "Le dessin sur ordinateur : pointeurs, fichiers corrompus, corbeilles... et des BUGS qui frappent en pleine vague.",
		"unlock": "Gagne une partie sur Le Tableau noir (Esquisse ou plus dur).",
		"bosses": {5: ["virus"], 10: ["bug", "tableur"], 15: ["curseur_boss"]}},
}


static func get_def(id: int) -> Dictionary:
	return MAPS.get(id, MAPS[1])


## Boss de chaque vague pour une nouvelle partie sur cette carte (tirés au sort s'il y a le choix).
static func boss_plan(id: int) -> Dictionary:
	var out := {}
	var b: Dictionary = get_def(id).bosses
	for w in b:
		out[w] = (b[w] as Array).pick_random()
	return out
