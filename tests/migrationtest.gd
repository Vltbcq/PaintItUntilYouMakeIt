extends Node
## Migration de la sauvegarde (renommage du jeu) et écriture sûre (.tmp puis renommage, .bak).
## Tout se passe dans un dossier temporaire : la vraie sauvegarde n'est jamais touchée.

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _ready() -> void:
	var tmp := OS.get_temp_dir().path_join("paintit_migrationtest")
	_rm(tmp)
	var old := tmp.path_join("VowelGame")
	var new := tmp.path_join("PaintItUntilYouMakeIt")
	_write(old.path_join("vowel_save.json"), '{"pigments": 42}')
	_write(old.path_join("gallery/a.png"), "png")
	_write(old.path_join("slot2/vowel_save.json"), '{"pigments": 7}')
	_write(old.path_join("logs/godot.log"), "log")
	_write(new.path_join("logs/godot.log"), "log du nouveau dossier")   # (Godot crée ses logs avant tout)

	# 1. recopie de l'ancien dossier (sans les logs), l'ancien reste intact
	Meta.migrate_old_dir(old, new)
	_check(FileAccess.file_exists(new.path_join("vowel_save.json")) and FileAccess.file_exists(new.path_join("gallery/a.png"))
		and FileAccess.file_exists(new.path_join("slot2/vowel_save.json")), "migration : sauvegarde, galerie et emplacement 2 recopiés")
	_check(FileAccess.get_file_as_string(new.path_join("logs/godot.log")) == "log du nouveau dossier", "migration : les logs ne sont pas recopiés")
	_check(FileAccess.file_exists(old.path_join("vowel_save.json")), "migration : l'ancien dossier reste en place")

	# 2. une seconde fois : le nouveau dossier a déjà une sauvegarde, rien n'est écrasé
	_write(new.path_join("vowel_save.json"), '{"pigments": 99}')
	Meta.migrate_old_dir(old, new)
	_check(FileAccess.get_file_as_string(new.path_join("vowel_save.json")).contains("99"), "migration : jamais par-dessus une sauvegarde existante")

	# 3. vowel_save.json -> save.json dans chaque emplacement
	var root0: String = Meta.root
	Meta.root = new + "/"
	Meta._rename_legacy_saves()
	_check(FileAccess.file_exists(Meta.save_path(1)) and FileAccess.file_exists(Meta.save_path(2))
		and not FileAccess.file_exists(new.path_join("vowel_save.json")), "save.json à la place de vowel_save.json (emplacements 1 et 2)")

	# 4. écriture sûre : l'ancienne version reste en .bak ; un save.json abîmé est rattrapé par le .bak
	Meta._store(Meta.save_path(1), '{"pigments": 100}')
	_check(FileAccess.get_file_as_string(Meta.save_path(1) + ".bak").contains("99") and not FileAccess.file_exists(Meta.save_path(1) + ".tmp"),
		"écriture sûre : la version d'avant est gardée en .bak, pas de .tmp qui traîne")
	_write(Meta.save_path(1), '{"pigments": 1')   # coupure en pleine écriture
	_check(int(Meta._read_json(Meta.save_path(1)).get("pigments", -1)) == 99, "save.json illisible : on relit la version .bak")
	Meta.root = root0
	_rm(tmp)
	print("MIGRATION : %d échec(s)" % fails)
	get_tree().quit()


func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for s in d.get_directories():
		_rm(dir.path_join(s))
	DirAccess.remove_absolute(dir)
