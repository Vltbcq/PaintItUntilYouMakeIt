#!/usr/bin/env bash
# Lance les tests avant un push.
#   tests/run_tests.sh          : lot de base + tests liés à ce qui a changé depuis le dernier push
#   tests/run_tests.sh --all    : suite complète (avant une release)
#   tests/run_tests.sh --list   : affiche seulement les tests choisis (combinable avec --all)
# Godot : variable GODOT, sinon « godot » dans le PATH.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
export PAINTIT_LANG="${PAINTIT_LANG:-fr}"   # les tests lisent des textes français
BASE="checkall selftest flowtest savetest"
# Captures d'écran, bancs d'essai et simulations de réglage : jamais lancés automatiquement
skip() { case $1 in *shot*|hotkeys|*capture*|weaponbench|latesim|goldsim|familiardps) return 0;; esac; return 1; }

mode=auto
only_list=0
for a in "$@"; do
	[ "$a" = "--all" ] && mode=all
	[ "$a" = "--list" ] && only_list=1
done

if [ $mode = all ]; then
	picked=""
	for f in tests/*.tscn; do n=$(basename "$f" .tscn); skip "$n" || picked="$picked $n"; done
else
	up=${SINCE:-$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null || echo HEAD)}   # (SINCE=<commit> pour comparer à un autre point)
	changed=$( (git diff --name-only "$up"; git ls-files --others --exclude-standard) | sort -u)
	# Mots à chercher dans les tests : class_name des fichiers changés + fonctions / constantes touchées
	words=""
	for f in $changed; do
		case $f in tests/*) continue;; *.gd) ;; *) continue;; esac   # (un test modifié est choisi plus bas)
		[ -f "$f" ] || continue
		cn=$(sed -nE 's/^class_name[[:space:]]+([A-Za-z_0-9]+).*/\1/p' "$f" | head -1)
		[ -n "$cn" ] && words="$words $cn"
		words="$words $(git diff -U0 "$up" -- "$f" | sed -nE 's/^(@@.*@@[[:space:]]*|[+-])?(static[[:space:]]+)?(func|const)[[:space:]]+([A-Za-z_0-9]+).*/\4/p' | sort -u | tr '\n' ' ')"
	done
	picked="$BASE"
	for f in tests/*.tscn; do
		n=$(basename "$f" .tscn)
		skip "$n" && continue
		case " $picked " in *" $n "*) continue;; esac
		# test modifié lui-même
		if echo "$changed" | grep -qx "tests/$n.gd\|tests/$n.tscn"; then picked="$picked $n"; continue; fi
		for w in $words; do
			# fonctions appelées par Godot dans tous les scripts : elles ne disent rien
			case $w in _ready|_process|_physics_process|_draw|_input|_gui_input|_unhandled_input|_init|_notification|_enter_tree|_exit_tree) continue;; esac
			if grep -qw "$w" "tests/$n.gd" 2>/dev/null; then picked="$picked $n"; break; fi
		done
	done
	echo "Fichiers changés : $(echo $changed)"
fi

echo "Tests : $picked"
[ $only_list = 1 ] && exit 0
fails=0
for n in $picked; do
	out=$(timeout 300 "$GODOT" --headless --path . "res://tests/$n.tscn" 2>&1); rc=$?
	if [ $rc -ne 0 ] || echo "$out" | grep -q "SCRIPT ERROR\|Parse Error"; then
		echo "ÉCHEC $n ($rc)"; echo "$out" | grep -v "Unreferenced static string" | grep -i "échec\|error\|fail" | head -5
		fails=$((fails + 1))
	else
		echo "ok    $n"
	fi
done
echo "$fails échec(s)"
exit $fails
