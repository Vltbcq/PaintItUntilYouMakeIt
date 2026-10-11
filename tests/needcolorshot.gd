extends Node
## Capture : choix d'un dessin d'ennemi avec une COULEUR IMPOSÉE (pastille en haut, pastilles
## sur les vignettes, dessins de la mauvaise couleur grisés). Lit la vraie galerie sans rien écrire.
## Godot --path . res://tests/needcolorshot.tscn -- <capture.png> [élément] [pick] [arme]


func _ready() -> void:
	Meta.no_save = true
	Meta.data = Meta.data.duplicate(true)
	Meta.settings = Meta.settings.duplicate()
	Meta.settings.tips = false
	var args := OS.get_cmdline_user_args()
	var cfg := DrawCfg.enemy("tache")
	if "arme" in args:
		# [arme] : choix du dessin d'une arme achetée (l'élément principal de chaque dessin s'affiche)
		cfg = DrawCfg.weapon("epee", 0)
	else:
		cfg.need_el = int(args[1]) if args.size() > 1 else 4
	var p := BestiaryPrompt.new(cfg, null)
	p.size = Vector2(640, 360)
	add_child(p)
	await get_tree().process_frame
	if args.size() > 2 and not p.gallery_btns.is_empty():
		# [pick] : sélectionne le dernier dessin (le moins utilisable) pour voir le bouton grisé
		(p.gallery_btns.back() as Button).pressed.emit()
		print("RAISON : ", p.keep_btn.tooltip_text, " / utilisable : ", not p.keep_btn.disabled, " / modifier : ", not p.mod_btn.disabled)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[0])
	get_tree().quit()
