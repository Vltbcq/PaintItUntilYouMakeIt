"""Prépare les scripts pour la traduction (à relancer sans risque : ne refait pas ce qui est fait).

  - chaque texte affiché écrit dans une fonction devient Loc.t("...")
  - chaque `const` de données qui contient du texte affiché devient `static var` et est listée
    dans scripts/data/lang_tables.gd (Loc.apply la réécrit dans la langue choisie)

    python docs/i18n/wrap.py [--dry]
"""
import io
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract import ROOT, STR, displayable, files, strip_comment  # noqa: E402

SKIP_FILES = {'scripts/core/loc.gd', 'scripts/data/lang_en.gd', 'scripts/data/lang_tables.gd'}
SKIP_LINE = re.compile(r'\b(print|printerr|push_error|push_warning|assert|print_rich|prints)\(|^\s*(@|class_name|extends|signal|enum)\b')
NOT_TABLES = {'BUS_MUSIC', 'BUS_SFX', 'SEED_DIGITS', 'STAT_WORDS', 'STAT_WORDS_EN'}   # (pas du texte affiché)
CONST = re.compile(r'^(\s*)(static\s+)?const\s+(\w+)')
TABLE = re.compile(r'^()(static\s+)var\s+(\w+)')   # une const déjà convertie (2e passage)
UNWRAP = re.compile(r'Loc\.t\(("(?:[^"\\]|\\.)*")\)')
MATCH_ARM = re.compile(r'^\s*"[^"]*"(\s*,\s*"[^"]*")*\s*:\s*$')


def depth_delta(line):
    bare = STR.sub('""', strip_comment(line))
    return sum(bare.count(c) for c in '([{') - sum(bare.count(c) for c in ')]}')


def wrap_line(raw):
    """Entoure de Loc.t les textes affichés de cette ligne de code."""
    code = strip_comment(raw.rstrip('\n'))
    tail = raw.rstrip('\n')[len(code):]
    if SKIP_LINE.search(code) or MATCH_ARM.match(code):
        return raw, 0
    out = []
    last = 0
    n = 0
    for m in STR.finditer(code):
        pre = code[:m.start()]
        if not displayable(m.group(1)) or pre.endswith('Loc.t(') or pre[-1:] in '&^$%r':
            continue
        out.append(code[last:m.start()] + 'Loc.t(' + m.group(0) + ')')
        last = m.end()
        n += 1
    out.append(code[last:])
    return ''.join(out) + tail + '\n', n


def process(rel, dry, known=()):
    path = os.path.join(ROOT, rel)
    lines = io.open(path, encoding='utf-8', newline='').read().split('\n')
    res = []
    tables = []
    wrapped = 0
    k = 0
    while k < len(lines):
        line = lines[k]
        m = CONST.match(strip_comment(line))
        again = None
        if not m:
            again = TABLE.match(strip_comment(line))
            if again and ('res://' + rel, again.group(3)) not in known:
                again = None
            m = again
        if not m:
            new, n = wrap_line(line + '\n')
            res.append(new[:-1])
            wrapped += n
            k += 1
            continue
        # une déclaration const, sur une ou plusieurs lignes
        block = [line]
        d = depth_delta(line)
        while (d > 0 or strip_comment(block[-1]).rstrip().endswith('\\')) and k + len(block) < len(lines):
            block.append(lines[k + len(block)])
            d += depth_delta(block[-1])
        if again:
            # table déjà convertie : ses textes ne passent PAS par Loc.t (Loc.apply la réécrit)
            res.extend(UNWRAP.sub(r'\1', b) for b in block)
            k += len(block)
            continue
        has_text = any(displayable(s.group(1)) for b in block for s in STR.finditer(strip_comment(b)))
        if has_text and m.group(3) not in NOT_TABLES:
            indent = m.group(1)
            if indent == '':
                block[0] = re.sub(r'^(static\s+)?const\s', 'static var ', block[0], count=1)
                tables.append(m.group(3))
            else:
                # const locale : une simple variable, et ses textes passent par Loc.t
                block[0] = re.sub(r'^(\s*)(static\s+)?const\s', r'\1var ', block[0], count=1)
                nb = []
                for b in block:
                    new, n = wrap_line(b + '\n')
                    nb.append(new[:-1])
                    wrapped += n
                block = nb
        res.extend(block)
        k += len(block)
    if not dry and res != lines:
        io.open(path, 'w', encoding='utf-8', newline='').write('\n'.join(res))
    return wrapped, tables


if __name__ == '__main__':
    dry = '--dry' in sys.argv
    tab_path = os.path.join(ROOT, 'scripts/data/lang_tables.gd')
    known = []
    if os.path.exists(tab_path):
        known = re.findall(r'\["(res://[^"]+)", "(\w+)"\]', io.open(tab_path, encoding='utf-8').read())
    known = [tuple(x) for x in known]
    tot = 0
    for rel in files():
        if rel in SKIP_FILES:
            continue
        w, tables = process(rel, dry, known)
        tot += w
        for t in tables:
            row = ('res://' + rel, t)
            if row not in known:
                known.append(row)
        if w or tables:
            print('%4d textes  %s  %s' % (w, rel, ' '.join(tables)))
    print('total', tot, '—', len(known), 'tables')
    if not dry:
        with io.open(tab_path, 'w', encoding='utf-8', newline='\n') as f:
            f.write('class_name LangTables\nextends RefCounted\n'
                    '## Tables de données qui contiennent du texte affiché : Loc.apply les réécrit dans la langue\n'
                    '## choisie. Fichier ÉCRIT PAR docs/i18n/wrap.py (ne pas modifier à la main).\n\n'
                    'const LIST := [\n')
            for p, t in sorted(known):
                f.write('\t["%s", "%s"],\n' % (p, t))
            f.write(']\n')
