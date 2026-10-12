"""Visuel du cercle des faiblesses (pixel art, couleurs du jeu).
Chaque couleur bat la suivante (sens des flèches) : Feu → Foudre → Poison → Glace → Arcane → Feu ;
Lumière et Ombre se battent l'un l'autre.
Écrit assets/ui/cercle.png (avec les noms en français), assets/ui/cercle_en.png (en anglais),
assets/ui/cercle_mini.png (sans les noms, petit) et docs/cercle_elements_x4.png (aperçu agrandi).
Une langue de plus = une entrée dans NAMES_BY_LANG. Usage : python docs/cercle_elements.py"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
INK = (0x1a, 0x14, 0x23)
GOLD = (0xd6, 0xab, 0x4f)
GOLD_DARK = (0x8c, 0x64, 0x14)
SH = {   # sombre, normale, claire
	'feu': [(0x8c, 0x1f, 0x2a), (0xd8, 0x43, 0x3b), (0xf0, 0x8a, 0x5d)],
	'foudre': [(0xb0, 0x7d, 0x1c), (0xf0, 0xc4, 0x3a), (0xfb, 0xe7, 0x9a)],
	'poison': [(0x2c, 0x6b, 0x3a), (0x4f, 0xaa, 0x4c), (0xa4, 0xd8, 0x6a)],
	'glace': [(0x23, 0x40, 0x7a), (0x3f, 0x7f, 0xd9), (0x8c, 0xc4, 0xf2)],
	'arcane': [(0x4d, 0x2a, 0x7a), (0x8c, 0x52, 0xc9), (0xc7, 0x9b, 0xea)],
	'lumiere': [(0xc8, 0xbf, 0xae), (0xf4, 0xef, 0xe2), (0xff, 0xff, 0xff)],
	'noir': [(0x1a, 0x14, 0x23), (0x3d, 0x34, 0x50), (0x6e, 0x67, 0x84)],
}
ICON = {   # 7×7 : '#' = blanc (ou encre sur fond clair), 'o' = teinte claire
	'feu': ["...#...", "..##...", "..###..", ".#####.", ".##o##.", "##ooo##", ".#####."],
	'foudre': ["...###.", "..###..", ".###...", "#######", "...###.", "..###..", ".##...."],
	'poison': [".#####.", "#######", "#..#..#", "#######", ".##.##.", "..###..", "..#.#.."],   # crâne
	'glace': ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	'arcane': ["...#...", "...#...", ".#####.", "#######", ".#####.", "...#...", "...#..."],
	'lumiere': ["#..#..#", ".#...#.", "...#...", "#.###.#", "...#...", ".#...#.", "#..#..#"],
	'noir': [".#####.", "##...##", "#.....#", "#..#..#", "#.....#", "##...##", ".#####."],
}
NAMES_BY_LANG = {
	'fr': {'feu': 'Feu', 'foudre': 'Foudre', 'poison': 'Poison', 'glace': 'Glace', 'arcane': 'Arcane',
		'lumiere': 'Lumière', 'noir': 'Ombre'},
	'en': {'feu': 'Fire', 'foudre': 'Lightning', 'poison': 'Poison', 'glace': 'Ice', 'arcane': 'Arcane',
		'lumiere': 'Light', 'noir': 'Shadow'},
}
CYCLE = ['feu', 'foudre', 'poison', 'glace', 'arcane']


def build(with_names: bool, lang: str = 'fr'):
	NAMES = NAMES_BY_LANG[lang]
	"""Arcs d'épaisseur constante (anneau exact) et pointes pleines symétriques, au pixel près."""
	R, r = (44, 10) if with_names else (31, 7)
	W, H = (236, 168) if with_names else (84, 98)
	cx, cy = W // 2, (72 if with_names else 40)
	font = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'YosterIsland.ttf'), 12)
	if with_names:
		# Un nom long à droite (« Lightning ») : l'image s'élargit vers la droite, le cercle ne bouge pas
		probe = ImageDraw.Draw(Image.new('RGBA', (4, 4)))
		for k, el in enumerate(CYCLE):
			ang = -math.pi / 2 + k * 2 * math.pi / 5
			if math.cos(ang) > 0.3 and math.sin(ang) <= 0.5:
				W = max(W, math.ceil(cx + R * math.cos(ang) + r + 5 + probe.textlength(NAMES[el], font=font) + 3))
	img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
	px = img.load()
	d = ImageDraw.Draw(img)

	def put(x, y, c):
		if 0 <= x < W and 0 <= y < H:
			px[x, y] = c + (255,)

	def disc(x0, y0, rr, sh):
		for y in range(-rr - 1, rr + 2):
			for x in range(-rr - 1, rr + 2):
				dd = math.hypot(x, y)
				if dd <= rr + 1.0:
					put(x0 + x, y0 + y, INK)
				if dd <= rr - 0.2:
					c = sh[1]
					if x + y < -rr * 0.6:
						c = sh[2]
					elif x + y > rr * 0.7:
						c = sh[0]
					put(x0 + x, y0 + y, c)

	def icon(x0, y0, el):
		light = el in ('lumiere', 'foudre')
		for j, row in enumerate(ICON[el]):
			for i, ch in enumerate(row):
				if ch == '#':
					put(x0 - 3 + i, y0 - 3 + j, INK if light else (255, 255, 255))
				elif ch == 'o':
					put(x0 - 3 + i, y0 - 3 + j, SH[el][2])

	def tri(pts):
		"""Triangle rempli au pixel près (test de demi-plans, pas d'anticrénelage)."""
		xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
		def side(a, b, p):
			return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
		out = []
		for y in range(math.floor(min(ys)), math.ceil(max(ys)) + 1):
			for x in range(math.floor(min(xs)), math.ceil(max(xs)) + 1):
				p = (x + 0.5, y + 0.5)
				s1, s2, s3 = side(pts[0], pts[1], p), side(pts[1], pts[2], p), side(pts[2], pts[0], p)
				if (s1 >= 0 and s2 >= 0 and s3 >= 0) or (s1 <= 0 and s2 <= 0 and s3 <= 0):
					out.append((x, y))
		return out

	def arc(a0, a1, rad, thick, hl):
		"""Anneau exact (épaisseur constante) de a0 à a1 (sens horaire), pointe pleine dans l'axe."""
		pts = []
		for y in range(cy - rad - 4, cy + rad + 5):
			for x in range(cx - rad - 4, cx + rad + 5):
				dd = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
				if rad - thick / 2.0 <= dd < rad + thick / 2.0:
					a = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
					rel = (a - a0) % (2 * math.pi)
					if rel <= (a1 - a0):
						pts.append((x, y))
		tang = a1 + math.pi / 2
		ex, ey = cx + rad * math.cos(a1), cy + rad * math.sin(a1)
		tip = (ex + math.cos(tang) * hl, ey + math.sin(tang) * hl)
		wn = hl * 0.75
		base = [(ex + math.cos(tang + math.pi / 2) * wn, ey + math.sin(tang + math.pi / 2) * wn),
			(ex - math.cos(tang + math.pi / 2) * wn, ey - math.sin(tang + math.pi / 2) * wn)]
		head = tri([tip] + base)
		for p in pts + head:   # ombre
			put(p[0] + 1, p[1] + 1, GOLD_DARK)
		for p in pts + head:
			put(p[0], p[1], GOLD)

	angs = [-math.pi / 2 + k * 2 * math.pi / 5 for k in range(5)]
	hl = 6 if with_names else 4
	gap = (r + (6 if with_names else 4)) / R
	for k in range(5):
		arc(angs[k] + gap, angs[k] + 2 * math.pi / 5 - gap - hl / R, R, 2.2 if with_names else 2.0, hl)
	for k, el in enumerate(CYCLE):
		x, y = round(cx + R * math.cos(angs[k])), round(cy + R * math.sin(angs[k]))
		disc(x, y, r, SH[el])
		icon(x, y, el)
		if with_names:
			tw = d.textlength(NAMES[el], font=font)
			c, s = math.cos(angs[k]), math.sin(angs[k])
			if s > 0.5:
				tx, ty = x - tw / 2, y + r + 3
			elif c > 0.3:
				tx, ty = x + r + 5, y - 7
			elif c < -0.3:
				tx, ty = x - r - 5 - tw, y - 7
			else:
				tx, ty = x - tw / 2, y - r - 15
			d.text((round(tx) + 1, ty + 1), NAMES[el], font=font, fill=INK)
			d.text((round(tx), ty), NAMES[el], font=font, fill=SH[el][2])
	# Lumière ⇄ Ombre : deux flèches droites de 2 px, pointes pleines
	y = H - (16 if with_names else 10)
	rr = 8 if with_names else 6
	lx, nx = cx - (26 if with_names else 17), cx + (26 if with_names else 17)
	hh = 4 if with_names else 3
	for (x0, x1, yy) in ((lx + rr + 3, nx - rr - 3 - hh, y - 3), (nx - rr - 3, lx + rr + 3 + hh, y + 2)):
		step = 1 if x1 > x0 else -1
		line = [(x, yy + t) for x in range(x0, x1, step) for t in (0, 1)]
		tip_x = x1 + step * hh
		head = tri([(tip_x, yy + 1), (x1, yy + 1 - hh * 0.9), (x1, yy + 1 + hh * 0.9)])
		for p in line + head:
			put(p[0] + 1, p[1] + 1, GOLD_DARK)
		for p in line + head:
			put(p[0], p[1], GOLD)
	disc(lx, y, rr, SH['lumiere']); icon(lx, y, 'lumiere')
	disc(nx, y, rr, SH['noir']); icon(nx, y, 'noir')
	if with_names:
		for text, x, col, right in ((NAMES['lumiere'], lx - rr - 5, SH['lumiere'][1], True), (NAMES['noir'], nx + rr + 5, SH['noir'][2], False)):
			tw = d.textlength(text, font=font)
			tx = x - tw if right else x
			d.text((round(tx) + 1, y - 6), text, font=font, fill=INK)
			d.text((round(tx), y - 7), text, font=font, fill=col)
	return img


os.makedirs(os.path.join(ROOT, 'assets', 'ui'), exist_ok=True)
full = build(True)
full.save(os.path.join(ROOT, 'assets', 'ui', 'cercle.png'))
for lang in NAMES_BY_LANG:
	if lang != 'fr':
		build(True, lang).save(os.path.join(ROOT, 'assets', 'ui', 'cercle_%s.png' % lang))
build(False).save(os.path.join(ROOT, 'assets', 'ui', 'cercle_mini.png'))
bg = Image.new('RGBA', full.size, (0x2a, 0x10, 0x15, 255))
bg.alpha_composite(full)
bg.resize((full.width * 4, full.height * 4), Image.NEAREST).save(os.path.join(HERE, 'cercle_elements_x4.png'))
print('ok')
