"""Construit scripts/data/lang_en.gd à partir de docs/i18n/en.json, et dit ce qui manque.

    python docs/i18n/build.py            -> écrit lang_en.gd, liste les textes sans traduction
    python docs/i18n/build.py --todo F   -> écrit dans F les textes sans traduction (n° <tab> texte)
    python docs/i18n/build.py --take F G -> ajoute à en.json les traductions de G (n° <tab> anglais),
                                            numérotées comme dans F

Un texte traduit par lui-même (identique en anglais) se note "=" dans en.json.
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import ROOT, STR, displayable, files, strip_comment  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
JSON = os.path.join(HERE, 'en.json')
SKIP_FILES = {'scripts/core/loc.gd', 'scripts/data/lang_en.gd', 'scripts/data/lang_tables.gd'}


def all_texts():
    """Tous les textes affichables des scripts, dans l'ordre des fichiers, sans doublon."""
    seen = {}
    for rel in files():
        if rel in SKIP_FILES:
            continue
        for raw in io.open(os.path.join(ROOT, rel), encoding='utf-8'):
            raw = strip_comment(raw.rstrip('\n'))
            for m in STR.finditer(raw):
                s = m.group(1)
                # (tout ce qui est écrit dans Loc.t(...) compte, même un mot court comme "deux")
                in_loc = raw[:m.start()].endswith('Loc.t(')
                if (displayable(s) or (in_loc and s != '')) and s not in seen:
                    seen[s] = rel
    return seen


def load():
    return json.load(io.open(JSON, encoding='utf-8')) if os.path.exists(JSON) else {}


def save(d):
    with io.open(JSON, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(d, f, ensure_ascii=False, indent=0, sort_keys=True)


def gd(s):
    """Un littéral GDScript : les textes sont déjà écrits avec les échappements de GDScript."""
    out = []
    k = 0
    while k < len(s):
        if s[k] == '\\' and k + 1 < len(s):
            out.append(s[k:k + 2])
            k += 2
            continue
        out.append('\\"' if s[k] == '"' else s[k])   # (un guillemet nu dans une traduction)
        k += 1
    return '"' + ''.join(out) + '"'


if __name__ == '__main__':
    texts = all_texts()
    d = load()
    if '--take' in sys.argv:
        k = sys.argv.index('--take')
        todo = {}
        for line in io.open(sys.argv[k + 1], encoding='utf-8'):
            n, s = line.rstrip('\n').split('\t', 1)
            todo[n] = s
        got = 0
        for line in io.open(sys.argv[k + 2], encoding='utf-8'):
            line = line.rstrip('\n')
            if not line.strip():
                continue
            n, en = line.split('\t', 1) if '\t' in line else line.split('|', 1)
            assert n in todo, 'numéro inconnu : ' + n
            fr = todo[n]
            # mêmes marques de format des deux côtés
            import re
            marks = lambda x: sorted(re.findall(r'%[-+0-9.]*[dsf]|\{[a-z0-9_]+\}', x.replace('%%', '')))
            if en != '=' and marks(fr) != marks(en):
                print('FORMAT', n, '|', fr, '|', en)
            d[fr] = en
            got += 1
        save(d)
        print(got, 'traductions prises')
    missing = [s for s in texts if s not in d]
    if '--todo' in sys.argv:
        out = sys.argv[sys.argv.index('--todo') + 1]
        with io.open(out, 'w', encoding='utf-8', newline='\n') as f:
            for n, s in enumerate(missing):
                f.write('%d\t%s\n' % (n, s))
    with io.open(os.path.join(ROOT, 'scripts/data/lang_en.gd'), 'w', encoding='utf-8', newline='\n') as f:
        f.write('class_name LangEn\nextends RefCounted\n'
                '## Traduction anglaise. Fichier ÉCRIT PAR docs/i18n/build.py à partir de docs/i18n/en.json\n'
                '## (ne pas modifier à la main).\n\nconst D := {\n')
        for fr in sorted(d):
            if d[fr] != '=':   # (y compris les textes que l'inventaire ne repère pas : mots courts dans une table)
                f.write('\t%s: %s,\n' % (gd(fr), gd(d[fr])))
        f.write('}\n')
    print(len(texts), 'textes,', len(missing), 'sans traduction,', sum(1 for k in d if k not in texts), 'en trop dans en.json')
