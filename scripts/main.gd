extends Node
## Chef d'orchestre : enchaîne les écrans (titre → dessins → vagues → boutique → fin).

var current: Node


func _ready() -> void:
	randomize()
	Meta.ensure_settings_file()
	SteamLink.start()   # (sans Steam : ne fait rien, le jeu marche pareil)
	_choose_slot()


func _swap(n: Node) -> void:
	if current:
		current.queue_free()
	current = n
	add_child(n)
	# Musique : vagues / entre les vagues (partie en cours) / menus
	Sfx.music("vague" if n is Arena else ("transition" if Run.active else "menu"))
	# Les écrans sont posés sous un Node : sans taille explicite ils font 0×0, et leurs
	# voiles / fenêtres (conseils, confirmations...) ne bloqueraient pas les clics.
	if n is Control:
		(n as Control).position = Vector2.ZERO
		(n as Control).size = get_viewport().get_visible_rect().size


## Échap sur un écran qui n'a pas de « retour » (choix de niveau, pose d'objet, dessin obligatoire...) :
## on ouvre les options par-dessus. (Pendant les vagues, Échap = pause.)
var _esc_panel: Control


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE):
		return
	if current == null or current is Arena or get_tree().paused:
		return
	if is_instance_valid(_esc_panel):
		return
	var op := OptionsPanel.new()
	_esc_panel = op
	current.add_child(op)
	op.done.connect(func(_r):
		op.queue_free()
		Engine.time_scale = 1.0)
	get_viewport().set_input_as_handled()


## Affiche un écran et attend son signal done(result).
func _ask(n: Node):
	_swap(n)
	return await n.done


func _paint(cfg: Dictionary):
	return await _ask(DrawScreen.new(cfg))


# ------------------------------------------------------------------ Menus

## Choix de la sauvegarde (au lancement, ou depuis le titre).
func _choose_slot() -> void:
	while true:
		var r = await _ask(ChoiceScreens.slots())
		match r.a:
			"play":
				Meta.select_slot(r.n)
				break
			"delete":
				var ok = await _ask(ChoiceScreens.confirm(Loc.t("Supprimer la sauvegarde %d ?") % r.n,
					Loc.t("Progression, pigments, galerie, Codex et partie en cours seront effacés. Impossible de revenir en arrière."),
					Loc.t("Supprimer"), Loc.t("Annuler"), true))
				if ok:
					Meta.delete_slot(r.n)
			"quit":
				var sure = await _ask(ChoiceScreens.confirm(Loc.t("Quitter le jeu ?"), Loc.t("À bientôt !"), Loc.t("Quitter"), Loc.t("Rester")))
				if sure:
					get_tree().quit()
					return
	_title()


func _title() -> void:
	Run.active = false
	SteamLink.sync()   # (retour au menu, changement de sauvegarde : succès et compteurs à jour)
	# Plus de partie en cours (nouvelle partie annulée avant la 1re vague) : rien ne doit rester en attente
	if not Meta.has_run():
		Meta.apply_pending_unlocks()
	var r = await _ask(TitleScreen.new())
	match r:
		"play":
			if Meta.has_run():
				var ok = await _ask(ChoiceScreens.confirm(Loc.t("Nouvelle partie ?"),
					Loc.t("Ta partie en cours sera perdue (elle ne comptera pas comme une défaite)."), Loc.t("Nouvelle partie"), Loc.t("Annuler")))
				if not ok:
					_title()
					return
				Meta.clear_run()
				# La partie abandonnée compte comme finie pour les succès qu'elle a rapportés
				var got := Meta.apply_pending_unlocks()
				if not got.is_empty():
					await _ask(ChoiceScreens.unlock_recap(got))
			_new_run()
		"resume":
			_resume()
		"slots":
			_choose_slot()
		"atelier":
			await _ask(AtelierScreen.new())
			_title()
		"gallery":
			await _ask(GalleryScreen.new())
			_title()
		"options":
			var opts := OptionsPanel.new()
			opts.from_title = true
			await _ask(opts)
			_title()
		"codex":
			await _codex()
			_title()
		"stats":
			await _ask(StatsScreen.new())
			_title()
		"quit":
			get_tree().quit()


func _new_run() -> void:
	var map := 1
	if Meta.map_unlocked(2):
		var m = await _ask(ChoiceScreens.map_choice())
		if m == null:
			_title()
			return
		map = int(m)
	var d = await _ask(ChoiceScreens.difficulty(map))
	if d == null:
		_title()
		return
	if d is Dictionary:
		# Partie avec seed (code partagé) : sa carte et sa difficulté, et rien ne se débloque
		Run.start(int(d.diff), int(d.map), int(d.seed))
	else:
		Run.start(d, map)
	var r = await _obtain("perso", DrawCfg.character(), 0, Loc.t("TON DERNIER PERSO"))
	if r == null:
		_title()
		return
	Run.set_character(r.image, r.effect, r.outline)
	Run.rseed("start")
	var wk := ChoiceScreens.weapon_kind()   # (les 3 armes proposées suivent la seed)
	Run.unseed()
	var type = await _ask(wk)
	await _get_weapon(type, 0, 0, false)
	Run.log_event("buy", Loc.t("Arme de départ : ") + Run.item_label("weapon", type, 0))
	_game_loop()


## Obtenir une arme. Chaque RARETÉ a son propre dessin (et sa propre encre), puis on la pose
## sur le perso. Retourne false si annulé.
func _get_weapon(type: String, rar: int, price: int, cancel := true) -> bool:
	if not Run.has_art(type, rar):
		if not await _draw_rarity(type, rar, cancel):
			return false
	var p = await _ask(ArrangeScreen.new(type, rar))
	Run.apply_weapon_moves(p.moves)
	Run.apply_amulet_moves(p.get("amulet_moves", []))
	Run.add_weapon(type, rar, price, p.new.anchor, p.new.rot, p.new.flip)
	return true


## Dessin d'une rareté pas encore dessinée dans la partie (achat ou fusion) :
## - le Codex a un dessin pour CETTE rareté, ou le type n'a encore aucun dessin dans la
##   partie : sélection (utiliser / modifier / nouveau) ;
## - sinon : on retouche le dessin d'une autre rareté avec l'encre de celle-ci.
func _draw_rarity(type: String, rar: int, cancel: bool) -> bool:
	var key := Run.weapon_key(type, rar)
	var base := Run.closest_art(type, rar)
	if not base.is_empty() and Meta.bestiary_get(key) == null:
		return await _retouch_rarity(type, rar, base, cancel)
	var def := WeaponDB.get_def(type)
	var wcfg := DrawCfg.weapon(type, rar, cancel)
	# (les balles se dessinent juste après seulement pour un type jamais dessiné de la partie)
	wcfg.bullets_next = base.is_empty() and def.kind == "ranged" and not def.get("nobullet", false)
	var r = await _obtain(key, wcfg, 0, Loc.t("TON ARME %s") % Pal.RARITY_NAMES_F[rar].to_upper())
	if r == null:
		return false
	var bullet: Image = null
	var beffect := ""
	var boutline := false
	if not base.is_empty():
		# Les balles sont les mêmes pour toutes les raretés du type
		bullet = base.bullet
		beffect = base.beffect
		boutline = base.get("boutline", false)
	elif def.kind == "ranged" and not def.get("nobullet", false):
		var bb = await _obtain("balle_" + type, DrawCfg.bullet(type, Analyzer.analyze(r.image), r.effect, rar), 0, Loc.t("TES DERNIÈRES BALLES"))
		bullet = bb.image
		beffect = bb.effect
		boutline = bb.outline
	Run.set_weapon_art(type, rar, r.image, r.effect, bullet, beffect, r.outline, boutline)
	return true


## Nouvelle rareté d'un type déjà dessiné : on retouche le dessin existant avec l'encre de
## cette rareté. Les exemplaires des autres raretés gardent leur dessin.
## cancel = false (fusion) : pas de retour possible, il faut valider un dessin. Retourne false si annulé.
func _retouch_rarity(type: String, rar: int, base: Dictionary, cancel := true) -> bool:
	var def := WeaponDB.get_def(type)
	var cfg := DrawCfg.weapon(type, rar, true)
	cfg.ink = maxi(int(cfg.ink), Analyzer.ink_cost(base.image))
	cfg.base = base.image
	cfg.effect = base.effect
	cfg.outline = base.outline
	if base.get("bullet") != null:
		cfg.bullet_a = Analyzer.analyze(base.bullet)   # couleur finale = arme + balles
	cfg.random = false
	cfg.title = Loc.t("%s %s : retouche ton dessin") % [def.name, Pal.RARITY_NAMES_F[rar].to_lower()]
	cfg.sub = Loc.t("Cette rareté a son propre dessin (%d d'encre). Tes armes des autres raretés gardent le leur.") % int(cfg.ink)
	cfg.cancel = cancel
	cfg.cancel_label = Loc.t("Retour")
	var r = await _paint(cfg)
	if r == null:
		return false
	Run.set_weapon_art(type, rar, r.image, r.effect, base.bullet, base.beffect, r.outline, base.boutline)
	# Premier dessin de cette rareté : il devient son dessin par défaut dans le Codex
	await _remember(Run.weapon_key(type, rar), Meta.bestiary_get(Run.weapon_key(type, rar)), r)
	return true


## Obtenir une amulette : dessin (une seule fois par partie) puis pose avec rotation / miroir.
## Familier : on le dessine (ou on reprend son dessin de base), puis il rejoint la partie.
func _get_familiar(id: String) -> bool:
	var def := FamiliarDB.get_def(id)
	if not Run.familiar_art.has(id):
		var r = await _obtain("familier_" + id, DrawCfg.familiar(def), 0, Loc.t("TON FAMILIER"))
		if r == null:
			return false
		Run.set_familiar_art(id, r.image, r.effect, r.outline)
	Run.add_familiar(id)
	return true


## cancel = false (Restaurateur) : pas de retour possible, il faut dessiner et poser l'amulette.
func _get_amulet(id: String, cancel := true) -> bool:
	var def := AmuletDB.get_def(id)
	if not Run.amulet_art.has(id):
		var cfg := DrawCfg.amulet(def)
		cfg.cancel = cancel
		var r = await _obtain("amulette_" + id, cfg, 0, Loc.t("TA DERNIÈRE AMULETTE"))
		if r == null:
			return false
		Run.set_amulet_art(id, r.image, r.effect, r.outline)
	var p = await _ask(PlaceScreen.new("amulet", Run.amulet_art[id].image, def, Run.amulet_art[id].outline))
	Run.apply_amulet_moves(p.get("moves", []))   # amulettes déjà posées, éventuellement décalées
	Run.add_amulet(id, p.image, p.pos)
	if id == "oculiste" and Run.oculist_ok < 0:
		# Lunettes de l'oculiste : le test de vision, tout de suite
		var ok = await _ask(OculistTest.new())
		Run.oculist_ok = 1 if ok else 0
		Run.log_event("event", Loc.t("Test de vision : %s") % (Loc.t("réussi") if ok else Loc.t("raté")))
		Run.recompute()
	return true


## Effets à l'achat. Boîte de Pandore : ni dessin ni pose, elle disparaît aussitôt ("consume").
## Le Diplôme : même effet immédiat, mais l'amulette reste ("on_buy", appelé après la pose).
func _consume(id: String) -> bool:
	match id:
		"pandore":
			var ch := Run.open_pandora()
			if ch.is_empty():
				return false
			Sfx.play("level")
			for c in ch:
				Run.log_event("event", Loc.t("Boîte de Pandore : %s → %s") % c)
			if Run.amulet_count("oculiste") > 0 and Run.oculist_ok < 0:
				var ok = await _ask(OculistTest.new())
				Run.oculist_ok = 1 if ok else 0
				Run.recompute()
			await _ask(ChoiceScreens.info(Loc.t("BOÎTE DE PANDORE"), "\n".join(ch.map(func(c): return "%s  →  %s" % c))))
			return true
		"diplome":
			var idx := []
			for i in Run.weapons.size():
				if int(Run.weapons[i].rar) < 3:
					idx.append(i)
			if idx.is_empty():
				return false
			var i: int = idx.pick_random()
			var w: Dictionary = Run.weapons[i]
			Run.log_event("event", Loc.t("Diplôme : %s → %s") % [Run.item_label("weapon", w.type, int(w.rar)), Pal.RARITY_NAMES_F[int(w.rar) + 1].to_lower()])
			await _upgrade_weapon(i)
			Run.recompute()
			return true
	return false


# ------------------------------------------------------------------ Partie

## Reprend la partie sauvegardée de la sauvegarde active.
func _resume() -> void:
	var d := Meta.read_run()
	if not Run.from_save(d):
		Meta.clear_run()
		_title()
		return
	# Écran de reprise : ton perso, tes stats, ton journal... et tu choisis de reprendre ou non
	var go = await _ask(RunLogScreen.new("resume"))
	if not go:
		Run.active = false
		_title()
		return
	_game_loop(String(d.stage), int(d.wave))


## Point de sauvegarde automatique (reprise possible après avoir quitté le jeu).
func _checkpoint(stage: String) -> void:
	Meta.check_achievements(Run.achievement_ctx())
	Meta.save_run(Run.to_save(stage))


## stage "wave" : la vague `start` commence ; "after" : elle est finie (niveaux + boutique).
func _game_loop(stage := "wave", start := 1) -> void:
	var w := start
	while w <= Run.WAVES or Run.endless:
		if not (w == start and stage == "after"):
			Run.wave = w
			Run.plan_endless_boss(w)
			await _pre_wave(w)
			_checkpoint("wave")
			var res = await _ask(Arena.new())
			if res == "suspend":
				_title()   # la partie reprendra au début de cette vague
				return
			if res != "cleared":
				Run.log_event("wave", Loc.t("Effacé à la vague %d") % w)
				if Run.endless:
					await _end_endless()
				else:
					await _end(false)
				return
			Run.log_event("wave", Loc.t("Vague %d terminée (PV %d / %d, ● %d)") % [w, ceili(Run.hp), int(Run.stats.max_hp), Run.gold])
			# Outil de dev : saut direct à une vague (sans niveaux ni boutique)
			if Run.dev_jump > 0:
				w = Run.dev_jump
				Run.dev_jump = 0
				stage = "wave"
				continue
			if w == Run.WAVES and not Run.endless:
				# Victoire : on la compte tout de suite ; le joueur peut continuer en mode infini
				if not await _end(true, true):
					return
				Run.log_event("wave", Loc.t("Mode infini : la partie continue !"))
			Run.shop_offers = []
			_checkpoint("after")
		await _level_ups()
		if await _shop():
			_title()
			return
		w += 1


## Premier contact avec un nouvel ennemi ou boss : on reprend le dessin du carnet
## (ou un de la galerie), ou on le dessine. Les projectiles ennemis sont automatiques.
func _pre_wave(w: int) -> void:
	var ids := []
	for k in range(1, w + 1):   # (toutes les vagues jusqu'ici : utile si l'outil de dev en a sauté)
		for id in EnemyDB.intro_at(k):
			if k == w or not EnemyDB.get_def(id).has("boss"):
				ids.append(id)
	for id in ids:
		if Run.enemy_art.has(id):
			continue
		var def := EnemyDB.get_def(id)
		var art = await _obtain(id, DrawCfg.enemy(id), 5 if def.has("boss") else 2)
		Run.set_enemy_art(id, art.image, art.effect, art.outline)
		if def.get("shoots", false):
			Run.auto_eproj(id)
	# Difficultés hautes : une version élite par vague
	if Run.difficulty >= 1 and w >= 4 and EnemyDB.boss_for(w) == "":   # élites dès Croquis
		for id in EnemyDB.pool(w):
			if Run.enemy_art.has(id) and not Run.elite_art.has(id):
				# Comme pour les armes : un dessin d'élite dans le Codex -> choix (le reprendre, le
				# modifier, en faire un nouveau) ; sinon on complète directement le dessin de l'ennemi.
				var art
				if Meta.bestiary_get(id + "_elite") != null:
					art = await _obtain(id + "_elite", DrawCfg.elite(id))
				else:
					art = await _paint(DrawCfg.elite(id))
					await _remember(id + "_elite", null, art)
				if art != null:
					Run.set_elite_art(id, art.image, art.effect, art.outline)
				break


## Pour TOUT ce qui se dessine (seulement la 1re fois dans la partie) : on propose d'abord le
## dessin par défaut du Codex, ou un dessin compatible de la galerie, ou de dessiner.
## « < Choix » dans l'écran de dessin ramène à cette sélection.
## Retourne {image, effect, outline}, ou null si le joueur annule (quand c'est permis).
func _obtain(key: String, cfg: Dictionary, reward := 0, caption := Loc.t("TON DESSIN DE BASE")):
	var existing = Meta.bestiary_get(key)
	if existing != null:
		caption = Loc.t("TON DESSIN DE BASE")
	while true:
		var r = await _ask(BestiaryPrompt.new(cfg, existing, reward, caption))
		match r.a:
			"cancel":
				return null
			"keep":
				await _remember(key, existing, r)
				return {"image": r.image, "effect": r.effect, "outline": r.outline}
		var c: Dictionary = cfg.duplicate()
		c.cancel = true
		c.cancel_label = Loc.t("< Choix")
		c.outline = r.get("outline", false)
		if r.a == "redraw":
			c.base = r.image
			c.effect = r.effect
			c.random = false
		var d = await _paint(c)
		if d == null:
			continue   # retour à la sélection
		# Pigments seulement si on fait évoluer le dessin de son carnet (pas un dessin de galerie)
		if reward > 0 and r.a == "redraw" and r.get("from_carnet", false) and d.image.get_data() != r.image.get_data():
			Meta.add_pigments(reward)
		await _remember(key, existing, d)
		return {"image": d.image, "effect": d.effect, "outline": d.outline}


## Le dessin choisi ou dessiné en partie devient TOUJOURS le dessin par défaut (le perso, les armes,
## les balles... reprennent le dernier sélectionné la fois suivante).
func _remember(key: String, existing, r: Dictionary) -> void:
	if existing != null and (existing.image as Image).get_data() == (r.image as Image).get_data() 			and existing.effect == r.effect and existing.outline == r.outline:
		return   # déjà le même
	Meta.bestiary_set(key, r.image, r.effect, r.outline)


## Codex : régler le dessin par défaut de chaque arme / amulette / ennemi.
func _codex() -> void:
	var tab := "armes"
	var sel := ""
	while true:
		var r = await _ask(CodexScreen.new(tab, sel))
		if r == null:
			return
		tab = r.tab
		sel = r.sel
		var c: Dictionary = r.cfg.duplicate()
		var d0 = Meta.bestiary_get(r.key)
		if d0 != null:
			c.base = d0.image
			c.effect = d0.effect
			c.outline = d0.outline
		c.cancel = true
		c.cancel_label = Loc.t("Retour")
		c.random = c.get("random", false) and d0 == null
		var d = await _paint(c)
		if d != null:
			Meta.bestiary_set(r.key, d.image, d.effect, d.outline)


## Pour chaque niveau gagné : 1 bonus parmi 3 (plus de dessin de marque).
func _level_ups() -> void:
	while Run.pending_levels > 0:
		# Les 3 choix sont tirés AVANT la sauvegarde : quitter / reprendre ne les relance pas
		if Run.levelup_choices.is_empty():
			Run.levelup_choices = Run.roll_upgrades()
		_checkpoint("after")
		var u = await _ask(LevelUpScreen.new())
		Run.levelup_choices = []
		Run.pending_levels -= 1
		Run.apply_upgrade(u)
		_checkpoint("after")


## Boutique. Retourne true si le joueur a choisi « Sauvegarder et quitter ».
func _shop() -> bool:
	if Run.shop_offers.is_empty():
		Run.new_shop()
	while true:
		_checkpoint("after")
		var r = await _ask(ShopScreen.new())
		match r.a:
			"next":
				return false
			"suspend":
				return true
			"buy":
				await _buy(r.i)
			"fuse":
				await _fuse(r.type, r.rar)
			"arrange":
				var p = await _ask(ArrangeScreen.new("", 0))
				Run.apply_weapon_moves(p.moves)
				Run.apply_amulet_moves(p.get("amulet_moves", []))
			"ink":
				await _ink_pot(r.i)
	return false


func _buy(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if o.sold or Run.cash() < o.price:
		return
	Run.spend(o.price)
	var ok := false
	if o.type == "weapon":
		var m := Run.fusion_match(o.wtype, o.rar)
		if Run.weapons.size() >= Run.max_weapons() and m >= 0:
			# Plus de place : l'arme achetée fusionne directement avec son double
			Run.weapons[m].price = int(Run.weapons[m].price) + o.price
			await _upgrade_weapon(m)
			ok = true
		else:
			ok = Run.weapons.size() < Run.max_weapons() and await _get_weapon(o.wtype, o.rar, o.price)
	elif o.type == "familiar":
		ok = await _get_familiar(o.id)
	elif AmuletDB.get_def(o.id).get("consume", false):
		ok = await _consume(o.id)
	elif o.has("replace"):
		# Restaurateur : l'amulette donnée part tout de suite (sa place se libère pour la nouvelle),
		# puis la nouvelle se dessine et se pose, sans retour possible
		for k in Run.amulets.size():
			var am: Dictionary = Run.amulets[k]
			if am.id == o.replace.id and Vector2i(am.pos) == Vector2i(o.replace.pos):
				Run.amulets.remove_at(k)
				break
		Run.recompute()
		ok = await _get_amulet(o.id, false)
	else:
		ok = await _get_amulet(o.id)
		# Le Diplôme : une fois dessiné et posé, son effet d'achat (si le joueur annule le dessin, rien ne se passe)
		if ok and AmuletDB.get_def(o.id).get("on_buy", false):
			await _consume(o.id)
	if not ok:
		Run.refund(o.price)
		return
	o.sold = true
	if int(o.rar) == 3:
		Run.legend_buys += 1   # succès Vernissage
	var what := Run.item_label(o.type, o.wtype if o.type == "weapon" else o.id, int(o.rar))
	if o.has("replace"):
		Run.log_event("event", Loc.t("Restaurateur : %s → %s (● %d)") % [AmuletDB.get_def(o.replace.id).name, what, o.price])
	elif o.get("gift", false):
		Run.log_event("event", Loc.t("Obtenu : %s%s") % [what, (" (● %d)" % o.price) if o.price > 0 else ""])
	else:
		Run.log_event("buy", Loc.t("Achat : %s (● %d)") % [what, o.price])
	if o.type == "amulet" and o.id in ["capital", "de_pipe"]:
		# Le Capital ou le Dé pipé vient d'être acheté : les prix changent tout de suite (prix moyen,
		# puis tirés au dé). Les autres achats ne touchent plus aux prix (le dé garde son tirage).
		Run.apply_capital()
		Run.roll_dice_prices()
	Run.recompute()


## Pot d'encre : on retouche le perso avec de l'encre en plus, puis on range armes et amulettes.
func _ink_pot(i: int) -> void:
	var o: Dictionary = Run.shop_offers[i]
	if o.sold or Run.cash() < o.price:
		return
	var add := int(Run.HEALS[o.id].ink)
	var cfg := DrawCfg.character()
	cfg.base = Run.character
	# Pile +40 : l'encre déjà utilisée par le perso + le pot (l'encre restante ne s'ajoute pas)
	var need := Analyzer.ink_cost(Run.character) + add
	var budget := need
	if Run.char_effect != "":
		# l'effet du perso coûte une part de l'encre : on l'ajoute pour qu'il ne grignote pas le pot
		while budget - ceili(budget * Stats.EFFECT_COST) < need:
			budget += 1
	cfg.ink = budget
	cfg.effect = Run.char_effect
	cfg.outline = Run.char_outline
	cfg.title = Loc.t("Retouche ton perso (+%d d'encre)") % add
	cfg.sub = Loc.t("Ajoute (ou gomme) ce que tu veux : tes stats changent. Ensuite, replace tes armes et amulettes.")
	cfg.cancel = true
	cfg.cancel_label = Loc.t("Annuler")
	var r = await _paint(cfg)
	if r == null:
		return   # rien payé
	Run.spend(o.price)
	o.sold = true
	Run.char_ink_bonus += add
	Run.set_character(r.image, r.effect, r.outline)
	Run.log_event("buy", Loc.t("Pot d'encre : perso retouché (+%d d'encre, ● %d)") % [add, o.price])
	var p = await _ask(ArrangeScreen.new("", 0))
	Run.apply_weapon_moves(p.moves)
	Run.apply_amulet_moves(p.get("amulet_moves", []))


## Fusion : 2 exemplaires du même type et de même rareté -> 1 exemplaire de rareté +1.
func _fuse(type: String, rar: int) -> void:
	var idx := []
	for i in Run.weapons.size():
		if Run.weapons[i].type == type and Run.weapons[i].rar == rar:
			idx.append(i)
	if idx.size() < 2 or rar >= 3:
		return
	Run.log_event("buy", Loc.t("Fusion : 2× %s → %s") % [Run.item_label("weapon", type, rar), Pal.RARITY_NAMES_F[rar + 1].to_lower()])
	var gone: Dictionary = Run.weapons[idx[1]]
	Run.weapons[idx[0]].price = int(Run.weapons[idx[0]].price) + int(gone.price)
	Run.weapons.remove_at(idx[1])
	await _upgrade_weapon(idx[0])


## Monte une arme d'une rareté. Si cette rareté n'a pas encore de dessin, on repart du dessin
## actuel avec de l'encre en plus pour l'agrandir (« Garder » = même dessin).
## Les exemplaires de la rareté d'avant gardent leur dessin.
func _upgrade_weapon(i: int) -> void:
	var w: Dictionary = Run.weapons[i]
	var old: int = w.rar
	if old >= 3:
		return
	Sfx.play("level")
	if not Run.has_art(w.type, old + 1):
		await _draw_rarity(w.type, old + 1, false)
	w.rar = old + 1
	Run.rebuild_weapon(w)


## Fin de partie. can_endless : victoire, avec le choix de continuer en mode infini.
## Retourne true si le joueur continue en infini (la partie reste active).
func _end(win: bool, can_endless := false) -> bool:
	Meta.clear_run()
	var earned := 0 if Run.seeded else Run.pigments_earned(win)
	var new_map := 0
	if not Run.seeded:   # partie avec seed : ni pigments, ni record, ni déblocage
		new_map = Meta.record_run(Run.wave, win, Run.difficulty, earned, Run.kills, Run.map)
	var unlocked := Meta.apply_pending_unlocks()
	if new_map > 0:
		unlocked.push_front("map:%d" % new_map)
	Run.active = false
	Sfx.play("win" if win else "lose")
	var r = await _ask(ChoiceScreens.end_run(win, earned, unlocked, can_endless))
	if r is String and r == "endless":
		Run.active = true
		Run.endless = true
		Run.endless_base = {"kills": Run.kills, "elites": Run.elite_kills, "pigments": earned, "bosses": Run.bosses, "time": Run.play_time}
		return true
	if r is String and r == "atelier":
		await _ask(AtelierScreen.new())   # (bouton « Atelier » de l'écran de fin)
	_title()
	return false


## Fin d'une partie en mode infini : on ne compte que ce qui a été fait après la victoire.
func _end_endless() -> void:
	Meta.clear_run()
	var b: Dictionary = Run.endless_base
	var earned := 0 if Run.seeded else Run.pigments_endless()
	if not Run.seeded:
		Meta.record_endless(Run.wave, earned, Run.kills - int(b.get("kills", 0)), Run.elite_kills - int(b.get("elites", 0)))
	var unlocked := Meta.apply_pending_unlocks()
	Run.active = false
	Sfx.play("lose")
	var r = await _ask(ChoiceScreens.end_run(false, earned, unlocked))
	if r is String and r == "atelier":
		await _ask(AtelierScreen.new())
	_title()
