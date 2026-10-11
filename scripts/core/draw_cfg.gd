class_name DrawCfg
extends RefCounted
## Configurations de l'écran de dessin pour chaque type de dessin.


static func character() -> Dictionary:
	var s := 32 + Meta.canvas_bonus()
	return {"kind": "character", "gallery": "character", "size": Vector2i(s, s), "ink": Meta.base_ink(),
		"title": Loc.t("Dessine ton personnage"),
		"sub": Loc.t("Seuls les contours coûtent de l'encre : remplir l'intérieur est gratuit."),
		"cancel": true, "min": 12}


static func weapon(type: String, rar := 0, cancel := true) -> Dictionary:
	var def := WeaponDB.get_def(type)
	var s: int = def.canvas + Meta.canvas_bonus()
	var kind: String = def.kind
	var sub := Loc.t("Manche à GAUCHE, pointe à DROITE → (c'est elle qui frappe).  %s") % def.desc
	if kind == "ranged":
		sub = Loc.t("Crosse à GAUCHE, canon à DROITE → (les tirs partent de là).  %s") % def.desc
	return {"kind": kind, "wtype": type, "gallery": kind, "size": Vector2i(s, s),
		"ink": roundi(def.ink * WeaponDB.RAR_INK[rar]) + Meta.weapon_ink_bonus(), "rar": rar,
		"title": Loc.t("Dessine ton arme : %s") % def.name, "sub": sub,
		"cancel": cancel, "min": 6}


static func bullet(type: String, weapon_a: Dictionary, weapon_effect: String, rar := 0) -> Dictionary:
	var def := WeaponDB.get_def(type)
	@warning_ignore("integer_division")
	var s: int = def.bcanvas + Meta.canvas_bonus() / 2
	return {"kind": "bullet", "wtype": type, "gallery": "bullet", "size": Vector2i(s, s), "ink": roundi(def.bink * WeaponDB.RAR_INK[rar]) + Meta.bullet_ink_bonus(),
		"weapon_a": weapon_a, "weapon_effect": weapon_effect,
		"title": Loc.t("Dessine les projectiles : %s") % def.name,
		"sub": Loc.t("Chaque morceau séparé = un projectile en plus !"),
		"cancel": false, "min": 1}


static func enemy(id: String) -> Dictionary:
	var def := EnemyDB.get_def(id)
	var boss := def.has("boss")
	var title := Loc.t("Nouvel ennemi : %s") % def.name
	if boss:
		title = (Loc.t("BOSS : %s") if def.boss == 2 else Loc.t("MINI-BOSS : %s")) % def.name
	var sub := ""   # (pas de description des monstres en haut de la toile)
	var min_ink := 0
	if boss:
		# Un boss doit être un vrai chef-d'œuvre : au moins 95% de l'encre.
		min_ink = ceili(def.ink * 0.95)
		sub = Loc.t("Un boss doit utiliser au moins 95%% de l'encre (%d) !") % min_ink
	var cfg := {"kind": "boss" if boss else "enemy", "gallery": "boss" if boss else "enemy",
		"size": Vector2i(def.canvas, def.canvas), "ink": def.ink, "title": title, "sub": sub,
		"cancel": false, "min": 6, "min_ink": min_ink, "random": true}
	_need_color(cfg, id)
	return cfg


## Aquarelle et plus : chaque type d'ennemi a une couleur imposée (elle doit être la couleur dominante,
## comme l'élément de l'ennemi : le noir ne compte pas).
static func _need_color(cfg: Dictionary, id: String) -> void:
	if not Run.active:
		return
	var el := Run.enemy_color(id)
	if el <= 0:
		return
	cfg.need_el = el
	cfg.sub = (Loc.t("COULEUR IMPOSÉE : %s.  %s") % [String(Pal.NAMES[el]).to_upper(), cfg.sub]).strip_edges()


## Un dessin de la galerie peut-il servir sur cette toile ? "" si oui, sinon la raison.
## (L'encre n'en fait pas partie : un dessin trop gourmand peut être pris puis modifié.)
static func gallery_block(cfg: Dictionary, img: Image) -> String:
	var s: Vector2i = cfg.size
	var r := img.get_used_rect()
	if r.size.x > s.x or r.size.y > s.y:
		return Loc.t("Trop grand pour ta toile (%d px, toile %d px)") % [maxi(r.size.x, r.size.y), maxi(s.x, s.y)]
	var lc := Meta.locked_colors(img)
	if not lc.is_empty():
		return Loc.t("Couleurs pas encore débloquées : ") + ", ".join(lc)
	return ""


## "" si le dessin respecte la couleur imposée (cfg.need_el), sinon la raison.
static func color_issue(cfg: Dictionary, img: Image) -> String:
	if not cfg.has("need_el") or img == null:
		return ""
	var el := int(cfg.need_el)
	# (la même règle que l'élément de l'ennemi : sa couleur dominante)
	if int(Analyzer.analyze(img).dominant) != el:
		return Loc.t("Couleur imposée : %s doit être la couleur dominante") % Pal.NAMES[el]
	return ""


## Version élite : on repart du dessin de l'ennemi, sur une toile un peu plus grande, et on AJOUTE.
## base : le dessin de départ (par défaut celui de l'ennemi dans la partie ; le Codex donne le sien).
static func elite(id: String, base: Image = null, base_effect := "", base_outline := false) -> Dictionary:
	var def := EnemyDB.get_def(id)
	var in_run := base == null
	if in_run:
		base = Run.enemy_art[id].image
	var base_cost := Analyzer.ink_cost(base)
	var ink := maxi(roundi(def.ink * 1.4), base_cost + 30)
	var s: int = def.canvas + 8
	var cfg := {"kind": "enemy", "gallery": "enemy", "size": Vector2i(s, s), "ink": ink, "base": base,
		"effect": Run.enemy_art[id].effect if in_run else base_effect,
		"outline": Run.enemy_art[id].get("outline", false) if in_run else base_outline,
		"title": Loc.t("ÉLITE : %s") % def.name,
		"sub": Loc.t("Ajoute au moins 15 d'encre à ton dessin."),
		"cancel": false, "min": 6, "min_ink": base_cost + 15, "random": false}
	if in_run:
		_need_color(cfg, id)
	return cfg


static func eproj(id: String) -> Dictionary:
	var def := EnemyDB.get_def(id)
	return {"kind": "eproj", "gallery": "eproj", "size": Vector2i(12, 12), "ink": 40,
		"title": Loc.t("Dessine les projectiles de : %s") % def.name,
		"sub": "",
		"cancel": false, "min": 1, "random": true}


static func familiar(def: Dictionary) -> Dictionary:
	var s := FamiliarDB.canvas(def)
	return {"kind": "familiar", "gallery": "familiar", "size": Vector2i(s, s), "ink": FamiliarDB.ink(def),
		"def": def, "title": Loc.t("Dessine ton familier : %s") % def.name,
		"sub": String(def.desc),
		"cancel": true, "min": 4}


static func amulet(def: Dictionary) -> Dictionary:
	@warning_ignore("integer_division")
	var s := AmuletDB.canvas(def) + Meta.canvas_bonus() / 2   # Grande toile : +4 px par niveau
	return {"kind": "amulet", "gallery": "amulet", "size": Vector2i(s, s), "ink": AmuletDB.ink(def) + Meta.amulet_ink_bonus(),
		"def": def, "title": Loc.t("Dessine l'amulette : %s") % def.name,
		"sub": AmuletDB.describe(def),
		"cancel": true, "min": 3}


## Marque d'encre dessinée en montant de niveau (petite, ne compte pas dans la taille).
## Plus le bonus est rare, plus la marque peut être grande.
const MARK_INK := [10, 16, 24, 34]
const MARK_SIZE := [14, 16, 20, 24]


static func mark(u: Dictionary) -> Dictionary:
	var s: int = MARK_SIZE[u.rar]
	return {"kind": "mark", "gallery": "mark", "size": Vector2i(s, s), "ink": MARK_INK[u.rar], "upgrade": u,
		"title": Loc.t("Dessine ta marque : %s") % u.text,
		"sub": Loc.t("Tatouage, cicatrice, peinture de guerre... Elle s'ajoute sur ton perso sans compter dans sa taille."),
		"cancel": true, "cancel_label": Loc.t("Passer"), "min": 1, "random": true}
