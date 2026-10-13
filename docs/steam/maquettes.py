"""Maquettes de la capsule d'entête : trois idées pour ce qu'il y a sous le titre.

  1. le dessin qui SORT de la toile (un seul perso)
  3. le dessin et ses stats (icônes du jeu)
  4. le matériel d'artiste (aucun personnage)

Usage : python docs/steam/maquettes.py [dossier de sortie]
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from capsules import (ROOT, OUT, WALL, INK, PAL, PENCIL, CANVAS, CANVAS_LINE, WOOD, WOOD_D, GOLD, GOLD_D,
	frame, drawing, big, half_drawn, pencil, sprite, splat)

W, H = 920, 430
DEST = sys.argv[1] if len(sys.argv) > 1 else OUT


def logo(img, x=362, y=50, lw=500):
	lg = Image.open(os.path.join(ROOT, 'docs', 'logo_jeu_source.png')).convert('RGBA')
	lh = round(lg.height * lw / lg.width)
	lg = lg.resize((lw, lh), Image.NEAREST)
	img.paste(lg, (x, y), lg)
	return y + lh


def easel(img, d, cx0, cy0, cx1, cy1, y1, legs=True):
	if legs:
		d.polygon([(cx0 + 44, cy1), (cx0 + 58, cy1), (cx0 + 30, y1), (cx0 + 16, y1)], fill=WOOD_D)
		d.polygon([(cx1 - 58, cy1), (cx1 - 44, cy1), (cx1 - 14, y1), (cx1 - 28, y1)], fill=WOOD_D)
		d.rectangle([(cx0 + cx1) // 2 - 7, cy1, (cx0 + cx1) // 2 + 7, y1 - 20], fill=WOOD)
	d.rectangle([cx0 - 6, cy0 - 6, cx1 + 6, cy1 + 6], fill=WOOD_D)
	d.rectangle([cx0 - 2, cy0 - 2, cx1 + 2, cy1 + 2], fill=WOOD)
	d.rectangle([cx0, cy0, cx1, cy1], fill=CANVAS)
	for x in range(cx0 + 12, cx1, 12):
		d.line([x, cy0, x, cy1], fill=CANVAS_LINE)
	for y in range(cy0 + 12, cy1, 12):
		d.line([cx0, y, cx1, y], fill=CANVAS_LINE)
	d.rectangle([cx0 - 14, cy1 + 6, cx1 + 14, cy1 + 18], fill=WOOD_D)
	d.rectangle([cx0 - 14, cy1 + 6, cx1 + 14, cy1 + 9], fill=WOOD)


def canvas_with_hero(img, d, y1):
	"""La toile de gauche, avec le perso à moitié dessiné et le crayon (comme la capsule actuelle)."""
	cx0, cy0, cx1, cy1 = 66, 62, 330, 300
	easel(img, d, cx0, cy0, cx1, cy1, y1)
	hero = drawing('perso')
	sk, tip = half_drawn(hero, 10, 10)
	hx = (cx0 + cx1 - sk.width) // 2
	hy = (cy0 + cy1 - sk.height) // 2 + 6
	img.paste(sk, (hx, hy), sk)
	pen = pencil(6, 220)
	img.paste(pen, (hx + tip[0] - 4, hy + tip[1] - pen.height + 4), pen)
	return cx1


def blob(img, x, y, col, k, shape=0):
	"""Tache de peinture bordée d'encre."""
	shapes = [
		["..ooo...", ".ooooo.o", "ooooooo.", "oooooooo", ".oooooo.", "..oooo..", "o..oo..."],
		[".oo.....", "oooo.oo.", "ooooooo.", ".oooooo.", "..ooooo.", "...oo..o"],
		["...oo...", ".oooooo.", "oooooooo", "oooooooo", ".oooooo.", "..o..o.."],
	]
	rows = shapes[shape % len(shapes)]
	d = ImageDraw.Draw(img)
	fill = {(i, j) for j, r in enumerate(rows) for i, c in enumerate(r) if c == 'o'}
	for (i, j) in fill:
		for dx in (-1, 0, 1):
			for dy in (-1, 0, 1):
				if (i + dx, j + dy) not in fill:
					d.rectangle([x + (i + dx) * k, y + (j + dy) * k, x + (i + dx + 1) * k - 1, y + (j + dy + 1) * k - 1], fill=INK)
	hi = tuple(min(255, c + 50) for c in col)
	for (i, j) in fill:
		d.rectangle([x + i * k, y + j * k, x + (i + 1) * k - 1, y + (j + 1) * k - 1], fill=hi if (i + j) < 4 else col)


# ------------------------------------------------------------------ 1. Le dessin qui sort de la toile
def idee_1():
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	d = ImageDraw.Draw(img)
	cx0, cy0, cx1, cy1 = 66, 62, 330, 366
	easel(img, d, cx0, cy0, cx1, cy1, y1, legs=False)
	bottom = logo(img)
	hero = drawing('perso')
	k = 10
	w, h = hero.size
	px = hero.load()
	hx, hy = 226, bottom + 22
	def solid(x, y):
		return 0 <= x < w and 0 <= y < h and px[x, y][3] > 0
	for y in range(h):
		for x in range(w):
			if not solid(x, y):
				continue
			r, g, b, a = px[x, y]
			box = [hx + x * k, hy + y * k, hx + (x + 1) * k - 1, hy + (y + 1) * k - 1]
			if hx + x * k >= cx1 - 4:
				d.rectangle(box, fill=(r, g, b))                      # sorti de la toile : en couleur
			else:
				edge = not all(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
				pale = tuple(round(c * 0.3 + cc * 0.7) for c, cc in zip((r, g, b), CANVAS))
				d.rectangle(box, fill=INK if edge else pale)          # encore sur la toile : un croquis
	sword = big(drawing('arme_epee_arcane'), 5)
	img.paste(sword, (hx + w * k - 40, hy + 6), sword)
	pen = pencil(6, 200)
	img.paste(pen, (cx0 + 22, cy0 + 150), pen)
	# éclaboussures de peinture à la sortie, et quelques gouttes plus loin
	for (bx, by, ch, kk, sh) in ((640, bottom + 40, 'r', 5, 0), (716, bottom + 110, 'b', 4, 1), (800, bottom + 36, 'y', 4, 2),
			(840, bottom + 128, 'g', 3, 0), (668, bottom + 150, 'v', 3, 2)):
		blob(img, bx, by, PAL[ch], kk, sh)
	splat(img, 600, bottom + 130, 3, INK)
	splat(img, 768, bottom + 84, 3, INK)
	img.save(os.path.join(DEST, 'maquette_1_sort_de_la_toile.png'))


# ------------------------------------------------------------------ 3. Le dessin et ses stats
def idee_3():
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	d = ImageDraw.Draw(img)
	cx1 = canvas_with_hero(img, d, y1)
	bottom = logo(img)
	icons = ['max_hp', 'dmg', 'move', 'armor', 'crit']
	fills = [0.9, 0.55, 0.75, 0.35, 0.6]
	ty = bottom + 44
	for i, name in enumerate(icons):
		tx = 392 + i * 98
		d.rectangle([tx - 4, ty - 4, tx + 79, ty + 79], fill=INK)
		d.rectangle([tx, ty, tx + 75, ty + 75], fill=CANVAS)
		ic = Image.open(os.path.join(ROOT, 'assets', 'ui', 'stats', name + '.png')).convert('RGBA')
		ic = ic.resize((ic.width * 4, ic.height * 4), Image.NEAREST)
		img.paste(ic, (tx + (76 - ic.width) // 2, ty + (76 - ic.height) // 2), ic)
		# jauge sous l'icône
		gy = ty + 92
		d.rectangle([tx - 4, gy, tx + 79, gy + 17], fill=INK)
		d.rectangle([tx, gy + 4, tx + 75, gy + 13], fill=GOLD_D)
		d.rectangle([tx, gy + 4, tx + round(75 * fills[i]), gy + 13], fill=GOLD)
	# pointillés : de la toile aux stats
	for k in range(4):
		d.rectangle([cx1 + 14 + k * 14, ty + 34, cx1 + 14 + k * 14 + 7, ty + 40], fill=INK)
	img.save(os.path.join(DEST, 'maquette_3_stats.png'))


# ------------------------------------------------------------------ 4. Le matériel d'artiste
BRUSH = [
	"nn..........mm...",
	"nnnnnnnnnnnnmmrrr",
	"nnnnnnnnnnnnmmrrrr",
	"nnnnnnnnnnnnmmrrr",
	"nn..........mm...",
]
TUBE = [
	".kkkkkkkkkk..",
	"kwwwwwwwwwwkk",
	"kwccccccccwkmk",
	"kwccccccccwkmk",
	"kwwwwwwwwwwkk",
	".kkkkkkkkkk..",
]
ERASER = [
	"kkkkkkkkkk",
	"kppppppbbk",
	"kppppppbbk",
	"kppppppbbk",
	"kkkkkkkkkk",
]


def tool(rows, k, angle, swap=None):
	pal = dict(PAL)
	pal['c'] = PAL['r']
	if swap:
		pal.update(swap)
	im = Image.new('RGBA', (max(len(r) for r in rows) * k, len(rows) * k), (0, 0, 0, 0))
	dd = ImageDraw.Draw(im)
	for j, row in enumerate(rows):
		for i, ch in enumerate(row):
			if ch in pal:
				dd.rectangle([i * k, j * k, (i + 1) * k - 1, (j + 1) * k - 1], fill=pal[ch])
	return im.rotate(angle, resample=Image.NEAREST, expand=True)


def idee_4():
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	d = ImageDraw.Draw(img)
	canvas_with_hero(img, d, y1)
	bottom = logo(img)
	for (bx, by, ch, kk, sh) in ((392, bottom + 26, 'r', 6, 0), (470, bottom + 120, 'b', 6, 1), (560, bottom + 22, 'y', 6, 2),
			(650, bottom + 124, 'g', 6, 0), (742, bottom + 30, 'v', 6, 1), (826, bottom + 122, 'w', 5, 2)):
		blob(img, bx, by, PAL[ch], kk, sh)
	for (im, x, y) in (
			(tool(PENCIL, 6, 18), 380, bottom + 104),
			(tool(PENCIL, 6, -24, {'y': PAL['b'], 'Y': PAL['B']}), 590, bottom + 60),
			(tool(BRUSH, 6, 10, {'r': PAL['v']}), 700, bottom + 96),
			(tool(TUBE, 6, -14, {'c': PAL['g']}), 470, bottom + 44),
			(tool(TUBE, 6, 22, {'c': PAL['y']}), 790, bottom + 36),
			(tool(ERASER, 6, -8), 566, bottom + 150)):
		img.paste(im, (x, y), im)
	splat(img, 446, bottom + 172, 3, INK)
	splat(img, 868, bottom + 84, 3, INK)
	img.save(os.path.join(DEST, 'maquette_4_materiel.png'))


# ------------------------------------------------------------------ Versions épurées
def titre_seul():
	"""Juste le titre, à sa place habituelle (en haut à droite)."""
	img = Image.new('RGB', (W, H), WALL)
	frame(img, W, H)
	logo(img)
	img.save(os.path.join(DEST, 'capsule_titre_seul.png'))


def titre_et_toile():
	"""Le titre à sa place habituelle, et la toile vide sur son chevalet à gauche."""
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	d = ImageDraw.Draw(img)
	easel(img, d, 66, 62, 330, 300, y1)
	logo(img)
	img.save(os.path.join(DEST, 'capsule_titre_et_toile.png'))


PAPER_DARK, PAPER_LIGHT = (0x9c, 0x86, 0x5c), (0xe2, 0xd3, 0xae)   # (un peu plus foncé que le papier, clair compris)


def tinted(im):
	"""Le dessin ramené aux nuances du papier : ses zones sombres en beige foncé, ses zones claires en beige clair."""
	out = Image.new('RGBA', im.size, (0, 0, 0, 0))
	src, dst = im.load(), out.load()
	for y in range(im.height):
		for x in range(im.width):
			r, g, b, a = src[x, y]
			if a == 0:
				continue
			t = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
			dst[x, y] = tuple(round(PAPER_DARK[i] + (PAPER_LIGHT[i] - PAPER_DARK[i]) * t) for i in range(3)) + (255,)
	return out


def fit(im, height):
	"""Agrandit un petit dessin d'un facteur entier pour approcher la hauteur voulue."""
	k = max(1, round(height * 2 / im.height))
	return im.resize((im.width * k, im.height * k), Image.NEAREST)


def doodle(zone_w, zone_h, seed=3, margin=2):
	"""Un « doodle » : tous les sprites de docs/steam/dessins/doodle serrés les uns contre les autres,
	sans se chevaucher, pour remplir une zone. Les gros d'abord, les petits bouchent les trous."""
	import glob
	import random
	import numpy as np
	rnd = random.Random(seed)
	sprites = []
	for f in sorted(glob.glob(os.path.join(OUT, 'dessins', 'doodle', '*.png'))):
		im = Image.open(f).convert('RGBA')
		k = 1 if max(im.size) > 80 else 2          # (boss tels quels ; mini-boss et petits ennemis agrandis ×2)
		sprites.append(big(im, k))
	sprites.sort(key=lambda im: -im.width * im.height)
	used = np.zeros((zone_h, zone_w), dtype=bool)
	out = Image.new('RGBA', (zone_w, zone_h), (0, 0, 0, 0))
	for im in sprites:
		if rnd.random() < 0.5:
			im = im.transpose(Image.FLIP_LEFT_RIGHT)
		mask = np.array(im)[:, :, 3] > 0
		fat = np.zeros_like(mask)                  # le sprite, épaissi de `margin` px : l'écart entre voisins
		for dy in range(-margin, margin + 1):
			for dx in range(-margin, margin + 1):
				fat |= np.roll(np.roll(mask, dy, 0), dx, 1)
		h, w = mask.shape
		best = None
		for y in range(0, zone_h - h + 1, 2):
			for x in range(0, zone_w - w + 1, 2):
				if not (used[y:y + h, x:x + w] & fat).any():
					score = x + rnd.random() * 30 + abs(y + h / 2 - zone_h / 2) * 0.15   # de gauche à droite
					if best is None or score < best[0]:
						best = (score, x, y)
		if best is None:
			print('   doodle : un sprite de %dx%d ne rentre pas' % im.size)
			continue
		_, x, y = best
		used[y:y + h, x:x + w] |= mask
		out.alpha_composite(im, (x, y))
	return out


def doodle_fill(free, seed=5, margin=2):
	"""Remplit TOUTE la zone libre (free : tableau de booléens, vrai = on peut dessiner) avec les sprites,
	répétés autant qu'il faut, serrés sans se chevaucher. Les gros d'abord, puis de plus en plus petits."""
	import glob
	import random
	import numpy as np
	rnd = random.Random(seed)
	base = []
	for f in sorted(glob.glob(os.path.join(OUT, 'dessins', 'doodle', '*.png'))):
		im = Image.open(f).convert('RGBA')
		base.append(big(im, 1 if max(im.size) > 50 else 2))   # (les petits ennemis sont agrandis ×2)
	zone_h, zone_w = free.shape
	used = ~free
	out = Image.new('RGBA', (zone_w, zone_h), (0, 0, 0, 0))
	fu_shape = (zone_h, zone_w)
	n = 0

	def place(src):
		nonlocal n
		im = src.transpose(Image.FLIP_LEFT_RIGHT) if rnd.random() < 0.5 else src
		mask = np.array(im)[:, :, 3] > 0
		fat = np.zeros_like(mask)
		for dy in range(-margin, margin + 1):
			for dx in range(-margin, margin + 1):
				fat |= np.roll(np.roll(mask, dy, 0), dx, 1)
		h, w = mask.shape
		if h > zone_h or w > zone_w:
			return False
		# nombre de pixels en conflit pour chaque position (corrélation par transformée de Fourier)
		pad = np.zeros(fu_shape)
		pad[:h, :w] = fat
		hit = np.fft.irfft2(np.fft.rfft2(used.astype(float)) * np.conj(np.fft.rfft2(pad)), s=fu_shape)
		ys, xs = np.nonzero(hit[:zone_h - h + 1, :zone_w - w + 1] < 0.5)
		if len(xs) == 0:
			return False
		k = rnd.randrange(len(xs))   # une place au hasard : deux copies du même dessin ne se collent pas
		x, y = int(xs[k]), int(ys[k])
		used[y:y + h, x:x + w] |= mask
		out.alpha_composite(im, (x, y))
		n += 1
		return True

	# les boss une seule fois chacun, les mini-boss deux fois, puis les petits tant qu'il reste de la place
	bigs = [im for im in base if max(im.size) > 80]
	mids = [im for im in base if 50 < max(im.size) <= 80]
	smalls = [im for im in base if max(im.size) <= 50]
	bigs.sort(key=lambda im: -im.width * im.height)
	for im in bigs:
		place(im)
	for _rep in range(2):
		rnd.shuffle(mids)
		for im in mids:
			place(im)
	for _pass in range(40):
		rnd.shuffle(smalls)
		if not any([place(im) for im in smalls]):
			break
	print('   doodle : %d sprites posés' % n)
	return out


def capsule_fond_doodle(name='capsule_entete_920x430.png', dark=None):
	"""Le doodle couvre tout le papier (dans ses nuances, par-dessus le quadrillage) ; la toile, la tomate à
	moitié dessinée et le titre sont posés par-dessus, et les sprites se rangent autour d'eux."""
	import numpy as np
	global PAPER_DARK, PAPER_LIGHT
	if dark:
		PAPER_DARK, PAPER_LIGHT = dark
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	# le premier plan (chevalet, toile, tomate, titre) sur un calque à part
	front = Image.new('RGBA', (W, H), (0, 0, 0, 0))
	fd = ImageDraw.Draw(front)
	cx0, cy0, cx1, cy1 = 66, 62, 330, 300
	easel(front, fd, cx0, cy0, cx1, cy1, y1)
	sk, _tip = half_drawn(drawing('perso'), 10, 10)
	front.alpha_composite(sk, ((cx0 + cx1 - sk.width) // 2, (cy0 + cy1 - sk.height) // 2 + 6))
	lg = Image.open(os.path.join(ROOT, 'docs', 'logo_jeu_source.png')).convert('RGBA')
	lw = 500
	lg = lg.resize((lw, round(lg.height * lw / lg.width)), Image.NEAREST)
	front.alpha_composite(lg, (362, 50))
	# zone libre : le papier, moins le premier plan élargi de quelques pixels
	solid = np.array(front)[:, :, 3] > 0
	keep = np.zeros_like(solid)
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			keep |= np.roll(np.roll(solid, dy, 0), dx, 1)
	free = ~keep[y0 + 3:y1 - 2, x0 + 3:x1 - 2]
	dd = tinted(doodle_fill(free))
	img.paste(dd, (x0 + 3, y0 + 3), dd)
	# (les sprites restent DEVANT le quadrillage du papier)
	img.paste(front, (0, 0), front)
	img.save(os.path.join(DEST, name))


def capsule_doodle(tint=True, name='capsule_entete_920x430.png'):
	"""La tomate à moitié dessinée sur la toile, et sous le titre un doodle de tous les sprites."""
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	d = ImageDraw.Draw(img)
	cx0, cy0, cx1, cy1 = 66, 62, 330, 300
	easel(img, d, cx0, cy0, cx1, cy1, y1)
	sk, _tip = half_drawn(drawing('perso'), 10, 10)
	img.paste(sk, ((cx0 + cx1 - sk.width) // 2, (cy0 + cy1 - sk.height) // 2 + 6), sk)
	bottom = logo(img)
	zx0, zy0 = 356, bottom + 6
	dd = doodle(x1 - 4 - zx0, y1 - 4 - zy0)
	if tint:
		dd = tinted(dd)
	img.paste(dd, (zx0, zy0), dd)
	img.save(os.path.join(DEST, name))


def capsule_boss():
	"""La capsule retenue : la tomate à moitié dessinée sur la toile (sans crayon), deux boss sous le titre."""
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img, W, H)
	d = ImageDraw.Draw(img)
	cx0, cy0, cx1, cy1 = 66, 62, 330, 300
	easel(img, d, cx0, cy0, cx1, cy1, y1)
	sk, _tip = half_drawn(drawing('perso'), 10, 10)
	img.paste(sk, ((cx0 + cx1 - sk.width) // 2, (cy0 + cy1 - sk.height) // 2 + 6), sk)
	bottom = logo(img)
	# les deux boss sous le titre, dans les nuances du papier (comme un filigrane) : ça remplit sans alourdir
	bosses = [tinted(big(fit(drawing('boss_nuage'), 85), 1)), tinted(big(drawing('ennemi_sourire'), 2))]
	zone_x0, zone_x1 = 362, x1 - 8
	gap = (zone_x1 - zone_x0 - sum(b.width for b in bosses)) // 3
	x = zone_x0 + gap
	for b in bosses:
		y = bottom + (y1 - bottom - b.height) // 2
		img.paste(b, (x, y), b)
		x += b.width + gap
	img.save(os.path.join(DEST, 'capsule_entete_920x430.png'))


if __name__ == '__main__':
	capsule_fond_doodle('capsule_fond_doodle_clair.png', ((0xb9, 0xa5, 0x7c), (0xf3, 0xea, 0xd2)))
	capsule_fond_doodle('capsule_fond_doodle_fonce.png', ((0x9c, 0x86, 0x5c), (0xe2, 0xd3, 0xae)))
	titre_seul()
	titre_et_toile()
	idee_1()
	idee_3()
	idee_4()
	print('ok', DEST)
