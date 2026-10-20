class_name EnemyDB
extends RefCounted
## Types d'ennemis. Le comportement est fixe ; le joueur dessine leur apparence.
## Plus le joueur met d'encre dans un ennemi, plus il a de PV... et plus il lâche d'or.
## La couleur dominante du dessin donne son élément à l'ennemi. "map" : carte (1 par défaut).
## Les comportements sont pensés autour du dessin : flaques, traits, règle, compas, gomme...

static var TYPES := {
	"tache": {"name": "Tache", "beh": "hop", "hp": 10.0, "dmg": 3.9, "spd": 58.0, "wave": 1, "weight": 10, "canvas": 24, "ink": 160, "loot": 1,
		"desc": "Avance par bonds et laisse des flaques d'encre qui ralentissent."},
	"gribouille": {"name": "Gribouille", "beh": "scribble", "hp": 8.0, "dmg": 3.9, "spd": 84.0, "wave": 2, "weight": 8, "canvas": 24, "ink": 140, "loot": 1,
		"desc": "Gribouille le sol en zigzag : ses traits d'encre font mal, ne marche pas dessus !"},
	"crachoir": {"name": "Crachoir", "beh": "mortar", "hp": 14.0, "dmg": 5.2, "spd": 45.0, "wave": 3, "weight": 5, "canvas": 24, "ink": 160, "loot": 2, "shoots": true,
		"desc": "Crache des pâtés en cloche là où tu te tiens, puis s'enfonce et réapparaît ailleurs."},
	"belier": {"name": "Bélier", "beh": "ruler", "hp": 22.0, "dmg": 7.8, "spd": 40.0, "wave": 6, "weight": 5, "canvas": 24, "ink": 180, "loot": 2,
		"desc": "Trace une ligne à la règle... puis fonce dessus d'un bord à l'autre de la page."},
	"scinde": {"name": "Scinde", "beh": "mirror", "hp": 26.0, "dmg": 5.2, "spd": 50.0, "wave": 7, "weight": 5, "canvas": 24, "ink": 180, "loot": 2, "shoots": true,
		"desc": "Se place toujours en miroir de toi et te renvoie des reflets. Se divise en deux."},
	"eclaboussure": {"name": "Éclaboussure", "beh": "compass", "hp": 19.0, "dmg": 5.2, "spd": 72.0, "wave": 9, "weight": 5, "canvas": 24, "ink": 160, "loot": 2, "shoots": true,
		"desc": "Trace des cercles au compas, de plus en plus serrés autour de toi, et tire en éventail."},
	"colosse": {"name": "Colosse", "beh": "dvd", "hp": 96.0, "dmg": 10.4, "spd": 26.0, "wave": 11, "weight": 3, "canvas": 32, "ink": 320, "loot": 5,
		"desc": "Gomme géante : s'arrête pour viser (elle clignote), puis FONCE sur toi en ligne droite. Insensible au recul."},
	"pate": {"name": "Pâté", "beh": "mine", "hp": 13.0, "dmg": 15.6, "spd": 96.0, "wave": 13, "weight": 2, "canvas": 24, "ink": 140, "loot": 2,
		"desc": "Tache piégée qui fonce sur toi, de plus en plus vite : arrivée au contact, elle gonfle et explose."},
	# --- Le Tableau noir (carte 2)
	"punaise": {"name": "Punaise", "beh": "pin", "map": 2, "hp": 6.0, "dmg": 4.5, "spd": 110.0, "wave": 1, "weight": 9, "canvas": 20, "ink": 120, "loot": 1,
		"desc": "Vise, fonce sur toi puis reste plantée un instant, pointe en l'air."},
	"craie": {"name": "Craie", "beh": "chalk", "map": 2, "hp": 12.0, "dmg": 4.5, "spd": 50.0, "wave": 2, "weight": 6, "canvas": 24, "ink": 150, "loot": 1, "shoots": true,
		"desc": "Écrit une ligne de projectiles qui restent suspendus au tableau... puis partent tous vers toi."},
	"trombone": {"name": "Trombones", "beh": "clip", "map": 2, "hp": 18.0, "dmg": 5.0, "spd": 62.0, "wave": 3, "weight": 5, "canvas": 24, "ink": 160, "loot": 2,
		"desc": "Arrivent par deux, reliés par un fil qui coupe. Ils tournent autour de toi pour te trancher."},
	"tampon_e": {"name": "Tampon encreur", "beh": "stamp", "map": 2, "hp": 24.0, "dmg": 7.0, "spd": 45.0, "wave": 4, "weight": 5, "canvas": 24, "ink": 170, "loot": 2,
		"desc": "Saute très haut et s'écrase sur un carré marqué au sol. Ne reste pas dessous !"},
	"brouillon": {"name": "Brouillon", "beh": "crumple", "map": 2, "heavy": true, "hp": 70.0, "dmg": 6.0, "spd": 38.0, "wave": 6, "weight": 1, "canvas": 32, "ink": 280, "loot": 4,
		"desc": "TANK. Se froisse deux fois quand il perd de la vie : plus petit, plus rapide, et il crache ses boulettes."},
	"gomme_mie": {"name": "Gomme mie de pain", "beh": "gum", "map": 2, "heavy": true, "hp": 90.0, "dmg": 7.0, "spd": 34.0, "wave": 8, "weight": 1, "canvas": 32, "ink": 300, "loot": 4,
		"desc": "TANK. EFFACE tes projectiles autour d'elle : il faut aller la frapper de près."},
	"equation": {"name": "Équation", "beh": "equation", "map": 2, "heavy": true, "hp": 110.0, "dmg": 8.0, "spd": 24.0, "wave": 11, "weight": 1, "canvas": 40, "ink": 340, "loot": 5,
		"desc": "TANK. Avance lentement et « calcule » : chaque résultat est une nouvelle punaise."},
	# --- Carte 3 : L'Écran
	"curseur": {"name": "Pointeur", "beh": "cursor", "map": 3, "hp": 7.0, "dmg": 4.5, "spd": 105.0, "wave": 1, "weight": 9, "canvas": 20, "ink": 120, "loot": 1,
		"desc": "Fonce en ligne droite, s'arrête net, repart. À l'arrêt, il te CLIQUE parfois dessus : un petit carré s'allume sous toi."},
	"fichier": {"name": "Fichier corrompu", "beh": "corrupt", "map": 3, "hp": 16.0, "dmg": 4.0, "spd": 0.0, "wave": 2, "weight": 4, "canvas": 24, "ink": 150, "loot": 2,
		"desc": "Immobile et inoffensif... mais au bout de 6 s il S'OUVRE et libère 3 à 5 ennemis. Détruis-le avant !"},
	"corbeille": {"name": "Corbeille", "beh": "trash", "map": 3, "hp": 20.0, "dmg": 5.0, "spd": 78.0, "wave": 3, "weight": 5, "canvas": 24, "ink": 160, "loot": 2,
		"desc": "Rôde tout près de toi et AVALE les gouttes d'or qui volent vers toi. Tue-la : elle recrache tout."},
	"pot_peinture": {"name": "Pot de peinture", "beh": "bucket", "map": 3, "hp": 22.0, "dmg": 6.5, "spd": 46.0, "wave": 4, "weight": 5, "canvas": 24, "ink": 170, "loot": 2,
		"desc": "Renverse sa peinture sur toi : la zone s'annonce, se remplit d'un coup, puis brûle et ralentit 3 s."},
	"copier_coller": {"name": "Copier-coller", "beh": "paste", "map": 3, "hp": 26.0, "dmg": 5.0, "spd": 70.0, "wave": 6, "weight": 3, "canvas": 24, "ink": 170, "loot": 2,
		"desc": "Court vers les autres ennemis : quand il en touche un, il en fait une COPIE. À tuer en priorité."},
	"sablier_e": {"name": "Lag", "beh": "hourglass", "map": 3, "heavy": true, "hp": 95.0, "dmg": 7.0, "spd": 30.0, "wave": 8, "weight": 1, "canvas": 32, "ink": 300, "loot": 4,
		"desc": "TANK. Tout RAME autour de lui : toi... et les autres ennemis."},
	"lasso": {"name": "Lasso", "beh": "lasso", "map": 3, "hp": 24.0, "dmg": 6.0, "spd": 62.0, "wave": 9, "weight": 3, "canvas": 24, "ink": 170, "loot": 2,
		"desc": "Trace un contour autour de toi. S'il se referme avant que tu sois sorti, tu es coincé 2 s."},
	"barre": {"name": "Barre de chargement", "beh": "loadbar", "map": 3, "heavy": true, "hp": 120.0, "dmg": 9.0, "spd": 70.0, "wave": 11, "weight": 1, "canvas": 40, "ink": 340, "loot": 5,
		"desc": "TANK. Avance par à-coups et se CHARGE quand elle s'arrête. À 100 %, grosse explosion autour d'elle. La frapper vide sa barre."},
	# Boss
	"rature": {"name": "Le Raturé", "beh": "b_orbit", "boss": 2, "hp": 2400.0, "dmg": 10.4, "spd": 55.0, "wave": 5, "canvas": 96, "ink": 300, "loot": 30, "shoots": true,
		"desc": "Boss (vague 5). Tourne autour de toi en tirant des éventails de 3 projectiles, disparaît et réapparaît près de toi dans un anneau de projectiles."},
	"critique": {"name": "Le Critique", "beh": "b_critique", "boss": 2, "hp": 7000.0, "dmg": 13.0, "spd": 42.0, "wave": 10, "canvas": 120, "ink": 420, "loot": 60, "shoots": true,
		"desc": "Boss (vague 10). Spirales de projectiles et appelle des renforts."},
	"muse": {"name": "La Muse", "beh": "b_hatch", "boss": 2, "hp": 5000.0, "dmg": 12.5, "spd": 60.0, "wave": 10, "canvas": 96, "ink": 340, "loot": 60, "shoots": true,
		"desc": "Boss (vague 10, parfois à la place du Critique). Rature la page : charges en zigzag, hachures (passe entre les lignes), croix sur ta position, gribouillage furieux."},
	"toile": {"name": "La Toile Blanche", "beh": "b_toile", "boss": 2, "hp": 26000.0, "dmg": 19.5, "spd": 50.0, "wave": 15, "canvas": 132, "ink": 560, "loot": 0, "shoots": true,
		"desc": "Boss final (vague 15). Elle veut tout effacer. 3 phases : à 66 % et 33 % de PV elle accélère, fait pleuvoir des gommes et efface les bords de la page (le vide fait mal)."},
	"professeur": {"name": "Le Professeur", "beh": "b_prof", "map": 2, "boss": 2, "hp": 3000.0, "dmg": 11.0, "spd": 48.0, "wave": 5, "canvas": 96, "ink": 300, "loot": 30, "shoots": true,
		"desc": "Boss (vague 5). INTERRO SURPRISE : une question s'affiche, chaque colonne du tableau porte une réponse. Va dans la bonne avant que les autres explosent !"},
	"photocopieuse": {"name": "La Photocopieuse", "beh": "b_copy", "map": 2, "boss": 2, "hp": 6500.0, "dmg": 13.0, "spd": 40.0, "wave": 10, "canvas": 120, "ink": 400, "loot": 60, "shoots": true,
		"desc": "Boss (vague 10). Ses tirs ont une COPIE qui arrive du côté opposé, et son scanner balaie tout l'écran : mets-toi dans une bande non scannée ! Parfois : bourrage papier !"},
	"geometre": {"name": "Le Géomètre", "beh": "b_geo", "map": 2, "boss": 2, "hp": 6500.0, "dmg": 13.0, "spd": 40.0, "wave": 10, "canvas": 120, "ink": 400, "loot": 60,
		"desc": "Boss (vague 10, parfois à la place de la Photocopieuse). Un compas géant : il PLANTE sa pointe et trace des cercles autour de lui. Le trait brûle 3 s : place-toi entre les cercles. Planté, il ne bouge plus et prend +50% de dégâts !"},
	"virus": {"name": "Le Virus", "beh": "b_virus", "map": 3, "boss": 2, "hp": 3000.0, "dmg": 11.0, "spd": 48.0, "wave": 5, "canvas": 96, "ink": 300, "loot": 30, "shoots": true,
		"desc": "Boss (vague 5). Il ouvre des FENÊTRES de pub par-dessus le jeu : ferme-les à la souris (la croix, parfois minuscule ou qui fuit ; les énigmes, elles, n'ont pas de croix : il faut les résoudre (2 au plus à la fois)), sinon tu ne vois plus rien... et chaque fenêtre ouverte te tire dessus. À la manette : 3 touches à presser dans l'ordre."},
	"bug": {"name": "Le Bug", "beh": "b_bug", "map": 3, "boss": 2, "hp": 6500.0, "dmg": 13.0, "spd": 44.0, "wave": 10, "canvas": 120, "ink": 400, "loot": 60, "shoots": true,
		"desc": "Boss (vague 10). Il se TÉLÉPORTE, se DÉDOUBLE en copies qui tirent, et casse les règles du jeu : commandes inversées, écran à l'envers, retour en arrière, barre de vie folle. Chaque bug est annoncé 1 s avant."},
	"tableur": {"name": "Le Tableur", "beh": "b_sheet", "map": 3, "boss": 2, "hp": 6500.0, "dmg": 13.0, "spd": 36.0, "wave": 10, "canvas": 120, "ink": 400, "loot": 60,
		"desc": "Boss (vague 10, parfois à la place du Bug). L'arène devient une GRILLE : des lignes et des colonnes entières s'allument puis explosent. Il applique une FORMULE à tes stats, et fait la SOMME des ennemis d'une colonne pour les fusionner."},
	"curseur_boss": {"name": "Le Curseur", "beh": "b_cursor", "map": 3, "boss": 2, "hp": 18000.0, "dmg": 18.0, "spd": 45.0, "wave": 15, "canvas": 132, "ink": 540, "loot": 0, "shoots": true,
		"desc": "Boss final (vague 15). Une main géante qui MANIPULE tout : il te lance ses ennemis, te tire des FLÈCHES de projectiles, t'attrape pour te jeter à la CORBEILLE (secoue les touches !), sélectionne puis SUPPRIME, te redimensionne, réduit et traîne la fenêtre du jeu, te fait RAMER (CHARGEMENT : une spirale de points, et tu es ralenti)... À 60 % et 25 % de PV, le jeu PLANTE."},
	"encrier": {"name": "L'Encrier renversé", "beh": "b_ink", "map": 2, "boss": 2, "hp": 18000.0, "dmg": 18.0, "spd": 45.0, "wave": 15, "canvas": 132, "ink": 540, "loot": 0, "shoots": true,
		"desc": "Boss final (vague 15). 3 phases : il TACHE ton perso (tu passes à l'Ombre, ramasse les buvards !), puis tire des éclats de LUMIÈRE dans la nuit d'encre, puis se dédouble en taches de Rorschach."},
}


static func get_def(id: String) -> Dictionary:
	return TYPES.get(id, {})


## Ennemis qui apparaissent pour la première fois à cette vague (+ le boss de la partie).
static func on_map(id: String) -> bool:
	return int(TYPES[id].get("map", 1)) == Run.map


static func intro_at(wave: int) -> Array:
	var out := []
	for id in TYPES:
		if on_map(id) and not TYPES[id].has("boss") and TYPES[id].wave == wave:
			out.append(id)
	var b := boss_for(wave)
	if b != "":
		out.append(b)
	return out


## Ennemis normaux disponibles à cette vague.
static func pool(wave: int) -> Array:
	var out := []
	for id in TYPES:
		var d: Dictionary = TYPES[id]
		if on_map(id) and not d.has("boss") and d.wave <= wave:
			out.append(id)
	return out


## Boss de cette vague : tiré au début de la partie (vague 10 = Critique ou Muse).
static func boss_for(wave: int) -> String:
	return Run.boss_plan.get(wave, "")
