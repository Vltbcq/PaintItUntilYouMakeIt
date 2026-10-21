class_name DrawingGrid
extends ScrollContainer
## Grille de dessins qui ne crée ses cases qu'au moment où leur ligne devient visible (plus une ligne
## de marge) : 50 ou 5000 dessins s'ouvrent aussi vite. Les vignettes se chargent de la même façon
## (UI.drawing_thumb). make(item) -> Control : la case d'un élément (taille cell).

var items: Array
var cols: int
var cell: Vector2
var make: Callable
var gap := 4.0
var _box := Control.new()
var _built := {}   # lignes déjà créées


func _init(p_items: Array, p_cols: int, p_cell: Vector2, p_make: Callable) -> void:
	items = p_items
	cols = p_cols
	cell = p_cell
	make = p_make
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	var rows := ceili(items.size() / float(cols))
	_box.custom_minimum_size = Vector2(cols * (cell.x + gap) - gap, maxf(0.0, rows * (cell.y + gap) - gap))
	_box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_box)


func _ready() -> void:
	get_v_scroll_bar().value_changed.connect(func(_v): _fill())
	resized.connect(_fill)
	_fill()


func _fill() -> void:
	var step := cell.y + gap
	var r0 := maxi(0, floori(scroll_vertical / step) - 1)
	var r1 := ceili((scroll_vertical + size.y) / step) + 1
	for r in range(r0, r1 + 1):
		if _built.has(r) or r * cols >= items.size():
			continue
		_built[r] = true
		for c in mini(cols, items.size() - r * cols):
			var b: Control = make.call(items[r * cols + c])
			b.position = Vector2(c * (cell.x + gap), r * step)
			b.size = cell
			_box.add_child(b)
