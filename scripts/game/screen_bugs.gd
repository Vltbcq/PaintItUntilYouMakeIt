class_name ScreenBugs
extends Node
## Les BUGS de L'Écran (carte 3). Un seul système pour deux usages :
## - la règle de la carte : de temps en temps pendant une vague, un bug LÉGER (surtout visuel,
##   court, jamais mortel à lui seul), un seul à la fois, annoncé par un grésillement ;
## - le boss « Le Bug » : il lance les GROS bugs (commandes inversées, écran à l'envers, retour en
##   arrière, barre de vie folle), annoncés 1 s avant.
## L'arène appelle tick(delta) ; les effets sont lus par le joueur, le HUD et la caméra.

## Bugs légers : durée (s)
const LIGHT := {"freeze": 0.5, "invert": 4.0, "shift": 4.0, "trail": 5.0}
## Gros bugs (boss) : durée (s)
const HEAVY := {"controls": 4.0, "flip": 4.0, "rewind": 0.1, "fakehp": 5.0}
const NAMES := {"freeze": "IMAGE FIGÉE", "invert": "COULEURS INVERSÉES", "shift": "IMAGE DÉCALÉE", "trail": "TRAÎNÉE",
	"controls": "COMMANDES INVERSÉES", "flip": "ÉCRAN À L'ENVERS", "rewind": "RETOUR EN ARRIÈRE", "fakehp": "BARRE DE VIE FOLLE"}
const WARN_LIGHT := 0.5    # grésillement avant un bug léger
const WARN_HEAVY := 1.0    # annonce avant un gros bug
const REWIND_SEC := 1.5    # « retour en arrière » : le joueur revient où il était 1,5 s plus tôt

var arena: Arena
var auto := false           # règle de la carte : des bugs légers tombent tout seuls
var cd := 8.0               # prochain bug automatique
var active := {}            # bug en cours -> secondes restantes
var pending := {}           # bug annoncé -> secondes avant qu'il démarre
var last := ""              # dernier bug léger (jamais deux fois de suite)
var rect: ColorRect         # rectangle plein écran qui porte le shader
var mat: ShaderMaterial
var frozen: TextureRect     # « image figée » : une photo de l'écran posée par-dessus le jeu
var trail_t := 0.0
var hist: Array = []        # positions récentes du joueur, une toutes les 0,1 s (retour en arrière)
var hist_t := 0.0


func setup(a: Arena) -> void:
	arena = a
	var layer := CanvasLayer.new()
	layer.layer = 1   # sous le HUD (qui passe en 2) : le HUD reste lisible
	arena.hud.layer = 2
	add_child(layer)
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/bug.gdshader")
	rect.material = mat
	rect.visible = false
	layer.add_child(rect)
	frozen = TextureRect.new()
	frozen.set_anchors_preset(Control.PRESET_FULL_RECT)
	frozen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frozen.stretch_mode = TextureRect.STRETCH_SCALE
	frozen.visible = false
	layer.add_child(frozen)


func is_on(kind: String) -> bool:
	return float(active.get(kind, 0.0)) > 0.0


## Annonce un bug : il démarre après `warn` secondes. Retourne false s'il est refusé
## (déjà en cours ou déjà annoncé).
func launch(kind: String, warn: float) -> bool:
	if active.has(kind) or pending.has(kind):
		return false
	pending[kind] = warn
	Sfx.play("zap")
	arena.shake(2.0)
	if HEAVY.has(kind):
		arena.hud.announce("BUG : " + String(NAMES[kind]), Pal.BAD)
	return true


## Gros bugs que le boss peut lancer maintenant. Si le joueur a déjà l'effet (Tête à l'envers,
## commandes inversées du Stream), ce bug-là est ignoré : il en choisit un autre.
func heavy_choices() -> Array:
	var out := []
	for k in HEAVY:
		if active.has(k) or pending.has(k):
			continue
		if k == "flip" and Run.amulet_count("envers") > 0:
			continue
		if k == "controls" and arena.stream and arena.stream.flip_t > 0.0:
			continue
		out.append(k)
	return out


func tick(delta: float) -> void:
	# positions récentes du joueur (pour le retour en arrière)
	hist_t -= delta
	if hist_t <= 0.0:
		hist_t = 0.1
		hist.append(arena.player.position)
		if hist.size() > int(REWIND_SEC / 0.1) + 1:
			hist.pop_front()
	# règle de la carte : un bug léger de temps en temps, jamais deux à la fois
	if auto and active.is_empty() and pending.is_empty():
		cd -= delta
		if cd <= 0.0:
			cd = randf_range(8.0, 14.0)
			var pool := LIGHT.keys().filter(func(k): return k != last)
			last = pool.pick_random()
			launch(last, WARN_LIGHT)
	for k in pending.keys():
		pending[k] -= delta
		if pending[k] <= 0.0:
			pending.erase(k)
			_start(k)
	for k in active.keys():
		active[k] -= delta
		if active[k] <= 0.0:
			active.erase(k)
			_stop(k)
	if is_on("trail"):
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.12
			_ghost()
	if is_on("shift"):
		# la bande décalée saute de place de temps en temps
		mat.set_shader_parameter("band_shift", 0.04 + 0.03 * sin(arena.elapsed * 9.0))


func _start(kind: String) -> void:
	active[kind] = float(LIGHT.get(kind, HEAVY.get(kind, 1.0)))
	if LIGHT.has(kind):
		arena.float_text(arena.player.position + Vector2(0, -34), "BUG : " + String(NAMES[kind]), Pal.DIM)
	match kind:
		"invert":
			mat.set_shader_parameter("invert", 1.0)
		"shift":
			mat.set_shader_parameter("band_y", randf_range(0.15, 0.6))
			mat.set_shader_parameter("band_h", randf_range(0.12, 0.22))
		"freeze":
			# une photo de l'écran, posée sur le jeu qui continue derrière
			var img: Image = null if DisplayServer.get_name() == "headless" else get_viewport().get_texture().get_image()   # (pas d'image sans affichage)
			if img != null and not img.is_empty():
				frozen.texture = ImageTexture.create_from_image(img)
				frozen.visible = true
		"flip":
			arena.sync_amulets()
		"rewind":
			if not hist.is_empty():
				arena.burst(arena.player.position, Color.WHITE, 12, 90.0)
				arena.player.position = hist[0]
				arena.burst(arena.player.position, Color.WHITE, 12, 90.0)
				hist.clear()
	_refresh()


func _stop(kind: String) -> void:
	match kind:
		"invert":
			mat.set_shader_parameter("invert", 0.0)
		"shift":
			mat.set_shader_parameter("band_h", 0.0)
		"freeze":
			frozen.visible = false
			frozen.texture = null
		"flip":
			arena.sync_amulets()
	_refresh()


## Le rectangle du shader n'est affiché que quand il sert.
func _refresh() -> void:
	rect.visible = is_on("invert") or is_on("shift")


## Traînée : une copie du joueur, bien visible, qui reste 2 s avant de disparaître.
func _ghost() -> void:
	var p := arena.player
	var g := Sprite2D.new()
	g.texture = p.sprite.texture
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.position = p.position + p.body.position
	g.scale = p.body.scale
	# presque opaque et longue à s'effacer : on dirait plusieurs « toi », on ne sait plus lequel est le vrai
	g.modulate = Color(1.0, 1.0, 1.0, 0.92)
	g.material = p.sprite.material
	g.z_index = -1
	arena.world.add_child(g)
	var tw := g.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(g, "modulate:a", 0.0, 0.8)
	tw.tween_callback(g.queue_free)
