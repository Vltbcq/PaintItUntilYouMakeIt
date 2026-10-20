"""Capsules Steam « fond doodle clair », recomposées à leur taille plutôt qu'agrandies (le pixel art reste net) :
cadre doré, papier quadrillé couvert du doodle beige, la tomate à moitié dessinée sur son chevalet, le titre.

  capsule_principale_1232x706   titre à droite, chevalet à gauche
  capsule_verticale_748x896     titre en haut, chevalet en dessous
  bibliotheque_*                capsule 600×900, entête 920×430, bannière 3840×1240 (sans texte), logo 1280 px

Usage : python docs/steam/capsule_principale.py [dossier de sortie]
"""
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import maquettes
from capsules import ROOT, OUT, WALL, WALL_LINE, GOLD, GOLD_D, GOLD_L, PAPER, PAPER_LINE, drawing, half_drawn
from maquettes import easel, tinted, doodle_fill

DEST = sys.argv[1] if len(sys.argv) > 1 else OUT
maquettes.PAPER_DARK, maquettes.PAPER_LIGHT = (0xb9, 0xa5, 0x7c), (0xf3, 0xea, 0xd2)   # (les nuances « clair »)


def frame(img):
	"""Le mur rayé et le cadre doré de la capsule d'entête, en un peu plus épais (même proportion)."""
	W, H = img.size
	d = ImageDraw.Draw(img)
	for x in range(0, W, 20):
		d.rectangle([x, 0, x + 6, H], fill=WALL_LINE)
	m = 18
	d.rectangle([m, m, W - m - 1, H - m - 1], fill=GOLD_D)
	d.rectangle([m + 5, m + 5, W - m - 6, H - m - 6], fill=GOLD)
	d.rectangle([m + 5, m + 5, W - m - 6, m + 10], fill=GOLD_L)
	d.rectangle([m + 5, m + 5, m + 10, H - m - 6], fill=GOLD_L)
	d.rectangle([m + 24, m + 24, W - m - 25, H - m - 25], fill=GOLD_D)
	x0, y0, x1, y1 = m + 29, m + 29, W - m - 30, H - m - 30
	d.rectangle([x0, y0, x1, y1], fill=PAPER)
	for x in range(x0 + 20, x1, 20):
		d.line([x, y0, x, y1], fill=PAPER_LINE, width=2)
	for y in range(y0 + 20, y1, 20):
		d.line([x0, y, x1, y], fill=PAPER_LINE, width=2)
	return x0, y0, x1, y1


def paper(img):
	"""Sans cadre : le papier quadrillé jusqu'aux bords (bannière de la bibliothèque)."""
	W, H = img.size
	d = ImageDraw.Draw(img)
	d.rectangle([0, 0, W, H], fill=PAPER)
	for x in range(20, W, 20):
		d.line([x, 0, x, H], fill=PAPER_LINE, width=2)
	for y in range(20, H, 20):
		d.line([0, y, W, y], fill=PAPER_LINE, width=2)
	return -3, -3, W + 1, H + 1


def compose(W, H, name, canvas, k, logo_w, logo_pos, framed=True, up=1):
	"""canvas = (cx0, cy0, cx1, cy1) de la toile ; k = taille d'un pixel de la tomate ;
	logo_pos(x0, y0, x1, y1, logo) -> position du titre (logo_w = 0 : pas de titre) ;
	framed = False : pas de mur ni de cadre ; up = agrandissement final au pixel près."""
	img = Image.new('RGB', (W, H), WALL)
	x0, y0, x1, y1 = frame(img) if framed else paper(img)
	# Premier plan (chevalet, toile, tomate, titre) sur un calque à part
	front = Image.new('RGBA', (W, H), (0, 0, 0, 0))
	cx0, cy0, cx1, cy1 = canvas
	easel(front, ImageDraw.Draw(front), cx0, cy0, cx1, cy1, y1)
	sk, _tip = half_drawn(drawing('perso'), 10, k)
	front.alpha_composite(sk, ((cx0 + cx1 - sk.width) // 2, (cy0 + cy1 - sk.height) // 2 + 8))
	if logo_w > 0:
		lg = Image.open(os.path.join(ROOT, 'docs', 'logo_jeu_source.png')).convert('RGBA')
		lg = lg.resize((logo_w, round(lg.height * logo_w / lg.width)), Image.NEAREST)
		front.alpha_composite(lg, logo_pos(x0, y0, x1, y1, lg))
	# Le doodle couvre TOUT le papier, régulièrement : il passe derrière le titre et la toile
	free = np.ones((y1 - 2 - (y0 + 3), x1 - 2 - (x0 + 3)), dtype=bool)
	dd = tinted(doodle_fill(free))
	img.paste(dd, (x0 + 3, y0 + 3), dd)
	img.paste(front, (0, 0), front)
	if up > 1:
		img = img.resize((W * up, H * up), Image.NEAREST)
	img.save(os.path.join(DEST, name + '.png'))
	img.save(os.path.join(DEST, name + '.jpg'), quality=95)


if __name__ == '__main__':
	which = sys.argv[2] if len(sys.argv) > 2 else 'tout'
	if which in ('tout', 'principale'):
		compose(1232, 706, 'capsule_principale_1232x706', (104, 96, 484, 476), 14, 640,
			lambda x0, y0, x1, y1, lg: (528, (y0 + y1 - lg.height) // 2 - 10))
	if which in ('tout', 'verticale'):
		# Titre en haut, la toile en dessous, centrés
		compose(748, 896, 'capsule_verticale_748x896', (184, 290, 564, 670), 14, 600,
			lambda x0, y0, x1, y1, lg: ((748 - lg.width) // 2, y0 + 40))
	# --- Bibliothèque Steam
	if which in ('tout', 'bibliotheque'):
		# Capsule de la bibliothèque : titre en haut, la toile en dessous
		compose(600, 900, 'bibliotheque_capsule_600x900', (130, 300, 470, 640), 12, 500,
			lambda x0, y0, x1, y1, lg: ((600 - lg.width) // 2, y0 + 50))
		# Entête de la bibliothèque : la composition de la capsule d'entête
		compose(920, 430, 'bibliotheque_entete_920x430', (76, 66, 336, 326), 10, 500,
			lambda x0, y0, x1, y1, lg: (378, (y0 + y1 - lg.height) // 2 - 6))
		# Bannière : le cadre doré, papier + doodle, la tomate au centre (zone de sécurité 860×380),
		# aucun texte ; dessinée à 1920×620 puis agrandie ×2
		compose(1920, 620, 'bibliotheque_banniere_3840x1240', (868, 212, 1052, 396), 7, 0, None, up=2)
		# Logo : 1280 px de large, fond transparent
		lg = Image.open(os.path.join(ROOT, 'docs', 'logo_jeu_source.png')).convert('RGBA')
		lg.resize((1280, round(lg.height * 1280 / lg.width)), Image.LANCZOS).save(os.path.join(DEST, 'bibliotheque_logo_1280.png'))
	print('ok', DEST)
