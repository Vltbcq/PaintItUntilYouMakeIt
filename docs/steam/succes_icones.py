"""Maquettes des icônes de succès DÉBLOQUÉS (256 × 256) : le même cadre doré que l'icône verrouillée,
avec autre chose que le « ? » dedans. Une planche : 5 styles (lignes) × 5 succès d'exemple (colonnes).

Usage : python docs/steam/succes_icones.py <icône verrouillée 256 px> <dossier des dessins du Codex> <sortie.png>
"""
import os
import sys
from PIL import Image, ImageDraw

LOCKED, BESTIARY, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PAPER = (233, 220, 188)
IN0, IN1 = 32, 224                     # l'intérieur du cadre (papier), en pixels de l'icône
RARITY = {0: (230, 230, 230), 1: (90, 150, 240), 2: (170, 100, 230), 3: (240, 150, 50)}
INK = (26, 20, 35)


def drawing(key):
	im = Image.open(os.path.join(BESTIARY, key + '.png')).convert('RGBA')
	return im.crop(im.getbbox())


def stat_icon(name):
	im = Image.open(os.path.join(ROOT, 'assets', 'ui', 'stats', name + '.png')).convert('RGBA')
	return im.crop(im.getbbox())


def fit(im, box):
	"""Agrandi d'un facteur entier (pixels nets) pour tenir dans un carré de `box` px."""
	k = max(1, min(box // im.width, box // im.height))
	return im.resize((im.width * k, im.height * k), Image.NEAREST)


def base(paper=PAPER):
	ic = Image.open(LOCKED).convert('RGBA')
	ImageDraw.Draw(ic).rectangle([IN0, IN0, IN1 - 1, IN1 - 1], fill=paper)
	return ic


def center(ic, im, dy=0):
	ic.alpha_composite(im, ((256 - im.width) // 2, (256 - im.height) // 2 + dy))


# Succès d'exemple : (titre, dessins, rareté, texte du cartel)
EXEMPLES = [
	("Arme : Aérographe", ['arme_aerographe_r2'], 2, "+40 %"),
	("Familier : Luciole", ['familier_luciole'], 1, "LUCIOLE"),
	("Boss : Le Professeur", ['professeur'], 3, "VAGUE 10"),
	("Stat : 500 ennemis", None, 0, "500"),
	("Collection d'armes", ['arme_epee_r3', 'arme_marteau_r3', 'arme_arc_r3', 'arme_faux_r3'], 3, "15 / 15"),
]


def content(ex, box):
	title, keys, rar, _ = ex
	if keys is None:
		return fit(stat_icon('dmg'), box)
	if len(keys) == 1:
		return fit(drawing(keys[0]), box)
	# collection : une grille 2×2 de petits dessins
	cell = box // 2
	out = Image.new('RGBA', (box, box), (0, 0, 0, 0))
	for i, k in enumerate(keys[:4]):
		d = fit(drawing(k), cell - 6)
		out.alpha_composite(d, ((i % 2) * cell + (cell - d.width) // 2, (i // 2) * cell + (cell - d.height) // 2))
	return out


def style_dessin(ex):
	ic = base()
	center(ic, content(ex, 160))
	return ic


def style_vendu(ex):
	ic = style_dessin(ex)
	d = ImageDraw.Draw(ic)
	d.ellipse([186, 186, 214, 214], fill=(200, 40, 40), outline=INK, width=2)   # pastille rouge des galeries
	d.ellipse([193, 191, 201, 199], fill=(240, 120, 110))
	return ic


def style_rayons(ex):
	ic = base((246, 236, 205))
	d = ImageDraw.Draw(ic)
	import math
	for k in range(16):   # rayons dorés derrière le dessin
		a0, a1 = k * math.pi / 8, k * math.pi / 8 + math.pi / 16
		pts = [(128, 128), (128 + 160 * math.cos(a0), 128 + 160 * math.sin(a0)), (128 + 160 * math.cos(a1), 128 + 160 * math.sin(a1))]
		d.polygon(pts, fill=(240, 205, 110))
	ic2 = base()
	mask = Image.new('L', (256, 256), 0)
	ImageDraw.Draw(mask).rectangle([IN0, IN0, IN1 - 1, IN1 - 1], fill=255)
	ic2.paste(ic, (0, 0), mask)
	center(ic2, content(ex, 150))
	return ic2


def style_cartel(ex):
	ic = base()
	center(ic, content(ex, 128), -16)
	d = ImageDraw.Draw(ic)
	d.rectangle([60, 186, 196, 214], fill=(140, 100, 20))      # plaque en laiton
	d.rectangle([63, 189, 193, 211], fill=(240, 196, 58))
	try:
		from PIL import ImageFont
		f = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'YosterIsland.ttf'), 16)
	except Exception:
		f = None
	d.text((128, 200), ex[3], fill=INK, font=f, anchor='mm')
	return ic


def style_rarete(ex):
	c = RARITY[ex[2]]
	paper = tuple(round(PAPER[i] * 0.55 + c[i] * 0.45) for i in range(3))
	ic = base(paper)
	center(ic, content(ex, 160))
	return ic


STYLES = [("1. Le dessin seul", style_dessin), ("2. + pastille « vendu »", style_vendu),
	("3. Rayons dorés", style_rayons), ("4. + cartel en laiton", style_cartel), ("5. Fond couleur de rareté", style_rarete)]

S = 160   # taille d'une icône sur la planche
sheet = Image.new('RGB', (190 + len(EXEMPLES) * (S + 12), 34 + len(STYLES) * (S + 12)), (40, 30, 34))
d = ImageDraw.Draw(sheet)
from PIL import ImageFont
lf = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'YosterIsland.ttf'), 12)
for j, ex in enumerate(EXEMPLES):
	d.text((190 + j * (S + 12), 12), ex[0], fill=(240, 220, 160), font=lf)
for i, (name, fn) in enumerate(STYLES):
	d.text((10, 34 + i * (S + 12) + S // 2), name, fill=(240, 220, 160), font=lf)
	for j, ex in enumerate(EXEMPLES):
		ic = fn(ex).resize((S, S), Image.LANCZOS)
		sheet.paste(ic, (190 + j * (S + 12), 34 + i * (S + 12)))
sheet.save(OUT)
print('ok', OUT)
