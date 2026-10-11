"""Inventaire des textes du jeu (français, écrits en dur dans les scripts).

    python docs/i18n/extract.py            -> résumé par fichier
    python docs/i18n/extract.py --dump F   -> écrit toutes les occurrences dans F (tsv)

Une « occurrence » = un littéral de chaîne qui ressemble à du texte affiché. On note son contexte :
  const : dans une déclaration const (données : traduit là où c'est lu)
  code  : dans une fonction (à passer par Loc.t)
"""
import glob
import io
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
ACCENT = re.compile(r'[éèêëàâçîïôöûùüœÉÈÀÇÊÔ«»…]')
WORD = re.compile(r'[A-Za-zéèêàâçîôûùœ]{2,}')


def files():
    out = []
    for f in glob.glob(os.path.join(ROOT, 'scripts', '**', '*.gd'), recursive=True):
        rel = os.path.relpath(f, ROOT).replace(os.sep, '/')
        if rel.startswith('scripts/dev/') or rel.startswith('scripts/data/lang_'):
            continue
        out.append(rel)
    return sorted(out)


def displayable(s):
    """Le littéral ressemble-t-il à du texte montré au joueur ?"""
    if not WORD.search(s):
        return False
    if s.startswith(('res://', 'user://', 'uid://')) or s.endswith(('.png', '.ogg', '.tscn', '.gd', '.json')):
        return False
    if re.fullmatch(r'[a-z0-9_:#./%-]+', s):          # identifiant, clé, chemin
        return False
    if re.fullmatch(r'[A-Za-z0-9_]+', s) and not ACCENT.search(s):
        # un seul mot sans accent : affiché seulement s'il commence par une majuscule (« Retour »)
        return s[0].isupper() and not s.isupper() or (s.isupper() and len(s) > 2)
    return True


def strip_comment(line):
    """Retire le commentaire de fin de ligne (hors chaînes)."""
    out = []
    in_s = False
    k = 0
    while k < len(line):
        c = line[k]
        if in_s:
            out.append(c)
            if c == '\\' and k + 1 < len(line):
                out.append(line[k + 1])
                k += 1
            elif c == '"':
                in_s = False
        else:
            if c == '#':
                break
            out.append(c)
            if c == '"':
                in_s = True
        k += 1
    return ''.join(out)


def occurrences(rel):
    """[(ligne, contexte, littéral, texte de la ligne)]"""
    res = []
    in_const = False
    depth = 0
    for n, raw in enumerate(io.open(os.path.join(ROOT, rel), encoding='utf-8'), 1):
        line = strip_comment(raw.rstrip('\n'))
        st = line.strip()
        if depth <= 0:
            in_const = bool(re.match(r'(static\s+)?const\s', st))
            depth = 0
        ctx = 'const' if in_const else 'code'
        for m in STR.finditer(line):
            if displayable(m.group(1)):
                res.append((n, ctx, m.group(1), st))
        bare = STR.sub('""', line)
        depth += bare.count('[') + bare.count('{') + bare.count('(') - bare.count(']') - bare.count('}') - bare.count(')')
        if in_const and depth <= 0 and not st.endswith('\\'):
            in_const = False if depth <= 0 and n and not st.endswith(',') else in_const
    return res


if __name__ == '__main__':
    tot = {'const': 0, 'code': 0}
    uniq = set()
    rows = []
    for rel in files():
        occ = occurrences(rel)
        c = sum(1 for o in occ if o[1] == 'const')
        tot['const'] += c
        tot['code'] += len(occ) - c
        for o in occ:
            uniq.add(o[2])
            rows.append((rel,) + o)
        if '--dump' not in sys.argv and occ:
            print('%4d const %4d code  %s' % (c, len(occ) - c, rel))
    print('total', tot, 'uniques', len(uniq))
    if '--dump' in sys.argv:
        out = sys.argv[sys.argv.index('--dump') + 1]
        with io.open(out, 'w', encoding='utf-8') as f:
            for r in rows:
                f.write('%s\t%d\t%s\t%s\t%s\n' % r)
