extends Node
## Test : les musiques (menus / entre les vagues / vagues) se chargent et changent avec un fondu.

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("OK   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _playing() -> String:
	for mp in Sfx.music_players:
		if mp.playing and mp.stream:
			return mp.stream.resource_path.get_file()
	return ""


func _ready() -> void:
	Meta.no_save = true
	for id in Sfx.MUSIC:
		_check(ResourceLoader.exists(Sfx.MUSIC[id]), "musique « %s » présente" % id)
	Sfx.music("menu")
	await get_tree().process_frame
	_check(_playing() == "Bozos-Arcade.ogg", "menus : Bozos Arcade (%s)" % _playing())
	_check((Sfx.music_players[Sfx._music_i].stream as AudioStreamOggVorbis).loop, "elle tourne en boucle")
	Sfx.music("vague")
	await get_tree().create_timer(1.2).timeout
	_check(_playing() == "Pixel-City-Cruising.ogg", "vagues : Pixel City Cruising, l'ancienne s'est arrêtée (%s)" % _playing())
	Sfx.music("boss")
	await get_tree().create_timer(1.2).timeout
	_check(_playing() == "Backup-Plan.ogg", "vagues de boss : Backup Plan (%s)" % _playing())
	Sfx.music("transition")
	await get_tree().create_timer(1.2).timeout
	_check(_playing() == "Bumbling-Burglars_Looping.ogg", "entre les vagues : Bumbling Burglars (%s)" % _playing())
	print("MUSIQUE : %d échec(s)" % fails)
	get_tree().quit(1 if fails else 0)
