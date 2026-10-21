class_name Analyzer
extends RefCounted
## Analyse un dessin : nombre de pixels, forme, symétrie, morceaux séparés, couleurs.
## Toutes les stats du jeu sont dérivées de ce résultat.


@warning_ignore("integer_division")
static func analyze(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var filled := PackedByteArray()
	filled.resize(w * h)
	var count := 0
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	var el := []
	el.resize(Pal.COUNT)
	el.fill(0)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				filled[y * w + x] = 1
				count += 1
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
				el[Pal.element_of(c)] += 1

	var r := {
		"pixels": count, "w": w, "h": h, "rect": Rect2i(), "bw": 0, "bh": 0,
		"sym": 0.0, "solidity": 0.0, "components": 0, "comp_list": [],
		"labels": PackedInt32Array(), "frac": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
		"dominant": 0, "elements": 0, "elong": 1.0, "long": 0, "diag": 0.0,
	}
	if count == 0:
		return r

	var bw := maxx - minx + 1
	var bh := maxy - miny + 1
	var edge := 0
	var sym := 0
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			if filled[y * w + x] == 0:
				continue
			if filled[y * w + (minx + maxx - x)] == 1:
				sym += 1
			if x == 0 or y == 0 or x == w - 1 or y == h - 1 \
					or filled[y * w + x - 1] == 0 or filled[y * w + x + 1] == 0 \
					or filled[(y - 1) * w + x] == 0 or filled[(y + 1) * w + x] == 0:
				edge += 1

	# Morceaux séparés (8-connexité)
	var labels := PackedInt32Array()
	labels.resize(w * h)
	labels.fill(-1)
	var comps := []
	for i in w * h:
		if filled[i] == 0 or labels[i] != -1:
			continue
		var id := comps.size()
		var stack: Array[int] = [i]
		labels[i] = id
		var n := 0
		var cx0 := w
		var cy0 := h
		var cx1 := -1
		var cy1 := -1
		while not stack.is_empty():
			var j: int = stack.pop_back()
			var jx := j % w
			var jy := j / w
			n += 1
			cx0 = mini(cx0, jx)
			cx1 = maxi(cx1, jx)
			cy0 = mini(cy0, jy)
			cy1 = maxi(cy1, jy)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := jx + dx
					var ny := jy + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					var k := ny * w + nx
					if filled[k] == 1 and labels[k] == -1:
						labels[k] = id
						stack.append(k)
		comps.append({"count": n, "rect": Rect2i(cx0, cy0, cx1 - cx0 + 1, cy1 - cy0 + 1)})

	var frac := []
	var elements := 0
	for e in Pal.COUNT:
		frac.append(float(el[e]) / count)
		if el[e] > 0 and float(el[e]) / count >= 0.03:
			elements += 1
	var dominant := dominant_of(el)

	r.rect = Rect2i(minx, miny, bw, bh)
	r.bw = bw
	r.bh = bh
	r.sym = float(sym) / count
	r.solidity = 1.0 - float(edge) / count
	r.components = comps.size()
	r.comp_list = comps
	r.labels = labels
	r.frac = frac
	r.dominant = dominant
	r.elements = elements
	r.long = maxi(bw, bh)
	r.elong = float(maxi(bw, bh)) / float(mini(bw, bh))
	r.diag = sqrt(float(bw * bw + bh * bh))
	return r


## Découpe chaque morceau en image séparée (un morceau = un projectile).
## center = position du morceau par rapport au centre du dessin complet.
static func split_components(img: Image, a: Dictionary, max_parts := 12) -> Array:
	var out := []
	if a.pixels == 0:
		return out
	var w: int = a.w
	var full: Rect2i = a.rect
	var full_c := Vector2(full.position) + Vector2(full.size) / 2.0
	var labels: PackedInt32Array = a.labels
	for id in a.comp_list.size():
		var comp: Dictionary = a.comp_list[id]
		var rc: Rect2i = comp.rect
		var part := Image.create_empty(rc.size.x, rc.size.y, false, Image.FORMAT_RGBA8)
		for y in rc.size.y:
			for x in rc.size.x:
				var gx := rc.position.x + x
				var gy := rc.position.y + y
				if labels[gy * w + gx] == id:
					part.set_pixel(x, y, img.get_pixel(gx, gy))
		var c := Vector2(rc.position) + Vector2(rc.size) / 2.0
		out.append({
			"image": part, "count": comp.count, "center": c - full_c,
			"elong": float(maxi(rc.size.x, rc.size.y)) / float(mini(rc.size.x, rc.size.y)),
			"size": rc.size,
		})
	out.sort_custom(func(p, q): return p.count > q.count)
	if out.size() > max_parts:
		out.resize(max_parts)
	return out


## Couleur dominante d'après les pixels par couleur (0 si aucune ne fait 25 % du dessin).
static func dominant_of(el: Array) -> int:
	var count := 0
	for v in el:
		count += int(v)
	var dominant := 0
	var dom_count := 0
	for e in range(1, mini(el.size(), Pal.COUNT)):
		if int(el[e]) > dom_count:
			dom_count = int(el[e])
			dominant = e
	if count == 0 or float(dom_count) / count < 0.25:
		return 0
	return dominant


static func trim(img: Image) -> Image:
	var r := img.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	return img.get_region(r)


## Encre consommée = pixels de contour (qui touchent une case vide ou le bord).
## L'intérieur d'une forme est gratuit : colorier ne coûte rien, tracer coûte.
static func ink_cost(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if is_edge(img, Vector2i(x, y)):
				n += 1
	return n


static func is_edge(img: Image, p: Vector2i) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or img.get_pixelv(p).a < 0.5:
		return false
	if p.x == 0 or p.y == 0 or p.x == w - 1 or p.y == h - 1:
		return true
	return img.get_pixel(p.x - 1, p.y).a < 0.5 or img.get_pixel(p.x + 1, p.y).a < 0.5 \
		or img.get_pixel(p.x, p.y - 1).a < 0.5 or img.get_pixel(p.x, p.y + 1).a < 0.5


static func count_pixels(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				n += 1
	return n
