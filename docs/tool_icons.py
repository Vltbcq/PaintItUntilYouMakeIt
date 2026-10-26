"""Icônes des outils de dessin (pinceau, gomme, formes, remplir...), en pixel art 16 × 16 dans la DA
du jeu : couleurs de la palette et contour d'encre d'1 pixel (comme le logo).

Usage : python docs/tool_icons.py [planche.png]
  - écrit les icônes dans assets/ui/tools/<nom>.png
  - avec un chemin : une planche d'aperçu (icônes agrandies sur des boutons du jeu)
(pip install pillow)
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 16
INK = (0x1a, 0x14, 0x23)
C = {
	'cream': (0xe9, 0xdc, 0xbc), 'white': (0xf4, 0xef, 0xe2), 'gold': (0xf0, 0xc4, 0x3a), 'gold_l': (0xfb, 0xe7, 0x9a),
	'gold_d': (0xb0, 0x7d, 0x1c), 'red': (0xd8, 0x43, 0x3b), 'red_d': (0x8c, 0x1f, 0x2a), 'blue': (0x3f, 0x7f, 0xd9),
	'blue_l': (0x8c, 0xc4, 0xf2), 'pink': (0xf0, 0x8a, 0xa4), 'pink_l': (0xf8, 0xc0, 0xcc), 'grey': (0xb8, 0xb8, 0xc8),
	'grey_d': (0x78, 0x78, 0x88), 'wood': (0xc0, 0x90, 0x5a), 'wood_d': (0x8a, 0x5a, 0x2a), 'green': (0x4f, 0xaa, 0x4c),
	'violet': (0x8c, 0x52, 0xc9),
}


class Icon:
	def __init__(self):
		self.px = {}
		self.outline = True

	def grid(self, rows, pal):
		"""Dessin pixel par pixel (1 caractère = 1 pixel, '.' = vide), contour déjà dessiné."""
		self.outline = False
		for y, row in enumerate(rows):
			for x, ch in enumerate(row):
				if ch in pal:
					self.set(x, y, pal[ch])

	def set(self, x, y, col):
		if 0 <= x < N and 0 <= y < N:
			self.px[(x, y)] = C[col] if isinstance(col, str) else col

	def rect(self, x0, y0, x1, y1, col):
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				self.set(x, y, col)

	def line(self, x0, y0, x1, y1, col, w=1):
		n = max(abs(x1 - x0), abs(y1 - y0), 1)
		for i in range(n + 1):
			x = round(x0 + (x1 - x0) * i / n)
			y = round(y0 + (y1 - y0) * i / n)
			for dx in range(w):
				for dy in range(w):
					self.set(x + dx, y + dy, col)

	def image(self):
		img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
		for (x, y), c in self.px.items():
			img.putpixel((x, y), c + (255,))
		if not self.outline:
			return img
		# contour d'encre d'1 pixel autour du dessin (comme le logo)
		out = img.copy()
		for y in range(N):
			for x in range(N):
				if img.getpixel((x, y))[3] > 0:
					continue
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					qx, qy = x + dx, y + dy
					if 0 <= qx < N and 0 <= qy < N and img.getpixel((qx, qy))[3] > 0 and img.getpixel((qx, qy))[:3] != INK:
						out.putpixel((x, y), INK + (255,))
						break
		return out


def brush():
	"""Pinceau court et trapu en diagonale : manche épais en bois orangé, grosse virole argentée,
	tête de poils rouge bombée qui finit en pointe (contour d'encre ajouté automatiquement)."""
	i = Icon()
	ax, ay, bx, by = 13.5, 2.5, 2.5, 13.5          # du bout du manche (en haut à droite) à la pointe
	ln = ((bx - ax) ** 2 + (by - ay) ** 2) ** 0.5
	ux, uy = (bx - ax) / ln, (by - ay) / ln
	for y in range(N):
		for x in range(N):
			px, py = x + 0.5 - ax, y + 0.5 - ay
			t = (px * ux + py * uy) / ln            # 0 = bout du manche, 1 = pointe
			d = px * uy - py * ux                   # côté (négatif : côté éclairé)
			if t < 0.0 or t > 1.0:
				continue
			if t < 0.36:
				w = 1.45
				col = (0xe0, 0x9a, 0x58) if d < -0.9 else ((0xc0, 0x6c, 0x34) if d < 0.7 else (0x8a, 0x44, 0x22))
			elif t < 0.52:
				w = 1.9
				col = 'white' if d < -0.9 else ('grey' if d < 0.7 else 'grey_d')
			else:
				k = (t - 0.52) / 0.48                # tête : bombée puis en pointe
				w = 2.5 * (1.0 - k) ** 0.75 + 0.35 if k > 0.1 else 2.1 + 0.4 * k / 0.1
				col = 'red' if d < -0.5 else 'red_d'
			if abs(d) <= w:
				i.set(x, y, col)
	return i


def eraser():
	i = Icon()
	i.rect(2, 6, 7, 11, 'pink')
	i.rect(2, 6, 7, 6, 'pink_l')
	i.rect(8, 6, 13, 11, 'blue_l')
	i.rect(8, 6, 13, 6, 'white')
	return i


def line():
	i = Icon()
	i.line(3, 12, 12, 3, 'gold', 2)
	i.rect(2, 12, 3, 13, 'red')
	i.rect(12, 2, 13, 3, 'red')
	return i


def rect():
	i = Icon()
	i.rect(2, 3, 13, 12, 'gold')
	i.rect(4, 5, 11, 10, 'gold_l')
	i.rect(5, 6, 10, 9, (0, 0, 0))       # (trou, effacé plus bas)
	for x in range(5, 11):
		for y in range(6, 10):
			i.px.pop((x, y), None)
	i.rect(2, 3, 13, 3, 'gold_l')
	return i


def ellipse():
	i = Icon()
	for y in range(N):
		for x in range(N):
			d = ((x - 7.5) / 6.0) ** 2 + ((y - 7.5) / 5.0) ** 2
			if 0.45 <= d <= 1.0:
				i.set(x, y, 'gold' if y > 6 else 'gold_l')
	return i


def fill():
	"""Seau de face qui déborde de peinture bleue : coulures sur le côté et flaque au pied."""
	i = Icon()
	i.grid([
		"................",
		"..kkkkkkkkkkk...",
		".kDBBBBBBBBBDk..",
		".kbBBBBBBBBBbkk.",
		".kbbbbbbbbbbbk.k",
		".kbgbggggbgGDk.k",
		".kbgbGgggbGGDk.k",
		".kggbGgggbGGDkk.",
		".kggbGggggGGDk..",
		".kggbGggggGGDk..",
		".kggbGgggGGGDk..",
		"..kgbGgggGGDk...",
		"..kkbkkkkkkkk...",
		".kbbBbbbbbbbbk..",
		"..kkkkkkkkkkk...",
		"................",
	], {'k': INK, 'g': (0xd8, 0xd8, 0xe2), 'G': (0xa8, 0xa8, 0xb8), 'D': (0x70, 0x70, 0x82),
		'b': (0x4c, 0xb8, 0xe0), 'B': (0xb0, 0xec, 0xfa)})
	return i


def select():
	i = Icon()
	for k in range(2, 14):
		c = 'white' if (k // 2) % 2 == 0 else 'grey_d'
		i.set(k, 2, c)
		i.set(k, 12, c)
		i.set(2, k if k <= 12 else 12, c)
		i.set(13, k if k <= 12 else 12, c)
	i.rect(8, 8, 9, 13, 'gold')          # petit curseur
	i.line(8, 8, 12, 12, 'gold')
	return i


def mirror():
	i = Icon()
	for y in range(1, 15, 3):            # axe de symétrie
		i.rect(7, y, 8, y + 1, 'red')
	for k in range(5):                   # deux moitiés en miroir
		i.line(5 - k, 4 + k, 5, 4 + k, 'blue')
		i.line(10, 4 + k, 10 + k, 4 + k, 'blue_l')
	return i


def triangle():
	"""Triangle isocèle parfaitement symétrique (axe entre les colonnes 7 et 8), bords de 2 px."""
	i = Icon()
	top, bot = 2, 13
	for y in range(top, bot + 1):
		k = round((y - top) * 6.0 / (bot - top))   # demi-largeur en plus
		lx, rx = 7 - k, 8 + k
		if y >= bot - 1:
			i.rect(lx, y, rx, y, 'gold')               # base pleine (2 lignes)
		else:
			i.rect(lx, y, min(lx + 1, rx), y, 'gold_l')  # bord gauche (clair)
			i.rect(max(rx - 1, lx), y, rx, y, 'gold')    # bord droit
	return i


def mirror_h():
	"""Symétrie haut / bas : axe horizontal, deux moitiés en miroir."""
	i = Icon()
	for x in range(1, 15, 3):            # axe de symétrie
		i.rect(x, 7, x + 1, 8, 'red')
	for k in range(4):                   # deux moitiés en miroir (pointes vers le haut / le bas)
		i.line(4 + k, 5 - k, 11 - k, 5 - k, 'blue')
		i.line(4 + k, 10 + k, 11 - k, 10 + k, 'blue_l')
	return i


def gradient():
	i = Icon()
	cols = ['red', (0xe8, 0x7a, 0x3a), (0xf0, 0xa0, 0x38), 'gold', 'gold_l']
	for k, c in enumerate(cols):
		i.rect(2 + k * 2 + (1 if k > 0 else 0), 5, 4 + k * 2, 10, c)
	i.rect(2, 5, 13, 10, 'red')
	for k, c in enumerate(cols):
		i.rect(2 + round(k * 12 / 5), 5, 1 + round((k + 1) * 12 / 5), 10, c)
	return i


def arrow(flip=False):
	i = Icon()
	pts = []
	# flèche courbe (vers la gauche) : arc + pointe
	for x in range(5, 12):
		pts.append((x, 5))
	for y in range(6, 11):
		pts.append((12, y))
	pts += [(11, 11), (10, 11)]
	for (x, y) in pts:
		i.set(x, y, 'gold')
		i.set(x, y + 1 if y == 5 else y, 'gold')
	i.rect(11, 5, 12, 11, 'gold')
	i.rect(5, 5, 11, 6, 'gold')
	for k in range(4):                   # pointe
		i.rect(1 + k, 6 - k, 1 + k, 5 + k, 'gold_l')
	i.rect(5, 2, 5, 9, 'gold_l')
	if flip:
		j = Icon()
		for (x, y), c in i.px.items():
			j.px[(N - 1 - x, y)] = c
		return j
	return i


def clear():
	i = Icon()
	# corbeille
	i.rect(3, 5, 12, 5, 'grey')
	i.rect(6, 3, 9, 4, 'grey_d')
	i.rect(4, 7, 11, 13, 'grey')
	for x in (6, 9):
		i.rect(x, 8, x, 12, 'grey_d')
	i.rect(4, 7, 11, 7, 'white')
	return i


def size(n):
	i = Icon()
	o = (N - 2 * n) // 2
	i.rect(o, o, o + 2 * n - 1, o + 2 * n - 1, 'cream')
	return i


ICONS = [
	("pinceau", "Pinceau", brush), ("gomme", "Gomme", eraser), ("ligne", "Ligne", line),
	("rect", "Rect.", rect), ("ellipse", "Ellipse", ellipse), ("remplir", "Remplir", fill),
	("selection", "Sélect.", select), ("symetrie", "Symétrie", mirror), ("symetrie_h", "Sym. haut/bas", mirror_h),
	("triangle", "Triangle", triangle), ("degrade", "Dégradé", gradient),
	("defaire", "Défaire", lambda: arrow(False)), ("refaire", "Refaire", lambda: arrow(True)),
	("effacer", "Tout effacer", clear), ("taille1", "1px", lambda: size(1)), ("taille2", "2px", lambda: size(2)),
	("taille3", "3px", lambda: size(3)),
]


def main():
	out_dir = os.path.join(ROOT, 'assets', 'ui', 'tools')
	icons = {}
	for key, label, fn in ICONS:
		icons[key] = fn().image()
	if len(sys.argv) > 1:
		sheet(icons, sys.argv[1])
	else:
		os.makedirs(out_dir, exist_ok=True)
		for key, img in icons.items():
			img.save(os.path.join(out_dir, key + '.png'))
		print('ok', len(icons), 'icônes dans', out_dir)


def sheet(icons, path):
	"""Planche d'aperçu : chaque icône ×4, puis sur un bouton du jeu (icône + texte), ×2."""
	cols = 5
	cw, ch = 220, 150
	rows = (len(ICONS) + cols - 1) // cols
	img = Image.new('RGB', (cols * cw, rows * ch), (0x3e, 0x18, 0x20))
	d = ImageDraw.Draw(img)
	font = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'YosterIsland.ttf'), 24)
	for k, (key, label, fn) in enumerate(ICONS):
		x0, y0 = (k % cols) * cw, (k // cols) * ch
		big = icons[key].resize((N * 4, N * 4), Image.NEAREST)
		img.paste(big, (x0 + (cw - N * 4) // 2, y0 + 8), big)
		# bouton du jeu (×2) : bois foncé, liseré laiton, icône + texte crème
		bx, by, bw, bh = x0 + 14, y0 + 84, cw - 28, 44
		d.rectangle([bx, by, bx + bw, by + bh], fill=(0x8c, 0x64, 0x14))
		d.rectangle([bx + 2, by + 2, bx + bw - 2, by + bh - 2], fill=(0x3a, 0x24, 0x18))
		ic = icons[key].resize((N * 2, N * 2), Image.NEAREST)
		img.paste(ic, (bx + 8, by + 6), ic)
		d.text((bx + 48, by + 9), label, font=font, fill=(0xe9, 0xdc, 0xbc))
	img.save(path)
	print('planche', path, img.size)


if __name__ == '__main__':
	main()
