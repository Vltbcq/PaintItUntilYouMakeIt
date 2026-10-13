extends Node
## Taille du perso : PV, vitesse et armure selon le nombre de pixels (courbe adoucie en v0.13).
## Godot --headless --path . res://tests/charsizetest.tscn

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _part(px: int) -> Dictionary:
	return Stats.character_part({"pixels": px, "sym": 0.0, "solidity": 0.0, "components": 1, "bh": 10, "bw": 10,
		"frac": [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}, "")


func _speed(px: int) -> float:
	return float(_part(px).speed_base) / 150.0


func _ready() -> void:
	Meta.no_save = true
	# Les petits persos ne perdent rien : même vitesse qu'avant sous ~190 pixels
	for px in [20, 50, 100, 150, 180]:
		_check(is_equal_approx(_speed(px), clampf(1.4 - px / 650.0, 0.5, 1.35)), "%d px : même vitesse qu'avant (×%.2f)" % [px, _speed(px)])
	# Les gros vont plus vite qu'avant : -10 points par 100 pixels, plancher à ×0,6 vers 700 pixels
	_check(absf(_speed(400) - 0.90) < 0.001, "400 px : ×0,90 (avant ×0,78)")
	_check(absf(_speed(500) - 0.80) < 0.001, "500 px : ×0,80 (avant ×0,63)")
	_check(absf(_speed(700) - 0.60) < 0.001 and absf(_speed(1500) - 0.60) < 0.001, "plancher à ×0,60 à partir de 700 px")
	var mono := true
	for px in range(10, 1000, 10):
		mono = mono and _speed(px) <= _speed(px - 10) + 0.0001
	_check(mono, "la vitesse ne remonte jamais quand le perso grossit")
	# Armure des gros persos : +1 par 100 pixels au-delà de 200, 5 au plus
	_check(int(_part(200).armor) == 0 and int(_part(299).armor) == 0, "pas d'armure de taille jusqu'à 299 px")
	_check(int(_part(300).armor) == 1 and int(_part(450).armor) == 2 and int(_part(700).armor) == 5 and int(_part(2000).armor) == 5, "armure : 300 px = 1, 450 px = 2, 700 px = 5, jamais plus de 5")
	_check(is_equal_approx(_part(400).max_hp, 26.0), "les PV ne changent pas (400 px = 26)")
	print("CHARSIZE : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
