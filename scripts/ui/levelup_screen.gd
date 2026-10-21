class_name LevelUpScreen
extends Control
## Montée de niveau : choisis 1 bonus parmi 3. Tu dessineras ensuite une marque sur ton perso.
## done(upgrade) avec upgrade = {stat, v, rar, text}

signal done(result)

var choices: Array = []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	UI.fill_bg(self)
	if Run.levelup_choices.is_empty():
		Run.levelup_choices = Run.roll_upgrades()
	choices = Run.levelup_choices
	UI.put(self, UI.label(Loc.t("NIVEAU %d !") % (Run.level - Run.pending_levels + 1), 40, Pal.GOOD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 24), Vector2(640, 48))
	var sub := Loc.t("Choisis un bonus parmi les %s.") % (["", Loc.t("un"), Loc.t("deux"), Loc.t("trois"), Loc.t("quatre"), Loc.t("cinq"), Loc.t("six")][choices.size()] if choices.size() < 7 else str(choices.size()))
	UI.put(self, UI.label(sub, 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 80), Vector2(640, 14))
	if Run.pending_levels > 1:
		UI.put(self, UI.label(Loc.t("Encore %d niveau(x) après celui-ci") % (Run.pending_levels - 1), 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 96), Vector2(640, 14))
	# Zone des cartes : de x = 20 à 464 (les stats du perso sont à droite). 2 cartes (Palimpseste)
	# ou 4 et plus (Stéroïdes) : toujours centrées, et rétrécies si elles ne tiennent pas
	var n := choices.size()
	var cw := minf(140.0, (444.0 - 10.0 * (n - 1)) / n)
	var x0 := 20.0 + (444.0 - (n * cw + (n - 1) * 10.0)) / 2.0
	for i in choices.size():
		var u: Dictionary = choices[i]
		var rc: Color = Pal.RARITY[u.rar]
		var p := UI.panel(Pal.PANEL, rc, 2)
		UI.put(self, p, Vector2(x0 + i * (cw + 10.0), 130), Vector2(cw, 150))
		UI.put(p, UI.label(Pal.RARITY_NAMES[u.rar], 10, rc, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 10), Vector2(cw, 12))
		if u.get("pact", false):
			UI.put(p, UI.label(Loc.t("PACTE : bonus doublé, mais..."), 10, Pal.BAD, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 24), Vector2(cw, 12))
		# Le bonus avec l'icône de la stat à la place du mot (son nom au survol)
		# Bonus simple (« +5 % » + icône) en grand ; un pacte (2 lignes) en petit
		var big: bool = not String(u.text).contains("\n")
		var l := UI.rich(u.text, 20 if big else 10, Pal.TEXT, 32 if big else 14, true)
		l.custom_minimum_size.x = cw - 16
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.tooltip_text = "%s : %s" % [StatText.KEY_NAMES.get(String(u.stat), ""), u.text]
		UI.put(p, l, Vector2(8, 44 if big else 40), Vector2(cw - 16, 66))
		var up: Dictionary = u
		var bw := minf(100.0, cw - 12.0)
		UI.put(p, UI.button(Loc.t("Choisir"), func(): done.emit(up)), Vector2((cw - bw) / 2.0, 116), Vector2(bw, 20))
		# Arrivée : la carte monte en apparaissant, une par une
		p.modulate.a = 0.0
		p.position.y += 30.0
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "modulate:a", 1.0, 0.25).set_delay(0.08 * i)
		tw.tween_property(p, "position:y", 130.0, 0.3).set_delay(0.08 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if int(u.rar) >= 2:
			# épique et légendaire : la carte luit doucement
			var sh := p.create_tween().set_loops()
			sh.tween_property(p, "self_modulate", Color(1.35, 1.25, 1.1), 0.6)
			sh.tween_property(p, "self_modulate", Color.WHITE, 0.6)
	# Les stats actuelles du perso, pour choisir en connaissance de cause
	var sp := UI.panel(Pal.PANEL, Pal.BORDER, 2)
	UI.put(self, sp, Vector2(474, 112), Vector2(150, 236))
	UI.put(sp, UI.label(Loc.t("TON PERSO"), 10, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 6), Vector2(150, 12))
	var stx := StatText.new(2)
	UI.put(sp, stx, Vector2(8, 22), Vector2(136, 208))
	stx.set_text(Stats.describe_player(Run.stats))
	sp.size.y = 22.0 + stx.custom_minimum_size.y + 8.0   # la boîte prend juste la hauteur des stats
