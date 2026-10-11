class_name StatText
extends Control
## Affiche des lignes de stats (« PV max : 19 », « Rés. Feu 60% · Foudre 80% »...) en ICÔNES :
## l'icône de la stat + sa valeur, en colonnes ; le nom de la stat s'affiche au survol.
## Les lignes qui ne sont pas des stats restent du texte, en dessous.

## Nom affiché dans le jeu -> icône (assets/ui/stats, dessinées par docs/stat_icons.py)
static var ICONS := {
	"PV max": "max_hp", "PV": "max_hp", "Régénération": "regen", "Armure": "armor", "Esquive": "dodge",
	"Vitesse": "move", "Dégâts": "dmg", "Vit. d'attaque": "atk_speed", "Critique": "crit", "Portée": "range",
	"Vol de vie": "lifesteal", "Chance": "luck", "Pourboire": "harvest", "Épines": "thorns",
	"Puissance élém.": "el_power",
}
## Clés de stats (bonus de niveau...) -> icône
const KEY_ICONS := {"max_hp": "max_hp", "regen": "regen", "armor": "armor", "dodge": "dodge", "speed": "move",
	"move": "move", "dmg": "dmg", "atk_speed": "atk_speed", "crit": "crit", "range": "range",
	"lifesteal": "lifesteal", "luck": "luck", "harvest": "harvest", "thorns": "thorns", "el_power": "el_power"}
static var KEY_NAMES := {"max_hp": "PV max", "regen": "Régénération", "armor": "Armure", "dodge": "Esquive",
	"speed": "Vitesse", "move": "Vitesse", "dmg": "Dégâts", "atk_speed": "Vitesse d'attaque", "crit": "Critique",
	"range": "Portée", "lifesteal": "Vol de vie", "luck": "Chance", "harvest": "Pourboire (or à chaque fin de vague)",
	"thorns": "Épines", "el_power": "Puissance élémentaire"}

var columns := 2
var color := Pal.TEXT
var row_h := 16.0
var stretch := false   # les lignes s'écartent pour remplir toute la hauteur (boutique)


func _init(cols := 2, col := Pal.TEXT) -> void:
	columns = cols
	color = col
	mouse_filter = Control.MOUSE_FILTER_PASS


static func icon(key: String) -> Texture2D:
	return load("res://assets/ui/stats/%s.png" % KEY_ICONS.get(key, key))


## Remplace le contenu par ces lignes de texte (format de Stats.describe_player / Stats.preview).
func set_text(text: String) -> void:
	for c in get_children():
		c.queue_free()
	var cells := []      # [texture, valeur, nom au survol]
	var others := []     # lignes de texte normales
	for line in text.split("\n"):
		var l := line.strip_edges()
		var res_pre: String = Loc.t("Rés. ")
		if l.begins_with(res_pre):
			for part in l.substr(res_pre.length()).split(" · "):
				var bits := part.split(" ")
				var el := Pal.NAMES.find(bits[0])
				if el > 0 and bits.size() > 1:
					cells.append([UI.element_icon(el), bits[1], Loc.t("Résistance %s") % bits[0]])
			continue
		# « Nom : valeur » en français, « Name: value » en anglais
		var cut := l.find(" : ")
		var skip := 3
		if cut < 0:
			cut = l.find(": ")
			skip = 2
		var name := l.substr(0, cut) if cut > 0 else ""
		if cut > 0 and ICONS.has(name):
			cells.append([load("res://assets/ui/stats/%s.png" % ICONS[name]), l.substr(cut + skip), name])
		elif l != "":
			others.append(l)
	var cw := size.x / columns if columns > 0 else size.x
	var rows := ceili(cells.size() / float(columns))
	if stretch and others.is_empty() and rows > 0:
		row_h = maxf(16.0, floorf(size.y / rows))
	var dy := floorf((row_h - 16.0) / 2.0)   # (icône et valeur centrées dans une ligne plus haute)
	for k in cells.size():
		var c: Array = cells[k]
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.tooltip_text = c[2]
		UI.put(self, cell, Vector2((k % columns) * cw, floori(float(k) / columns) * row_h), Vector2(cw, row_h))
		var tr := TextureRect.new()
		tr.texture = c[0]
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.put(cell, tr, Vector2(0, dy), Vector2(16, 16))
		var lb := UI.label(String(c[1]), 10, color)
		UI.put(cell, lb, Vector2(18, 1 + dy), Vector2(cw - 18, 14))
	var y := ceilf(cells.size() / float(columns)) * row_h
	for o in others:
		var lb := UI.label(o, 10, color)
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var h := UI.font.get_multiline_string_size(o, HORIZONTAL_ALIGNMENT_LEFT, size.x, UI.fs(10)).y
		UI.put(self, lb, Vector2(0, y), Vector2(size.x, h))
		y += h
	custom_minimum_size.y = y
