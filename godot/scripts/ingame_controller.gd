extends Node2D

const MAX_GECKOS := 8
const STARTER_COUNT := 2
const DEFAULT_INFO_TEXT := "Select two geckos to breed. Finish dialogue prompts to continue."
const DIALOGUE_INFO_TEXT := "Please finish reading the dialogue first!"
const TERRARIUM_FULL_TEXT := "Terrarium is full. Release or remove a gecko before breeding again."
const SPAWN_MARGIN := Vector2(64, 64)
const MIN_GECKO_DISTANCE := 120.0
const MAX_SPAWN_ATTEMPTS := 20
const LOG_PREFIX := "[IngameController]"

@onready var gecko_container := %GeckoContainer
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var pause_overlay := %PauseOverlay
@onready var fade_overlay := %FadeOverlay
@onready var punnett_overlay := %PunnettOverlay
@onready var info_label := %InfoLabel

var _dialogue_system := DialogueSystem.new()
var _selected: Array = []
var _gecko_scene := preload("res://scenes/gecko.tscn")
var _breeding_hint_shown := false

func _ready() -> void:
	randomize()
	add_child(_dialogue_system)
	_dialogue_system.dialogue_line_displayed.connect(_on_dialogue_line)
	_dialogue_system.dialogue_started.connect(_on_dialogue_started)
	_dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_box.advance_requested.connect(_advance_dialogue)
	pause_overlay.game_exited.connect(_save_game)
	fade_overlay.visible = true
	if SaveGame.has_save():
		SaveGame.load_game(get_tree())
		_wire_existing_geckos()
		if gecko_container.get_child_count() == 0:
			_spawn_starter_geckos()
	else:
		_spawn_starter_geckos()
	_set_info_text()
	_dialogue_system.start_dialogue(_dialogue_system.get_dialogue("intro"), "intro")

func _spawn_starter_geckos() -> void:
	for i in range(STARTER_COUNT):
		_spawn_gecko(GeneticsSystem.create_random_genes(), "Starter %d" % (i + 1), 1)

func _spawn_gecko(genes: Dictionary, name: String, generation: int, parents: PackedStringArray = []) -> GeckoEntity:
	if gecko_container.get_child_count() >= MAX_GECKOS:
		print(LOG_PREFIX, " spawn blocked: max geckos reached")
		return null
	var gecko: GeckoEntity = _gecko_scene.instantiate()
	gecko.position = _get_spawn_position()
	gecko.initialize(genes, name, generation, parents)
	_attach_gecko_signals(gecko)
	gecko_container.add_child(gecko)
	print(LOG_PREFIX, " spawned gecko", gecko.gecko_name, "at", gecko.position)
	return gecko

func _get_spawn_position() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size
	var min_bound := Vector2(
		min(SPAWN_MARGIN.x, viewport_size.x),
		min(SPAWN_MARGIN.y, viewport_size.y)
	)
	var max_bound := Vector2(
		max(viewport_size.x - SPAWN_MARGIN.x, min_bound.x),
		max(viewport_size.y - SPAWN_MARGIN.y, min_bound.y)
	)
	var fallback := (min_bound + max_bound) * 0.5
	for _i in range(MAX_SPAWN_ATTEMPTS):
		var candidate := Vector2(
			randf_range(min_bound.x, max_bound.x),
			randf_range(min_bound.y, max_bound.y)
		)
		if _is_spawn_position_valid(candidate):
			return candidate
	return fallback

func _is_spawn_position_valid(position: Vector2) -> bool:
	for child in gecko_container.get_children():
		if child is GeckoEntity and child.position.distance_to(position) < MIN_GECKO_DISTANCE:
			return false
	return true

func _on_gecko_selected(gecko: GeckoEntity) -> void:
	if _dialogue_system.is_active():
		var active_topic := _dialogue_system.get_active_topic()
		if active_topic != "breeding":
			print(LOG_PREFIX, " selection ignored due to dialogue", active_topic)
			return
	print(LOG_PREFIX, " gecko clicked", gecko.gecko_name)
	if gecko in _selected:
		_selected.erase(gecko)
		gecko.set_selected(false)
		print(LOG_PREFIX, " deselected", gecko.gecko_name, "remaining", _selected.size())
		#if _selected.size() < 2:
			#punnett_overlay.hide_overlay()
		return
	if _selected.size() >= 2:
		for entry in _selected:
			entry.set_selected(false)
		_selected.clear()
		#punnett_overlay.hide_overlay()
		print(LOG_PREFIX, " selection reset - too many geckos")
	_selected.append(gecko)
	gecko.set_selected(true)
	print(LOG_PREFIX, " selected", gecko.gecko_name, "total selected", _selected.size())
	if _selected.size() == 1 and not _breeding_hint_shown:
		_breeding_hint_shown = true
		print(LOG_PREFIX, " starting breeding dialogue")
		_dialogue_system.start_dialogue(_dialogue_system.get_dialogue("breeding"), "breeding")
	if _selected.size() == 2:
		print(LOG_PREFIX, " second selection complete, starting punnett dialogue")
		_show_punnett_square(_selected[0], _selected[1])
		_dialogue_system.start_dialogue(_dialogue_system.get_dialogue("punnett"), "punnett")

func _on_dialogue_line(line: Dictionary) -> void:
	dialogue_box.display_line(line)

func _on_dialogue_started(_topic: String) -> void:
	_set_info_text(DIALOGUE_INFO_TEXT)
	pause_overlay.visible = false

func _on_dialogue_ended(topic: String) -> void:
	dialogue_box.hide_dialogue()
	if topic == "punnett":
		#punnett_overlay.hide_overlay()
		_hatch_selected_gecko()
	else:
		_set_info_text()

func _advance_dialogue() -> void:
	_dialogue_system.advance()

func _hatch_selected_gecko() -> void:
	if _selected.size() < 2:
		print(LOG_PREFIX, " hatch aborted - need two selected geckos")
		return
	var parent_a: GeckoEntity = _selected[0]
	var parent_b: GeckoEntity = _selected[1]
	var genes := GeneticsSystem.breed(parent_a.genes, parent_b.genes)
	var parents := PackedStringArray([parent_a.gecko_name, parent_b.gecko_name])
	var child := _spawn_gecko(genes, "Hatchling %d" % randi(), max(parent_a.generation, parent_b.generation) + 1, parents)
	if child:
		print(LOG_PREFIX, " hatched child", child.gecko_name, "gen", child.generation)
		_selected.clear()
		parent_a.set_selected(false)
		parent_b.set_selected(false)
		_set_info_text()
		#punnett_overlay.hide_overlay()
		return
	print(LOG_PREFIX, " hatch failed - terrarium full")
	for entry in _selected:
		entry.set_selected(false)
	_selected.clear()
	#punnett_overlay.hide_overlay()
	_set_info_text(TERRARIUM_FULL_TEXT)

func _show_punnett_square(parent_a: GeckoEntity, parent_b: GeckoEntity) -> void:
	var data := GeneticsSystem.build_punnett_data(parent_a.genes, parent_b.genes)
	print(LOG_PREFIX, " punnett data entries", data.size())
	if data.is_empty():
		punnett_overlay.hide_overlay()
		return
	punnett_overlay.show_punnett(data)

func _on_gecko_hovered(_gecko: GeckoEntity, info: String) -> void:
	_set_info_text(info if not info.is_empty() else DEFAULT_INFO_TEXT)

func _attach_gecko_signals(gecko: GeckoEntity) -> void:
	if not gecko.gecko_selected.is_connected(_on_gecko_selected):
		gecko.gecko_selected.connect(_on_gecko_selected)
	if not gecko.gecko_hovered.is_connected(_on_gecko_hovered):
		gecko.gecko_hovered.connect(_on_gecko_hovered)

func _wire_existing_geckos() -> void:
	for gecko in gecko_container.get_children():
		if gecko is GeckoEntity:
			_attach_gecko_signals(gecko)

func _set_info_text(text: String = DEFAULT_INFO_TEXT) -> void:
	info_label.text = text

func _save_game() -> void:
	SaveGame.save_game(get_tree())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not pause_overlay.visible:
		if _dialogue_system.is_active():
			return
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		pause_overlay.grab_button_focus()
		pause_overlay.visible = true
	elif event.is_action_pressed("ui_accept") and _dialogue_system.is_active():
		get_viewport().set_input_as_handled()
		dialogue_box.request_advance()
