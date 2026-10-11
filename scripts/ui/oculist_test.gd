class_name OculistTest
extends Control
## Lunettes de l'oculiste : un test de vision des couleurs en pixel art, façon planche d'Ishihara.
## Un chiffre caché dans un disque de points. La planche est tirée au hasard parmi 3 types
## (rouge-vert « protan » et « deutan », bleu-jaune « tritan »). Les points du chiffre et ceux du
## fond sont sur une LIGNE DE CONFUSION : pour un daltonien de ce type, ils ont exactement la même
## couleur (seul le cône qui lui manque fait la différence) ; pour une vue normale, le chiffre saute
## aux yeux. La luminosité des points varie au hasard : elle ne trahit pas le chiffre.
## Pas de limite de temps : 4 réponses (dont « Je ne vois rien »). done(true) si c'est réussi.

signal done(result)

const TYPES := ["protan", "deutan", "tritan"]
static var TYPE_NAMES := {"protan": "rouge-vert (protanopie)", "deutan": "rouge-vert (deutéranopie)",
	"tritan": "bleu-jaune (tritanopie)"}
const SIZE := 120   # la planche (pixels), affichée ×2
## Chiffres 5×7 arrondis ('#' = allumé), plus lisibles que des chiffres carrés
const DIGITS := [
	[".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	[".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	[".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
	["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	[".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	[".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
]
## Familles de couleurs du chiffre, par type ([nom, [r min, r max], [g...], [b...]]). Le fond est
## toujours calculé sur la ligne de confusion du type : seule la famille du chiffre change.
const FAMILIES := {
	"rg": [["orange", [0.8, 0.95], [0.4, 0.55], [0.15, 0.3]], ["rose", [0.85, 0.95], [0.45, 0.6], [0.55, 0.7]],
		["brique", [0.65, 0.8], [0.3, 0.4], [0.2, 0.3]], ["marron", [0.55, 0.7], [0.38, 0.48], [0.25, 0.35]]],
	"by": [["bleu", [0.3, 0.55], [0.4, 0.6], [0.8, 0.95]], ["violet", [0.5, 0.65], [0.35, 0.5], [0.75, 0.9]],
		["ciel", [0.45, 0.6], [0.65, 0.8], [0.9, 0.98]]],
}
const NO_NUMBER_CHANCE := 0.2   # 1 planche sur 5 n'a pas de chiffre
const INVERT_CHANCE := 0.3   # parfois le chiffre prend la couleur du fond et inversement
const MIN_CONTRAST := 0.55   # en dessous (planche trop pâle pour une vue normale), on change de famille

# Passage RGB linéaire <-> LMS (cônes L, M, S), modèle de Viénot / Brettel
const RGB2LMS := [[17.8824, 43.5161, 4.11935], [3.45565, 27.1554, 3.86714], [0.0299566, 0.184309, 1.46709]]
const LMS2RGB := [[0.0809444479, -0.130504409, 0.116721066], [-0.0102485335, 0.0540193266, -0.113614708],
	[-0.000365296938, -0.00412161469, 0.693511405]]

var kind := ""
var answer := 0
var choices: Array = []
var finished := false
var info: Label
var plate: Dictionary


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	UI.fill_bg(self)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# rouge-vert 80 % (40 % chacun), bleu-jaune 20 % : le bleu-jaune est très rare (et plus dur à lire)
	var roll := rng.randf()
	kind = "protan" if roll < 0.4 else ("deutan" if roll < 0.8 else "tritan")
	answer = rng.randi_range(12, 98)
	if answer % 10 == 0:
		answer += 1
	if rng.randf() < NO_NUMBER_CHANCE:
		answer = -1   # planche SANS chiffre : la bonne réponse est « Je ne vois rien »
	plate = make_plate(kind, answer, rng)
	# Les réponses : 3 nombres (dont le bon s'il y en a un) et « Je ne vois rien »
	var decoys := []
	while decoys.size() < (2 if answer >= 0 else 3):
		var d := rng.randi_range(12, 98)
		if d != answer and not d in decoys and d % 10 != 0:
			decoys.append(d)
	choices = ([answer] if answer >= 0 else []) + decoys + [-1]
	var head := choices.slice(0, 3)
	head.shuffle()
	choices = head + [-1]

	UI.put(self, UI.label(Loc.t("LUNETTES DE L'OCULISTE"), 20, Pal.ACCENT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 10), Vector2(640, 24))
	UI.put(self, UI.label(Loc.t("Quel chiffre vois-tu dans le cercle ?"), 10, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 38), Vector2(640, 12))
	var fr := UI.panel(Pal.PAPER, Pal.BORDER, 2)
	UI.put(self, fr, Vector2(196, 56), Vector2(248, 248))
	UI.put(fr, UI.thumb(plate.image, Vector2(SIZE * 2, SIZE * 2)), Vector2(4, 4), Vector2(SIZE * 2, SIZE * 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	UI.put(self, row, Vector2(0, 320), Vector2(640, 22))
	for k in choices.size():
		var v: int = choices[k]
		var b := UI.hotkey(UI.button(str(v) if v >= 0 else Loc.t("Je ne vois rien"), func(): _pick(v), 20), [KEY_1 + k])
		b.custom_minimum_size = Vector2(70 if v >= 0 else 150, 22)
		row.add_child(b)
	info = UI.label("", 10, Pal.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UI.put(self, info, Vector2(0, 345), Vector2(640, 12))


func _pick(v: int) -> void:
	if finished:
		return
	finished = true
	var ok := v == answer
	Sfx.play("level" if ok else "hurt")
	var truth := (Loc.t("c'était %d") % answer) if answer >= 0 else Loc.t("il n'y avait pas de chiffre")
	var title := Loc.t("BONNE RÉPONSE ! Stats complètes") if ok else Loc.t("RATÉ : %s. Moitié des stats") % truth
	info.text = Loc.t("%s  ·  test %s") % [title, TYPE_NAMES[kind]]
	info.add_theme_color_override("font_color", Pal.GOOD if ok else Pal.BAD)
	await get_tree().create_timer(2.2).timeout
	done.emit(ok)


# ------------------------------------------------------------------ La planche

static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func _srgb(c: float) -> float:
	c = clampf(c, 0.0, 1.0)
	return c * 12.92 if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055


static func _mul(m: Array, v: Array) -> Array:
	return [m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2], m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
		m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2]]


static func to_lms(c: Color) -> Array:
	return _mul(RGB2LMS, [_lin(c.r), _lin(c.g), _lin(c.b)])


static func from_lms(l: Array) -> Color:
	var rgb := _mul(LMS2RGB, l)
	return Color(_srgb(rgb[0]), _srgb(rgb[1]), _srgb(rgb[2]))


static func _in_gamut(l: Array) -> bool:
	var rgb := _mul(LMS2RGB, l)
	return rgb[0] >= 0.0 and rgb[0] <= 1.0 and rgb[1] >= 0.0 and rgb[1] <= 1.0 and rgb[2] >= 0.0 and rgb[2] <= 1.0


## Ce que voit un daltonien de ce type : le cône manquant est reconstruit à partir des deux autres
## (projection de Viénot). Deux couleurs sur une même ligne de confusion donnent le même résultat.
static func simulate(c: Color, k: String) -> Color:
	var l := to_lms(c)
	match k:
		"protan":
			l[0] = 2.02344 * l[1] - 2.52581 * l[2]
		"deutan":
			l[1] = 0.494207 * l[0] + 1.24827 * l[2]
		"tritan":
			l[2] = -0.395913 * l[0] + 0.801109 * l[1]
	return from_lms(l)


## Couleurs du chiffre et du fond (sur une ligne de confusion du type), puis la planche.
## Retourne {image, fig, bg, kind}.
static func make_plate(k: String, number: int, rng: RandomNumberGenerator) -> Dictionary:
	var axis: int = {"protan": 0, "deutan": 1, "tritan": 2}[k]
	var fig := Color.WHITE
	var bg := Color.WHITE
	# Une famille de couleurs au hasard ; dans cette famille, on garde la paire la PLUS contrastée
	# pour une vue normale (identique, par construction, pour ce daltonisme).
	var fams: Array = FAMILIES["by" if k == "tritan" else "rg"]
	var fam: Array = fams[rng.randi() % fams.size()]
	var best_d := 0.0
	for attempt in 640:
		if attempt % 160 == 0 and attempt > 0 and best_d < MIN_CONTRAST:
			fam = fams[rng.randi() % fams.size()]   # trop pâle : une autre famille
		elif attempt >= 160 and best_d >= MIN_CONTRAST:
			break
		var f := Color(rng.randf_range(fam[1][0], fam[1][1]), rng.randf_range(fam[2][0], fam[2][1]), rng.randf_range(fam[3][0], fam[3][1]))
		var lf := to_lms(f)
		for sgn in [1.0, -1.0]:
			# le plus loin possible sur la ligne de confusion, en restant dans les couleurs affichables
			var tt := 0.0
			var best := 0.0
			while tt <= lf[axis] * 3.0:
				tt += lf[axis] * 0.03
				var lb := lf.duplicate()
				lb[axis] += sgn * tt
				if not _in_gamut(lb):
					break
				best = tt
			if best <= 0.0:
				continue
			var lb2 := lf.duplicate()
			lb2[axis] += sgn * best * 0.95
			var b := from_lms(lb2)
			var dist := Vector3(f.r - b.r, f.g - b.g, f.b - b.b).length()
			if dist > best_d:
				best_d = dist
				fig = f
				bg = b
	var inverted := rng.randf() < INVERT_CHANCE
	if inverted:
		var tmp := fig
		fig = bg
		bg = tmp
	# Masque du nombre : 2 chiffres 5×7 agrandis ×8, traits épaissis de 2 px (bien lisibles en points)
	var mask := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_L8)
	var sc := 8
	var digits := [int(number / 10), number % 10] if number >= 0 else []   # (pas de chiffre : rien à dessiner)
	var x0 := (SIZE - (11 * sc)) / 2
	var y0 := (SIZE - 7 * sc) / 2
	for di in digits.size():
		var pat: Array = DIGITS[digits[di]]
		for j in 7:
			for i in 5:
				if String(pat[j])[i] == "#":
					mask.fill_rect(Rect2i(x0 + di * (6 * sc) + i * sc - 2, y0 + j * sc - 2, sc + 4, sc + 4), Color.WHITE)
	# Points de tailles variées, sans chevauchement, dans le disque
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := Vector2(SIZE / 2.0, SIZE / 2.0)
	var taken := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_L8)
	var lfig := to_lms(fig)
	var lbg := to_lms(bg)
	for n in 14000:   # (beaucoup d'essais : une planche bien remplie)
		var r := rng.randi_range(2, 3) if n < 8000 else rng.randi_range(1, 2)
		var p := Vector2(rng.randf_range(r, SIZE - r), rng.randf_range(r, SIZE - r))
		if p.distance_to(c) > SIZE / 2.0 - r - 1:
			continue
		var free := true
		for y in range(int(p.y) - r - 1, int(p.y) + r + 2):
			for x in range(int(p.x) - r - 1, int(p.x) + r + 2):
				if x >= 0 and y >= 0 and x < SIZE and y < SIZE and taken.get_pixel(x, y).r > 0.5 and Vector2(x + 0.5, y + 0.5).distance_to(p) <= r + 0.6:
					free = false
		if not free:
			continue
		var on_fig := mask.get_pixel(int(p.x), int(p.y)).r > 0.5
		# luminosité au hasard (tous les cônes ensemble : reste sur la même ligne de confusion)
		var j := rng.randf_range(0.88, 1.1)
		var l: Array = (lfig if on_fig else lbg).map(func(v): return v * j)
		var col := from_lms(l)
		for y in range(int(p.y) - r, int(p.y) + r + 1):
			for x in range(int(p.x) - r, int(p.x) + r + 1):
				if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r:
					img.set_pixel(x, y, col)
					taken.set_pixel(x, y, Color.WHITE)
	return {"image": img, "fig": fig, "bg": bg, "kind": k, "family": fam[0], "inverted": inverted}
