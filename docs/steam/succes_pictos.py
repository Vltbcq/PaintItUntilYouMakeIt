"""Maquettes d'icônes de succès DÉBLOQUÉS sans les dessins du Codex : le cadre doré de l'icône verrouillée,
avec un pictogramme par catégorie (dessiné ici, en pixel art 16×16). 4 styles × 6 catégories.

Usage : python docs/steam/succes_pictos.py <icône verrouillée 256 px> <sortie.png>
"""
import math
import os
import random
import sys
from PIL import Image, ImageDraw, ImageFont

LOCKED, OUT = sys.argv[1], sys.argv[2]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PAPER = (233, 220, 188)
INK = (26, 20, 35)
IN0, IN1 = 32, 224

# Pictogrammes 16×16 (# = encre, + = couleur d'accent, . = vide)
PICTOS = {
	"Arme": [
		"............##..", "...........#++#.", "..........#++#..", ".........#++#...",
		"........#++#....", ".......#++#.....", "......#++#......", "..##.#++#.......",
		"..#+#++#........", "...#+##.........", "...##+#.........", "..#..#+#........",
		".#.....##.......", "#.#.............", ".#..............", "................"],
	"Amulette": [
		"....########....", "...#........#...", "..#..........#..", "..#..........#..",
		"...#........#...", "....#......#....", ".....#....#.....", "......####......",
		".....#++++#.....", "....#++++++#....", "....#+++#++#....", "....#++++++#....",
		".....#++++#.....", "......#++#......", ".......##.......", "................"],
	"Familier": [
		"................", "...##......##...", "..#++#....#++#..", "..#++#....#++#..",
		"...##..##..##...", "......#++#......", "......#++#......", ".......##.......",
		".....######.....", "....#++++++#....", "...#++++++++#...", "...#++++++++#...",
		"...#++++++++#...", "....#++++++#....", ".....######.....", "................"],
	"Boss": [
		"................", "..#....##....#..", "..##..#++#..##..", "..#+##++++##+#..",
		"..#++++++++++#..", "..############..", "................", "...##########...",
		"..#..........#..", "..#.##....##.#..", "..#.##....##.#..", "..#....##....#..",
		"...#........#...", "....#.#.#.#.#...", ".....########...", "................"],
	"Stat": [
		"................", "......####......", "....##++++##....", "...#++++++++#...",
		"..#+++####+++#..", "..#++#....#++#..", ".#++#......#++#.", ".#++#......#++#.",
		".#++#......#++#.", ".#++#......#++#.", "..#++#....#++#..", "..#+++####+++#..",
		"...#++++++++#...", "....##++++##....", "......####......", "................"],
	"Collection": [
		"................", ".##########.....", ".#++++++++#.....", ".#++++++++#.....",
		".#++++++++###...", ".#++++++++#+#...", ".##########+###.", "...#+++++++#+#..",
		"...###########+#", ".....#++++++++#.", ".....#++++++++#.", ".....#++++++++#.",
		".....#++++++++#.", ".....##########.", "................", "................"],
}
ACCENT = {"Arme": (90, 150, 240), "Amulette": (230, 70, 80), "Familier": (240, 170, 70),
	"Boss": (240, 196, 58), "Stat": (110, 200, 120), "Collection": (170, 100, 230)}


def picto(name, k, ink=INK, accent=None):
	rows = PICTOS[name]
	acc = accent or ACCENT[name]
	im = Image.new('RGBA', (16 * k, 16 * k), (0, 0, 0, 0))
	d = ImageDraw.Draw(im)
	for y, row in enumerate(rows):
		for x, ch in enumerate(row):
			if ch == '#':
				d.rectangle([x * k, y * k, x * k + k - 1, y * k + k - 1], fill=ink)
			elif ch == '+':
				d.rectangle([x * k, y * k, x * k + k - 1, y * k + k - 1], fill=acc)
	return im


def base(paper=PAPER):
	ic = Image.open(LOCKED).convert('RGBA')
	ImageDraw.Draw(ic).rectangle([IN0, IN0, IN1 - 1, IN1 - 1], fill=paper)
	return ic


def center(ic, im):
	ic.alpha_composite(im, ((256 - im.width) // 2, (256 - im.height) // 2))


def clip_inside(ic, layer):
	mask = Image.new('L', (256, 256), 0)
	ImageDraw.Draw(mask).rectangle([IN0, IN0, IN1 - 1, IN1 - 1], fill=255)
	ic.paste(layer, (0, 0), Image.composite(layer.split()[3], Image.new('L', (256, 256), 0), mask))


# 1. Pictogramme encre et couleur, sur le papier
def s_picto(name):
	ic = base()
	center(ic, picto(name, 10))
	return ic


# 2. Coche peinte, la même pour tous les succès (en pixels, comme le « ? »)
CHECK = ["................", "................", "..............##", ".............###",
	"............###.", "...........###..", "..........###...", ".##......###....",
	".###....###.....", "..###..###......", "...######.......", "....####........",
	".....##.........", "................", "................", "................"]


def s_coche(name):
	ic = base()
	PICTOS["_c"] = CHECK
	center(ic, picto("_c", 11, ink=INK, accent=INK))
	return ic


# 3. Tache de peinture de la couleur de la catégorie, pictogramme en crème dessus
def s_tache(name):
	ic = base()
	rnd = random.Random(hash(name) & 0xffff)
	layer = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)
	col = ACCENT[name] + (255,)
	pts = []
	for i in range(18):
		a = i * math.tau / 18
		r = 78 + rnd.uniform(-10, 14)
		pts.append((128 + r * math.cos(a), 128 + r * math.sin(a)))
	d.polygon(pts, fill=col)
	for _ in range(6):   # éclaboussures
		a = rnd.uniform(0, math.tau)
		r = rnd.uniform(86, 100)
		s = rnd.uniform(5, 10)
		x, y = 128 + r * math.cos(a), 128 + r * math.sin(a)
		d.ellipse([x - s, y - s, x + s, y + s], fill=col)
	clip_inside(ic, layer)
	center(ic, picto(name, 8, ink=INK, accent=(246, 238, 216)))
	return ic


# 4. Tampon d'encre rouge, légèrement penché
def s_tampon(name):
	ic = base()
	red = (190, 40, 45, 255)
	layer = Image.new('RGBA', (256, 256), (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)
	d.ellipse([46, 46, 210, 210], outline=red, width=10)
	d.ellipse([62, 62, 194, 194], outline=red, width=3)
	p = picto(name, 6, ink=red[:3], accent=red[:3])
	layer.alpha_composite(p, ((256 - p.width) // 2, (256 - p.height) // 2))
	layer = layer.rotate(-12, resample=Image.NEAREST, center=(128, 128))
	clip_inside(ic, layer)
	return ic


STYLES = [("1. Pictogramme", s_picto), ("2. Coche peinte (la même partout)", s_coche),
	("3. Tache de peinture + picto", s_tache), ("4. Tampon d'encre", s_tampon)]
CATS = ["Arme", "Amulette", "Familier", "Boss", "Stat", "Collection"]

S = 150
lf = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'YosterIsland.ttf'), 12)
sheet = Image.new('RGB', (230 + len(CATS) * (S + 12), 34 + len(STYLES) * (S + 12)), (40, 30, 34))
d = ImageDraw.Draw(sheet)
for j, c in enumerate(CATS):
	d.text((230 + j * (S + 12), 12), c, fill=(240, 220, 160), font=lf)
for i, (label, fn) in enumerate(STYLES):
	d.text((10, 34 + i * (S + 12) + S // 2), label, fill=(240, 220, 160), font=lf)
	for j, c in enumerate(CATS):
		sheet.paste(fn(c).resize((S, S), Image.LANCZOS), (230 + j * (S + 12), 34 + i * (S + 12)))
sheet.save(OUT)
print('ok', OUT)
