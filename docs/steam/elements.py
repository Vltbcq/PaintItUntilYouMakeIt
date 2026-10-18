"""Les morceaux de la capsule « fond doodle », chacun dans son PNG (fond transparent quand il en faut un).

  fond_quadrille.png        le papier quadrillé seul (la taille de l'intérieur du cadre)
  fond_quadrille_1920.png   le même papier en 1920×1080 (même carreau)
  cadre_fond_vide.png       mur + cadre doré + papier quadrillé, sans doodle, sans titre, sans chevalet
  cadre_transparent.png     mur + cadre doré, l'intérieur transparent
  chevalet_tomate.png       le chevalet et la tomate à moitié dessinée, détourés
  chevalet.png              le chevalet seul, toile vierge
  (chaque image existe aussi en ×2 et ×4, agrandie au pixel près : suffixe _x2, _x4)

Usage : python docs/steam/elements.py [dossier de sortie]
"""
import os
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from capsules import OUT, PAPER, PAPER_LINE, frame, drawing, half_drawn
from maquettes import W, H, easel

DEST = sys.argv[1] if len(sys.argv) > 1 else OUT


def save(img, name):
	img.save(os.path.join(DEST, name + '.png'))
	for k in (2, 4):
		img.resize((img.width * k, img.height * k), Image.NEAREST).save(os.path.join(DEST, '%s_x%d.png' % (name, k)))


def grid(w, h):
	img = Image.new('RGB', (w, h), PAPER)
	d = ImageDraw.Draw(img)
	for x in range(20, w, 20):
		d.line([x, 0, x, h], fill=PAPER_LINE, width=2)
	for y in range(20, h, 20):
		d.line([0, y, w, y], fill=PAPER_LINE, width=2)
	return img


# Le cadre complet, papier vide
full = Image.new('RGB', (W, H))
x0, y0, x1, y1 = frame(full, W, H)
save(full, 'cadre_fond_vide')
# Le papier seul (exactement celui de l'intérieur du cadre)
save(full.crop((x0, y0, x1 + 1, y1 + 1)), 'fond_quadrille')
grid(1920, 1080).save(os.path.join(DEST, 'fond_quadrille_1920.png'))
# Le cadre, intérieur transparent
hole = full.convert('RGBA')
ImageDraw.Draw(hole).rectangle([x0, y0, x1, y1], fill=(0, 0, 0, 0))
save(hole, 'cadre_transparent')
# Le chevalet et la tomate, détourés (mêmes positions que dans la capsule, puis recadrés)
front = Image.new('RGBA', (W, H), (0, 0, 0, 0))
cx0, cy0, cx1, cy1 = 66, 62, 330, 300
easel(front, ImageDraw.Draw(front), cx0, cy0, cx1, cy1, y1)
sk, _tip = half_drawn(drawing('perso'), 10, 10)
front.alpha_composite(sk, ((cx0 + cx1 - sk.width) // 2, (cy0 + cy1 - sk.height) // 2 + 6))
save(front.crop(front.getbbox()), 'chevalet_tomate')
# Le chevalet seul (toile vierge, sans la tomate)
easel_only = Image.new('RGBA', (W, H), (0, 0, 0, 0))
easel(easel_only, ImageDraw.Draw(easel_only), cx0, cy0, cx1, cy1, y1)
save(easel_only.crop(easel_only.getbbox()), 'chevalet')
print('ok', DEST)
