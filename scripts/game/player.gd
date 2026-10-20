class_name Player
extends Node2D
## Le perso dessiné. Se déplace (ZQSD/WASD/flèches/manette), les armes attaquent toutes seules.

var arena: Arena
var st: Dictionary
var hp := 10.0
var radius := 6.0
var body: Node2D
var sprite: Sprite2D
var mat: ShaderMaterial
var weapons: Array[WeaponNode] = []
var inv := 0.0
var flash := 0.0
var t := 0.0
var moving := false
var max_hp := 10.0          # PV max de la vague (réduits quand la Toile Blanche gomme ton dessin)
var erase_mult := 1.0
var pimg: Image             # image du perso, modifiable (gomme)
var ptex: ImageTexture
var was_hurt := false       # a perdu des PV cette vague (La Joconde)
var god := false            # OUTIL DE DEV : invincible
var invis_t := 0.0          # Encre invisible : les ennemis te perdent de vue
var shadow_ready := false   # Ombre portée : prochain coup ×2 après une esquive
var paper := 0              # Bouclier de papier : coups ignorés restants dans la vague
var shield := 0.0           # Encre carmin : bouclier d'encre (soin en trop)
var shield_cd := 0.0        # Encre carmin : après une casse, pas de recharge pendant SHIELD_CD s
const SHIELD_CD := 4.0
var spike_acc := 0.0        # Hérisson
var vel := Vector2.ZERO     # vitesse actuelle (les boss anticipent tes déplacements)
var sap_t := 0.0            # Élixir de sève
var weak_t := 0.0   # affichage « FAIBLESSE ! »
var poop_t := 0.0           # Pigeon : une fiente sur la tête, on avance moins vite
var size_k := 1.0           # Le Curseur : perso redimensionné (1,8 = énorme, 0,55 = minuscule)
var size_t := 0.0
var size_base := 0.0        # son rayon d'origine
var lag_t := 0.0           # Le Curseur, Chargement : ralenti
var hits_taken := 0         # Pinata : coups reçus pendant la vague
var itch_t := 0.0           # Poil à gratter : vitesse en plus après un coup reçu (s)
var airbag_used := false    # Airbag : une fois par vague
var punch_n := 0            # Punching-ball : coups reçus pendant la vague
var buffet_t := 0.0         # Buffet à volonté : temps depuis le dernier repas
const BUFFET_EVERY := 20.0
var grow := 1.0             # Biscuit pour gorille : le perso est dessiné plus gros
var sprite_c := Vector2.ZERO  # centre du dessin dans son image (l'origine du joueur)
var sand_t := 0.0           # Lag (L'Écran) : dans son aura, on avance au ralenti
var root_t := 0.0           # Lasso (L'Écran) : coincé sur place
var lasso_safe_t := 0.0     # ... puis à l'abri des lassos un moment (pas de prise en boucle)
var yuki_t := 0.0           # Yuki : +30 % de vitesse : régénération boostée restante (s)
var ghost_of: Player        # Reflet : ce perso est le double en miroir de ghost_of


func setup(a: Arena) -> void:
	arena = a
	Run.recompute()   # stats qui dépendent de l'or ou des armes (Cadre doré, Collage)
	st = Run.stats
	max_hp = st.max_hp
	hp = clampf(Run.hp, 1.0, max_hp)   # les PV ne remontent pas entre les vagues
	paper = Run.amulet_count("bouclier_papier")
	radius = st.radius * pow(0.92, Run.amulet_count("regime"))   # Régime : zone de touche plus petite
	hp = minf(max_hp, hp + 3.0 * Run.amulet_count("soda"))        # Soda : 3 PV au début de la vague
	if Run.amulet_count("pouce") > 0:
		inv = maxf(inv, 5.0)                                       # Pouce : 5 s sans pouvoir perdre de PV
	body = Node2D.new()
	add_child(body)
	mat = Gfx.material(Run.char_effect, Run.char_outline)
	pimg = Gfx.padded(Run.build_player_image(Run.show_amulets()))
	ptex = ImageTexture.create_from_image(pimg)
	sprite = Gfx.sprite(ptex, mat)
	grow = minf(2.0, 1.0 + 0.03 * Run.gorilla)
	sprite.centered = false
	# Le centre du dessin (hors amulettes) est l'origine du joueur.
	var r: Rect2i = Run.char_a.rect
	sprite_c = Vector2(r.position) + Vector2(r.size) / 2.0 + Vector2(Run.PAD + 1, Run.PAD + 1)
	_scale_sprite(grow)
	body.add_child(sprite)
	for w in Run.weapons:
		var wn := WeaponNode.new()
		add_child(wn)
		if ghost_of:
			# Reflet : mêmes armes, 40 % des dégâts
			var gw: Dictionary = w.duplicate()
			gw.st = (w.st as Dictionary).duplicate(true)
			gw.st.ghost = 0.4
			wn.setup(self, gw)
		else:
			wn.setup(self, w)
		weapons.append(wn)
	if ghost_of:
		mat.set_shader_parameter("tint", Color(0.7, 0.8, 1.3))


func _draw() -> void:
	if shield > 0.5:
		# Encre carmin : anneau du bouclier d'encre
		draw_arc(Vector2(0, -2), radius + 7.0, 0.0, TAU, 28, Color(0.75, 0.1, 0.2, 0.7), 2.0)
	elif shield_cd > 0.0:
		# bouclier cassé : un arc fin se remplit pendant la recharge
		var k := 1.0 - shield_cd / SHIELD_CD
		draw_arc(Vector2(0, -2), radius + 7.0, -PI / 2.0, -PI / 2.0 + TAU * k, 28, Color(0.75, 0.1, 0.2, 0.35), 1.0)
	draw_set_transform(Vector2(0, radius + 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius + 3, Color(0, 0, 0, 0.18))


func input_dir() -> Vector2:
	var d := Vector2.ZERO
	# Touches physiques : WASD sur QWERTY = ZQSD sur AZERTY
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	var joy := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if joy.length() > 0.25:
		d += joy
	# (la croix de la manette aussi)
	d.x += int(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT))
	d.y += int(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP))
	if arena and arena.stream and arena.stream.flip_t > 0.0:
		d = -d   # Le Stream : « !flip », commandes inversées
	if arena and arena.cam and not arena.cam.ignore_rotation:
		d = -d   # Tête à l'envers (ou bug de L'Écran) : l'écran est retourné, les touches suivent l'écran
	if arena and arena.bugs and arena.bugs.is_on("controls"):
		d = -d   # L'Écran, boss Le Bug : commandes inversées
	return d.limit_length(1.0) if d.length() > 1.0 else d


func tick(delta: float) -> void:
	if ghost_of:
		_ghost_tick(delta)
		return
	weak_t -= delta
	t += delta
	var d := input_dir()
	moving = d.length() > 0.1
	# Flaques d'encre : ralentissent, et les traits frais font mal
	# Correcteur : insensible aux flaques d'encre
	var hz: Array = [1.0, 0.0] if Run.amulet_count("correcteur") > 0 else arena.hazard_effect(position, radius)
	var boost := 1.2 if Run.amulet_count("derniere_touche") > 0 and hp < max_hp * 0.25 else 1.0
	if arena.stream:
		boost *= arena.stream.speed_mult()   # Le Stream : sondage « vitesse »
	if poop_t > 0.0:
		poop_t -= delta
		boost *= 0.55   # Pigeon : beurk
	if lag_t > 0.0:
		lag_t -= delta
		boost *= 0.6    # Le Curseur, Chargement : ton ordi rame
	if not arena.formula.is_empty():
		boost *= float(arena.formula.speed)   # Le Tableur : sa formule s'applique à ta vitesse
	if size_t > 0.0:
		size_t -= delta
		if size_k > 1.0:
			boost *= 0.7   # énorme : lent
		if size_t <= 0.0:
			resize(1.0, 0.0)
	if sand_t > 0.0:
		sand_t -= delta
		boost *= 0.6   # Lag : tout ralentit autour de lui
	lasso_safe_t -= delta
	if root_t > 0.0:
		root_t -= delta
		boost = 0.0   # Lasso : coincé
	if yuki_t > 0.0:
		yuki_t -= delta
		boost *= 1.3   # Yuki
	if itch_t > 0.0:
		itch_t -= delta
		boost *= 1.0 + 0.15 * Run.amulet_count("poil_gratter")   # Poil à gratter
	if arena.theme == "rapide":
		boost *= 1.3   # Salle thématique : tout va plus vite
	var want: Vector2 = d * st.move * hz[0] * boost
	if arena.theme == "glissant":
		vel = vel.lerp(want, minf(1.0, 2.5 * delta))   # Salle thématique : sol glissant
	else:
		vel = want
	position += vel * delta
	if hz[1] > 0.0:
		take_hit(hz[1], 0, null)
	position.x = clampf(position.x, radius, Arena.W - radius)
	position.y = clampf(position.y, radius, Arena.H - radius)
	if absf(d.x) > 0.1:
		body.scale.x = -1.0 if d.x < 0 else 1.0
	# Petite animation de marche
	if moving:
		body.position.y = -absf(sin(t * 12.0)) * 2.0
		body.rotation = sin(t * 12.0) * 0.06
	else:
		body.position.y = lerpf(body.position.y, 0.0, 0.3)
		body.rotation = lerpf(body.rotation, 0.0, 0.3)

	var regen: float = st.regen
	if sap_t > 0.0:
		sap_t -= delta
		regen = maxf(regen * 4.0, regen + 8.0)   # Élixir de sève
	if regen > 0.0:
		heal(regen * 0.12 * delta, false)   # (−40 % par rapport à 0,2)
	# Hérisson : les épines frappent en continu les ennemis collés à toi
	if st.thorns > 0.0 and Run.amulet_count("herisson") > 0:
		spike_acc += delta
		if spike_acc >= 0.5:
			spike_acc = 0.0
			for e in arena.near(position, radius + 8.0):
				e.hurt(st.thorns, false, (e.position - position).normalized() * 30.0)
	if shield > 0.0:
		queue_redraw()
	if shield_cd > 0.0:
		shield_cd -= delta
		queue_redraw()
	inv -= delta
	invis_t -= delta
	# Buffet à volonté : toutes les 20 s, les PV remontent au maximum
	if Run.amulet_count("restauration") > 0:
		buffet_t += delta
		if buffet_t >= BUFFET_EVERY:
			buffet_t = 0.0
			if hp < max_hp:
				arena.float_text(position + Vector2(0, -22), Loc.t("BUFFET ! +%d") % int(max_hp - hp), Pal.GOOD)
				hp = max_hp
				Sfx.play("level")
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
		mat.set_shader_parameter("flash", flash)
	mat.set_shader_parameter("alpha", 0.45 if inv > 0.0 and int(t * 20.0) % 2 == 0 else 1.0)

	for e in arena.near(position, radius + 1.0):
		if e.contact:
			var before := hp
			take_hit(e.dmg, e.element, e)
			if e.power == "vampire" and hp < before:
				e.hp = minf(e.max_hp, e.hp + (before - hp) * 4.0)   # élite vampire
				arena.float_text(e.position + Vector2(0, -16), "+%d" % roundi((before - hp) * 4.0), Color("e03a3a"))
			break
	for w in weapons:
		w.tick(delta)


## Réglage global des dégâts que te font les ennemis, les boss et leurs pièges (0,8 = -20 %).
const ENEMY_DMG_MULT := 0.8


func take_hit(dmg: float, element: int, src: Node) -> void:
	if god or inv > 0.0 or arena.ended:
		return
	dmg *= ENEMY_DMG_MULT
	# Cercle des faiblesses : couleur de l'attaquant contre la couleur principale de ton perso
	var att := element
	if src is Enemy:
		att = (src as Enemy).color
	var wmult := Pal.weakness(att, main_color())
	if wmult != 1.0:
		dmg *= wmult
		if weak_t <= 0.0:
			weak_t = 1.5
			arena.float_text(position + Vector2(0, -26), Loc.t("FAIBLESSE !") if wmult > 1.0 else Loc.t("RÉSISTE"), Pal.BAD if wmult > 1.0 else Pal.DIM)
	if paper > 0:
		# Bouclier de papier : ce coup-là est ignoré
		paper -= 1
		inv = 0.5
		arena.float_text(position + Vector2(0, -14), Loc.t("BOUCLIER !"), Pal.TEXT)
		arena.burst(position, Color.WHITE, 12, 90.0)
		return
	if randf() * 100.0 < st.dodge:
		arena.float_text(position + Vector2(0, -14), Loc.t("ESQUIVE"), Pal.DIM)
		inv = 0.25
		if Run.amulet_count("ombre_portee") > 0:
			shadow_ready = true
		if Run.amulet_count("matador") > 0:
			for wn in weapons:
				if wn.st.kind == "melee":
					wn.cd = 0.0   # Matador : l'esquive déclenche les armes de mêlée
		return
	arena.on_player_hit()   # (Rires en boîte : un vrai coup reçu)
	var d := dmg
	# Sardines : +2 armure par exemplaire quand 5 ennemis ou plus sont proches
	var armor: float = st.armor + (2.0 * Run.amulet_count("sardines") if arena.crowd >= 5 else 0.0)
	if armor >= 0.0:
		d /= 1.0 + armor / 15.0
	else:
		d *= 1.0 - armor / 15.0
	if element > 0:
		d *= 1.0 - st.res[element] / 100.0
	d = maxf(1.0, roundf(d))
	if Run.amulet_count("ceinture") > 0:
		d = minf(d, maxf(1.0, ceilf(max_hp * 0.2)))   # Ceinture de sécurité
	# Encre carmin : le bouclier d'encre absorbe d'abord
	if shield > 0.0:
		var ab := minf(shield, d)
		shield -= ab
		d -= ab
		if shield <= 0.0:
			shield = 0.0
			shield_cd = SHIELD_CD   # il a cassé : pas de nouveau bouclier pendant 4 s
			arena.float_text(position + Vector2(0, -22), Loc.t("BOUCLIER CASSÉ"), Color(0.85, 0.3, 0.35))
		queue_redraw()
		if d < 1.0:
			inv = 0.5
			arena.float_text(position + Vector2(0, -14), Loc.t("ABSORBÉ"), Color(0.85, 0.3, 0.35))
			return
	hp -= d
	was_hurt = true
	# Pinata : 1 or tous les 2 coups reçus, par exemplaire
	hits_taken += 1
	if Run.amulet_count("punching_ball") > 0:
		punch_n += 1
	if hits_taken % 2 == 0:
		Run.gold += Run.amulet_count("pinata")
	if Run.amulet_count("poil_gratter") > 0:
		itch_t = 2.0
	# Airbag : une fois par vague, sous 30 % des PV, repousse les ennemis proches
	if not airbag_used and hp > 0.0 and hp < max_hp * 0.3 and Run.amulet_count("airbag") > 0:
		airbag_used = true
		arena.explosion(position, 70.0, Color(Pal.TEXT, 0.7))
		for o in arena.near(position, 70.0):
			if not o.is_boss:
				o.knock += (o.position - position).normalized() * 420.0
		arena.float_text(position + Vector2(0, -26), Loc.t("AIRBAG !"), Pal.TEXT)
	if arena.stream:
		arena.stream.on_hurt()
	# Statistiques : qui t'a effacé (le dernier coup avant la fin)
	if src is Enemy:
		Run.killer = (src as Enemy).id
	elif arena.last_shot_by != "":
		Run.killer = arena.last_shot_by
	arena.last_shot_by = ""
	# L'Encrier renversé (et son reflet) TACHE ton perso
	if src is Enemy and ((src as Enemy).def.get("beh", "") == "b_ink" or (src as Enemy).reflet_of != null):
		stain()
	if Run.amulet_count("encre_invisible") > 0:
		invis_t = 1.0
	arena.squid_cloud(position)
	arena.player_hurt_fx(position)
	inv = 0.5
	flash = 1.0
	arena.shake(4.0)
	Sfx.play("hurt")
	arena.float_text(position + Vector2(0, -14), "-%d" % int(d), Pal.BAD if element == 0 else Pal.main_color(element))
	if st.thorns > 0.0 and src is Enemy:
		(src as Enemy).hurt(st.thorns, false, Vector2.ZERO)
	# Ronces : l'agresseur est repoussé et empoisonné
	if src is Enemy and Run.amulet_count("ronces") > 0:
		var en := src as Enemy
		en.knock += (en.position - position).normalized() * 260.0
		for k in Run.amulet_count("ronces"):
			en.add_poison()
	# Oursin : 6 épines d'encre tout autour
	if Run.amulet_count("oursin") > 0:
		arena.urchin(position, maxf(4.0, st.thorns * 2.0) * Run.amulet_count("oursin"))
	if hp <= 0.0:
		if Run.amulet_count("renaissance") > 0 and not Run.revived:
			Run.revived = true
			hp = maxf(1.0, roundf(max_hp * 0.5))
			inv = 2.0
			arena.explosion(position, 80.0, Color(Pal.GOOD, 0.9))
			for e in arena.near(position, 80.0):
				e.knock += (e.position - position).normalized() * 220.0
			arena.numbers.add(position + Vector2(0, -26), Loc.t("RENAISSANCE !"), Pal.GOOD, 1.8)
			return
		arena.player_died()


## Recrée les armes (après un changement de Run.weapons en cours de vague).
func rebuild_weapons() -> void:
	for wn in weapons:
		wn.queue_free()
	weapons.clear()
	for w in Run.weapons:
		var wn := WeaponNode.new()
		add_child(wn)
		wn.setup(self, w)
		weapons.append(wn)


## Reflet : suit ton perso en miroir (de l'autre côté de la page), ne prend pas de coups,
## attaque avec ses propres exemplaires de tes armes.
func _ghost_tick(delta: float) -> void:
	t += delta
	var m := ghost_of
	position = Vector2(Arena.W - m.position.x, m.position.y)
	vel = Vector2(-m.vel.x, m.vel.y)
	body.scale.x = -m.body.scale.x
	body.position = m.body.position
	body.rotation = -m.body.rotation
	mat.set_shader_parameter("alpha", 0.6)
	for w in weapons:
		w.tick(delta)


## Redessine le perso (après avoir ajouté / retiré des amulettes en cours de vague).
## Le Curseur te redimensionne : énorme (facile à toucher, lent) ou minuscule (tes coups font
## moins mal, voir Arena.hit_enemy). k = 1 : retour à la normale.
## Agrandit ou rétrécit le dessin AUTOUR DE SON CENTRE (l'image n'est pas centrée sur son nœud : sans
## recaler sa position, un perso agrandi se retrouvait décalé vers le bas et la droite).
func _scale_sprite(k: float) -> void:
	sprite.scale = Vector2(k, k)
	sprite.position = -sprite_c * k


func resize(k: float, dur: float) -> void:
	if size_base <= 0.0:
		size_base = radius
	size_k = k
	size_t = dur
	radius = size_base * k
	_scale_sprite(k * grow)


func refresh_image() -> void:
	pimg = Gfx.padded(Run.build_player_image(Run.show_amulets()))
	ptex = ImageTexture.create_from_image(pimg)
	sprite.texture = ptex


func refresh_max_hp() -> void:
	max_hp = maxf(1.0, roundf(st.max_hp * erase_mult))
	hp = minf(hp, max_hp)


## Taches de l'Encrier renversé : chacune noircit 16 % de ton perso (80 % au plus).
## Au-delà, ta couleur principale devient l'OMBRE... que ses éclats de lumière frappent ×1,5.
var stains := 0
const STAIN_MAX := 5


## Ta couleur dans le cercle des faiblesses (taches comprises).
func main_color() -> int:
	var frac: Array = Run.char_a.get("frac", [])
	if stains <= 0 or frac.is_empty():
		return Pal.color_of(frac)
	var s := minf(0.8, stains * 0.16)
	var f := []
	for e in frac.size():
		f.append(float(frac[e]) * (1.0 - s) + (s if e == 0 else 0.0))
	return Pal.color_of(f)


func stain() -> void:
	if stains >= STAIN_MAX:
		return
	var before := main_color()
	stains += 1
	var w := pimg.get_width()
	var h := pimg.get_height()
	var c := Vector2i(-1, -1)
	for i in 400:
		var q := Vector2i(randi() % w, randi() % h)
		if pimg.get_pixelv(q).a > 0.5:
			c = q
			break
	if c.x >= 0:
		var r := 4
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var q := c + Vector2i(x, y)
				if x * x + y * y <= r * r + randi() % 3 and q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and pimg.get_pixelv(q).a > 0.5:
					pimg.set_pixelv(q, Pal.SHADES[0][0])
		ptex.update(pimg)
	if main_color() == Pal.NOIR and before != Pal.NOIR:
		arena.float_text(position + Vector2(0, -30), Loc.t("TU PASSES À L'OMBRE !"), Pal.BAD)
	else:
		arena.float_text(position + Vector2(0, -22), Loc.t("TACHÉ !"), Pal.DIM)


## Buvard : les taches s'en vont.
func clean() -> void:
	if stains == 0:
		return
	stains = 0
	refresh_image()
	arena.float_text(position + Vector2(0, -22), Loc.t("NETTOYÉ !"), Pal.GOOD)


## La Toile Blanche gomme un morceau de ton dessin : -12% PV max jusqu'à la fin de la vague.
func erase_at(_world: Vector2) -> void:
	var w := pimg.get_width()
	var h := pimg.get_height()
	var c := Vector2i(-1, -1)
	for i in 400:
		var q := Vector2i(randi() % w, randi() % h)
		if pimg.get_pixelv(q).a > 0.5:
			c = q
			break
	if c.x < 0:
		return
	var r := 5
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var q := c + Vector2i(x, y)
			if x * x + y * y <= r * r and q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				pimg.set_pixelv(q, Color(0, 0, 0, 0))
	ptex.update(pimg)
	erase_mult = maxf(0.5, erase_mult - 0.12)
	refresh_max_hp()
	arena.float_text(position + Vector2(0, -22), Loc.t("EFFACÉ !"), Pal.TEXT)
	Sfx.play("explode")


func heal(n: float, show := true, from_steal := false) -> void:
	var before := hp
	# Encre carmin : le soin du vol de vie en trop devient un bouclier (20 % des PV max au plus)
	if from_steal and Run.amulet_count("encre_carmin") > 0:
		var extra := hp + n - max_hp
		if extra > 0.0 and shield_cd <= 0.0:
			shield = minf(shield + extra, max_hp * 0.2 * Run.amulet_count("encre_carmin"))
			queue_redraw()
	hp = minf(max_hp, hp + n)
	if hp > before:
		arena.bat_heal(hp - before)   # Chauve-souris
	if show and hp - before >= 1.0:
		arena.float_text(position + Vector2(0, -14), "+%d" % int(hp - before), Pal.GOOD)
