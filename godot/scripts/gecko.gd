class_name GeckoEntity
extends Node2D

signal gecko_selected(gecko: GeckoEntity)
signal gecko_hovered(gecko: GeckoEntity, info_text: String)

@export var animation_speed := 0.25
@export var base_scale := Vector2(0.18, 0.18)

# Per-frame offsets to correct the right-shifted 4th sprite in the sheets.
const FRAME_OFFSETS: Array[Vector2] = [
	Vector2.ZERO,
	Vector2.ZERO,
	Vector2.ZERO,
	Vector2(-64, 0)
]

var gecko_name := "Unnamed"
var generation := 1
var genes: Dictionary = {}
var parents: PackedStringArray = []
var sex := ""
var habitat := "wild"  # wild or terrarium

var _selected := false
var _frame := 0
var _info_cache := ""

@onready var composite := %CompositeSprite
@onready var body_sprite := %Body
@onready var eye_sprite := %Eyes
@onready var tail_sprite := %Tail
@onready var spots_sprite := %Spots
@onready var name_label := %NameLabel
@onready var animation_timer := %AnimationTimer
@onready var click_area := %ClickArea

func _ready() -> void:
	add_to_group("Persist")
	animation_timer.wait_time = animation_speed
	animation_timer.timeout.connect(_on_animation_timer_timeout)
	click_area.input_event.connect(_on_click_area_input_event)
	click_area.mouse_entered.connect(_on_mouse_entered)
	click_area.mouse_exited.connect(_on_mouse_exited)
	animation_timer.start()
	_update_name_label()
	if not genes.is_empty():
		_update_from_genes()

func initialize(p_genes: Dictionary, p_name: String, p_generation: int, p_parents: PackedStringArray = [], p_sex: String = "", p_habitat: String = "wild") -> void:
	gecko_name = p_name
	generation = p_generation
	parents = p_parents.duplicate()
	sex = p_sex if not p_sex.is_empty() else "M"
	habitat = p_habitat
	genes = {}
	for trait_key in p_genes.keys():
		var gene: Gene = p_genes[trait_key]
		genes[trait_key] = Gene.new()
		genes[trait_key].configure(gene.trait_key, gene.trait_data, gene.allele1, gene.allele2)
	_update_from_genes()


# Rename helper avoids clobbering Node.set_name
func set_gecko_name(new_name: String) -> void:
	gecko_name = new_name
	_info_cache = ""
	_update_name_label()

func set_selected(selected: bool) -> void:
	_selected = selected
	composite.modulate = Color(1.3, 1.3, 0.95, 1) if selected else Color(1, 1, 1, 1)

func toggle_selection() -> void:
	set_selected(not _selected)

func is_selected() -> bool:
	return _selected

func get_info_text() -> String:
	if _info_cache.is_empty():
		var header := "Sex: %s | Habitat: %s" % [sex, habitat.capitalize()]
		var genetics := GeneticsSystem.build_info_text(genes)
		_info_cache = header + "\n" + genetics
	return _info_cache

func save_data() -> Dictionary:
	return {
		"name": gecko_name,
		"generation": generation,
		"parents": parents,
		"genes": GeneticsSystem.serialize_genes(genes),
		"sex": sex,
		"habitat": habitat
	}

func load_data(data: Dictionary) -> void:
	gecko_name = data.get("name", gecko_name)
	generation = data.get("generation", generation)
	parents = data.get("parents", [])
	sex = data.get("sex", sex if not sex.is_empty() else "M")
	habitat = data.get("habitat", habitat)
	genes = GeneticsSystem.deserialize_genes(data.get("genes", []))
	_update_from_genes()

func _update_from_genes() -> void:
	_info_cache = ""
	_update_name_label()
	
	# Wait until nodes are ready before updating visuals
	if not body_sprite:
		return
	
	var summary: Dictionary = GeneticsSystem.get_phenotype_summary(genes)
	var color_data: Dictionary = summary.get("color", {}).get("data", {})
	var eye_data: Dictionary = summary.get("eye_color", {}).get("data", {})
	var pattern_data: Dictionary = summary.get("pattern", {}).get("data", {})
	var size_data: Dictionary = summary.get("size", {}).get("data", {})
	var tail_data: Dictionary = summary.get("tail", {}).get("data", {})

	var body_color: Color = color_data.get("color", Color.WHITE)
	body_sprite.modulate = body_color
	tail_sprite.modulate = body_color
	if not eye_data.is_empty():
		eye_sprite.modulate = eye_data.get("color", Color.WHITE)

	spots_sprite.visible = pattern_data.get("spots_visible", true)

	var size_scale: float = size_data.get("scale", 1.0)
	var tail_scale: float = tail_data.get("scale", 1.0)
	var final_scale := Vector2(size_scale, size_scale) * base_scale
	composite.scale = final_scale
	tail_sprite.scale = Vector2(1.0, tail_scale)

func _update_name_label() -> void:
	if name_label:
		name_label.text = "%s [%s] (Gen %d)" % [gecko_name, sex, generation]

func _on_animation_timer_timeout() -> void:
	_frame = (_frame + 1) % 4
	body_sprite.frame = _frame
	eye_sprite.frame = _frame
	tail_sprite.frame = _frame
	spots_sprite.frame = _frame
	_apply_frame_offset()

func _apply_frame_offset() -> void:
	var offset: Vector2 = FRAME_OFFSETS[_frame]
	body_sprite.offset = offset
	eye_sprite.offset = offset
	tail_sprite.offset = offset
	spots_sprite.offset = offset

func _on_click_area_input_event(_viewport, event, _shape_idx) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		gecko_selected.emit(self)
	if event.is_action_pressed("ui_accept"):
		gecko_selected.emit(self)

func _on_mouse_entered() -> void:
	gecko_hovered.emit(self, get_info_text())

func _on_mouse_exited() -> void:
	gecko_hovered.emit(self, "")
