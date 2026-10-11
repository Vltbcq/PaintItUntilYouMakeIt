class_name StreamLive
extends Control
## Amulette « Le Stream » : un faux tchat de stream à droite de l'écran pendant les vagues.
## - Il réagit à ce que tu fais (éliminations en série, coups reçus, PV bas, boss, élites...).
## - HYPE : chaque élimination remplit la jauge (elle redescend toute seule) ; pleine = HYPE TRAIN :
##   +30 % de dégâts et de vitesse d'attaque pendant 8 s.
## - SONDAGE toutes les ~20 s : 2 choix, le tchat vote (5 s), le gagnant s'applique.
## - ABONNEMENTS : de temps en temps, de l'or (plus souvent quand la hype est haute).
## - TROLLS : parfois « !shake » (l'écran tremble) ou « !flip » (commandes inversées 2 s).
## Les effets sont lus par l'arène (dégâts, or), l'arme (vitesse d'attaque) et le perso (vitesse, commandes).

const W := 116.0
const LINES := 13
const HYPE_KILL := 7.0
const HYPE_DECAY := 6.0
const HYPE_TIME := 8.0
const POLL_EVERY := 20.0
const POLL_VOTE := 5.0
## Effets de sondage : id -> [texte, durée (s)]
static var POLL_FX := {
	"dmg": ["+25 % DÉGÂTS", 15.0], "gold": ["PLUIE D'OR (+50 % d'or)", 15.0], "heal": ["SOIN (+20 % PV)", 0.0],
	"speed": ["+25 % VITESSE", 15.0], "chaos": ["SPAWN DE MONSTRES", 0.0],
}
static var NAMES := ["xX_Pinceau_Xx", "Gribouilleur", "Crayon2000", "PixelPierre", "Tomate_Officiel", "Aquarellix",
	"ScribbleQueen", "GommeMagique", "LeVraiPicasso", "encre_de_chine", "Taillecrayon", "MonsieurPalette",
	"Patate_Bleue", "LaMuseFan", "chevalet42", "Mlle_Feutre", "Rature_Lover", "BobLaGouache"]
const NAME_COLS := [Color("ff7a7a"), Color("7ac8ff"), Color("ffd36b"), Color("8ae07a"), Color("d39bff"), Color("ffb36b"), Color("7affe0")]
static var SAY := {
	"idle": ["salut le tchat", "première fois sur le stream", "c'est quoi ce dessin mdr", "le perso est trop beau",
		"!build", "lag ?", "la musique ?", "<3", "il dessine avec les pieds ou quoi", "GG l'artiste",
		"on est combien ?", "ça c'est de l'art", "follow pour la suite", "il gère"],
	"streak": ["QUEL CARNAGE", "il est chaud là", "Pog", "clip ça !!", "MONSTRUEUX", "personne ne l'arrête"],
	"hurt": ["aïe", "KEKW", "esquive stp", "il a pas vu venir", "LUL", "ça pique"],
	"low": ["il va mourir lol", "SOIGNE-TOI", "F", "c'est fini...", "non non non", "on y croit !!"],
	"boss": ["LE BOSS !!!", "on y croit", "gg à l'avance", "c'est quoi ce monstre", "prépare les mouchoirs"],
	"elite": ["ÉLITE DOWN", "propre", "trop facile", "WOW"],
	"hype": ["HYPE TRAIN !!!", "CHOO CHOO", "HYPE HYPE HYPE", "on est en feu"],
}

var arena: Arena
var lines: Array = []        # [nom, couleur, texte]
var chat: RichTextLabel
var hype := 0.0
var hype_t := 0.0            # HYPE TRAIN en cours (s)
var poll_t := POLL_EVERY * 0.6
var poll: Dictionary = {}    # {a, b, va, vb, t}
var effect := ""
var effect_t := 0.0
var sub_t := 28.0
var troll_t := 35.0
var flip_t := 0.0            # commandes inversées (s)
var idle_t := 2.0
var streak: Array = []       # instants des dernières éliminations
var said_boss := false
var said_low_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(640 - W - 4, 58)
	size = Vector2(W, 250)
	chat = RichTextLabel.new()
	chat.bbcode_enabled = true
	chat.scroll_active = true
	chat.scroll_following = true   # toujours les derniers messages en bas
	chat.fit_content = false
	chat.get_v_scroll_bar().modulate.a = 0.0   # (sans barre visible)
	chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat.add_theme_font_override("normal_font", UI.font)
	chat.add_theme_font_size_override("normal_font_size", UI.fs(10))
	chat.position = Vector2(4, 16)
	chat.size = Vector2(W - 8, 172)
	chat.clip_contents = true
	add_child(chat)
	_say("idle")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.08, 0.45))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 13)), Color(0.45, 0.25, 0.75, 0.75))
	draw_string(UI.font, Vector2(4, 10), Loc.t("● EN DIRECT"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Color.WHITE)
	# Sondage en cours
	var y := 192.0
	if not poll.is_empty():
		var tot := maxf(1.0, poll.va + poll.vb)
		draw_string(UI.font, Vector2(4, y + 8), Loc.t("SONDAGE"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Pal.ACCENT)
		for k in 2:
			var yy := y + 12 + k * 13
			var v: float = poll.va if k == 0 else poll.vb
			draw_rect(Rect2(4, yy, W - 8, 11), Color(0, 0, 0, 0.5))
			draw_rect(Rect2(4, yy, (W - 8) * v / tot, 11), Color(0.45, 0.25, 0.75, 0.9))
			draw_string(UI.font, Vector2(6, yy + 9), String(POLL_FX[poll.a if k == 0 else poll.b][0]), HORIZONTAL_ALIGNMENT_LEFT, W - 12, UI.fs(10), Color.WHITE)
	elif effect_t > 0.0:
		draw_string(UI.font, Vector2(4, y + 8), Loc.t("%s  %ds") % [POLL_FX[effect][0], ceili(effect_t)], HORIZONTAL_ALIGNMENT_LEFT, W - 8, UI.fs(10), Pal.ACCENT)
	# Jauge de hype
	var hy := size.y - 14.0
	draw_rect(Rect2(4, hy, W - 8, 10), Color(0, 0, 0, 0.6))
	var k2 := 1.0 if hype_t > 0.0 else hype / 100.0
	var col := Color("ff5aa0") if hype_t > 0.0 and int(Time.get_ticks_msec() / 120) % 2 == 0 else Color("ff8a3a")
	draw_rect(Rect2(4, hy, (W - 8) * k2, 10), col)
	draw_string(UI.font, Vector2(6, hy + 8), Loc.t("HYPE TRAIN !") if hype_t > 0.0 else Loc.t("HYPE"), HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fs(10), Color.WHITE)


func _process(delta: float) -> void:
	if arena == null or arena.ended:
		return
	var p := arena.player
	# Hype
	if hype_t > 0.0:
		hype_t -= delta
		if hype_t <= 0.0:
			hype = 0.0
	else:
		hype = maxf(0.0, hype - HYPE_DECAY * delta)
	# Effet du sondage gagné
	if effect_t > 0.0:
		effect_t -= delta
		if effect_t <= 0.0:
			effect = ""
	flip_t -= delta
	# Sondage
	poll_t -= delta
	if poll.is_empty() and poll_t <= 0.0:
		var ids := POLL_FX.keys()
		ids.shuffle()
		poll = {"a": ids[0], "b": ids[1], "va": 0.0, "vb": 0.0, "t": POLL_VOTE}
		_line(Loc.t("Le Stream"), Pal.ACCENT, Loc.t("SONDAGE : %s ou %s ?") % [POLL_FX[ids[0]][0], POLL_FX[ids[1]][0]])
	elif not poll.is_empty():
		poll.t -= delta
		# les votes arrivent petit à petit (un camp est un peu favori)
		poll.va += randf() * 6.0 * delta * (1.3 if hash(poll.a) % 2 == 0 else 1.0)
		poll.vb += randf() * 6.0 * delta
		if randf() < 2.0 * delta:
			_line(_name(), _col(), "!%d" % (1 if randf() < poll.va / maxf(0.01, poll.va + poll.vb) else 2))
		if poll.t <= 0.0:
			_apply(poll.a if poll.va >= poll.vb else poll.b)
			poll = {}
			poll_t = POLL_EVERY
	# Abonnements : plus souvent quand la hype est haute
	sub_t -= delta * (1.0 + hype / 50.0)
	if sub_t <= 0.0:
		sub_t = randf_range(25.0, 40.0)
		var g := 3 + Run.wave
		Run.gold += g
		Sfx.play("coin")
		_line(_name(), Pal.ACCENT, Loc.t("s'est abonné ! +● %d") % g)
		arena.float_text(p.position + Vector2(0, -24), Loc.t("ABONNEMENT ! +%d OR") % g, Pal.ACCENT)
	# Trolls
	troll_t -= delta
	if troll_t <= 0.0:
		troll_t = randf_range(30.0, 45.0)
		if randf() < 0.5:
			_line(_name(), _col(), Loc.t("!shake"))
			arena.shake(9.0)
		else:
			_line(_name(), _col(), Loc.t("!flip"))
			flip_t = 2.0
			arena.float_text(p.position + Vector2(0, -24), Loc.t("COMMANDES INVERSÉES !"), Pal.BAD)
	# Réactions
	if not said_boss and arena.enemies.any(func(e): return e.is_boss):
		said_boss = true
		_say("boss")
	said_low_t -= delta
	if p.hp < p.max_hp * 0.25 and said_low_t <= 0.0:
		said_low_t = 6.0
		_say("low")
	idle_t -= delta
	if idle_t <= 0.0:
		idle_t = randf_range(2.0, 4.5)
		_say("idle")
	queue_redraw()


func on_kill(e: Enemy) -> void:
	var now := arena.elapsed
	streak.append(now)
	streak = streak.filter(func(t): return now - t < 3.0)
	if hype_t <= 0.0:
		hype += HYPE_KILL * (6.0 if e.is_boss else (2.5 if e.elite else 1.0))
		if hype >= 100.0:
			hype = 100.0
			hype_t = HYPE_TIME
			_say("hype")
			arena.hud.announce(Loc.t("HYPE TRAIN !"), Color("ff5aa0"), Loc.t("+30 % dégâts et vitesse d'attaque pendant 8 s"))
			Sfx.play("level")
	if e.elite and randf() < 0.6:
		_say("elite")
	elif streak.size() == 6:
		_say("streak")


func on_hurt() -> void:
	if randf() < 0.45:
		_say("hurt")


## Multiplicateurs lus par le jeu
func dmg_mult() -> float:
	return (1.3 if hype_t > 0.0 else 1.0) * (1.25 if effect == "dmg" else 1.0)


func atk_bonus() -> float:
	return 0.3 if hype_t > 0.0 else 0.0


func speed_mult() -> float:
	return 1.25 if effect == "speed" else 1.0


func gold_mult() -> float:
	return 1.5 if effect == "gold" else 1.0


func _apply(id: String) -> void:
	_line(Loc.t("Le Stream"), Pal.ACCENT, Loc.t("Le tchat a choisi : %s") % POLL_FX[id][0])
	arena.hud.announce(Loc.t("LE TCHAT A VOTÉ"), Color("b98aff"), String(POLL_FX[id][0]))
	match id:
		"heal":
			arena.player.heal(arena.player.max_hp * 0.2)
		"chaos":
			for k in 8:
				var pool := EnemyDB.pool(Run.wave).filter(func(t): return Run.enemy_art.has(t))
				if not pool.is_empty():
					arena.spawn_enemy_now(pool.pick_random(), arena._spawn_pos(90.0), false)
		_:
			effect = id
			effect_t = float(POLL_FX[id][1])


# ------------------------------------------------------------------ Messages

func _name() -> String:
	return NAMES.pick_random()


func _col() -> Color:
	return NAME_COLS.pick_random()


func _say(kind: String) -> void:
	_line(_name(), _col(), String(SAY[kind].pick_random()))


func _line(who: String, col: Color, text: String) -> void:
	lines.append([who, col, text])
	if lines.size() > LINES:
		lines = lines.slice(lines.size() - LINES)
	var b := ""
	for l in lines:
		b += Loc.t("[color=#%s]%s[/color] %s\n") % [(l[1] as Color).to_html(false), l[0], String(l[2]).replace("[", "(")]
	chat.text = b
