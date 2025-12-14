extends Node2D

const MAX_GECKOS := 8
const DEFAULT_INFO_TEXT := ""
const DIALOGUE_INFO_TEXT := "Please finish reading the dialogue first!"
const TERRARIUM_FULL_TEXT := "Terrarium is full. Release or remove a gecko before breeding again."
const SPAWN_MARGIN := Vector2(64, 64)
const MIN_GECKO_DISTANCE := 120.0
const MAX_SPAWN_ATTEMPTS := 20
const LOG_PREFIX := "[IngameController]"
const SCENARIO_WILD := "wild"
const SCENARIO_TERRARIUM := "terrarium"
const STARTER_NAMES := ["Sunny", "Mango", "Pebble", "Nova", "Indie", "Zara", "Milo", "Roux"]

@onready var gecko_container := %GeckoContainer
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var pause_overlay := %PauseOverlay
@onready var fade_overlay := %FadeOverlay
@onready var punnett_overlay := %PunnettOverlay
@onready var info_label := %InfoLabel
@onready var wild_background := %WildBackground
@onready var terrarium_background := %TerrariumBackground
@onready var explore_button := %ExploreButton
@onready var scenario_label := %ScenarioLabel

var _dialogue_system := DialogueSystem.new()
var _selected: Array = []
var _gecko_scene := preload("res://scenes/gecko.tscn")
var _breeding_hint_shown := false
var _current_scenario := SCENARIO_WILD
var _intro_gecko: GeckoEntity
var _spouse_gecko: GeckoEntity
var _used_names := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	randomize()
	_rng.randomize()
	add_child(_dialogue_system)
	_dialogue_system.dialogue_line_displayed.connect(_on_dialogue_line)
	_dialogue_system.dialogue_started.connect(_on_dialogue_started)
	_dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_box.advance_requested.connect(_advance_dialogue)
	pause_overlay.game_exited.connect(_save_game)
	explore_button.pressed.connect(_toggle_scenario)
	fade_overlay.visible = true
	if SaveGame.has_save():
		SaveGame.load_game(get_tree())
		_wire_existing_geckos()
		if gecko_container.get_child_count() == 0:
			_spawn_intro_gecko()
	else:
		_spawn_intro_gecko()
	_switch_scenario(_current_scenario)
	_start_intro_dialogue()

func _spawn_intro_gecko() -> void:
	if _intro_gecko:
		return
	var gecko_name := _pick_unique_name()
	var sex := _random_sex()
	_intro_gecko = _spawn_gecko(GeneticsSystem.create_random_genes(), gecko_name, 1, [], sex, SCENARIO_WILD)
	if _intro_gecko:
		print(LOG_PREFIX, " intro guide spawned", _intro_gecko.gecko_name, "sex", _intro_gecko.sex)

func _spawn_spouse_gecko() -> void:
	if not _intro_gecko:
		return
	if _spouse_gecko:
		return
	var gecko_name := _pick_unique_name()
	var sex := _opposite_sex(_intro_gecko.sex)
	_spouse_gecko = _spawn_gecko(GeneticsSystem.create_random_genes(), gecko_name, 1, [], sex, SCENARIO_WILD)
	if _spouse_gecko:
		print(LOG_PREFIX, " spouse spawned", _spouse_gecko.gecko_name, "sex", _spouse_gecko.sex)

func _spawn_gecko(genes: Dictionary, gecko_name: String, generation: int, parents: PackedStringArray = [], sex: String = "", habitat: String = SCENARIO_TERRARIUM) -> GeckoEntity:
	if gecko_container.get_child_count() >= MAX_GECKOS:
		print(LOG_PREFIX, " spawn blocked: max geckos reached")
		return null
	var gecko: GeckoEntity = _gecko_scene.instantiate()
	gecko.position = _get_spawn_position(habitat)
	var final_sex := sex if not sex.is_empty() else _random_sex()
	gecko.initialize(genes, gecko_name, generation, parents, final_sex, habitat)
	_attach_gecko_signals(gecko)
	gecko_container.add_child(gecko)
	_sync_gecko_visibility(gecko)
	print(LOG_PREFIX, " spawned gecko", gecko.gecko_name, "at", gecko.position)
	return gecko

func _get_spawn_position(habitat: String) -> Vector2:
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
		if _is_spawn_position_valid(candidate, habitat):
			return candidate
	return fallback


func _is_spawn_position_valid(spawn_position: Vector2, habitat: String) -> bool:
	for child in gecko_container.get_children():
		if child is GeckoEntity and child.habitat == habitat and child.position.distance_to(spawn_position) < MIN_GECKO_DISTANCE:
			return false
	return true

func _on_gecko_selected(gecko: GeckoEntity) -> void:
	if _dialogue_system.is_active():
		var active_topic: String = _dialogue_system.get_active_topic()
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
		if _selected[0].sex == _selected[1].sex:
			print(LOG_PREFIX, " selection rejected - same sex")
			_set_info_text("Pick one male and one female to breed.")
			var removed: GeckoEntity = _selected.pop_back()
			removed.set_selected(false)
			return
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
	elif topic == "intro_primary":
		_spawn_spouse_gecko()
		if _intro_gecko and _spouse_gecko:
			_dialogue_system.start_dialogue(
				_dialogue_system.build_spouse_intro(_intro_gecko.gecko_name, _spouse_gecko.gecko_name),
				"intro_spouse"
			)
		else:
			_set_info_text()
	elif topic == "intro_spouse":
		_dialogue_system.start_dialogue(
			_dialogue_system.build_breeding_prompt(_intro_gecko.gecko_name, _spouse_gecko.gecko_name),
			"breeding_prompt"
		)
	else:
		_set_info_text()

func _advance_dialogue() -> void:
	_dialogue_system.advance()

func _start_intro_dialogue() -> void:
	if SaveGame.has_save() and gecko_container.get_child_count() > 0:
		return
	if not _intro_gecko:
		_spawn_intro_gecko()
	if _intro_gecko:
		_dialogue_system.start_dialogue(
			_dialogue_system.build_intro_primary(_intro_gecko.gecko_name),
			"intro_primary"
		)

func _hatch_selected_gecko() -> void:
	if _selected.size() < 2:
		print(LOG_PREFIX, " hatch aborted - need two selected geckos")
		return
	var parent_a: GeckoEntity = _selected[0]
	var parent_b: GeckoEntity = _selected[1]
	var genes := GeneticsSystem.breed(parent_a.genes, parent_b.genes)
	var parents := PackedStringArray([parent_a.gecko_name, parent_b.gecko_name])
	var child := _spawn_gecko(genes, "Hatchling %d" % randi(), max(parent_a.generation, parent_b.generation) + 1, parents, _random_sex(), SCENARIO_TERRARIUM)
	if child:
		print(LOG_PREFIX, " hatched child", child.gecko_name, "gen", child.generation)
		_selected.clear()
		parent_a.set_selected(false)
		parent_b.set_selected(false)
		if _current_scenario == SCENARIO_TERRARIUM:
			_set_info_text(DEFAULT_INFO_TEXT)
		else:
			_set_info_text("New hatchling is waiting in the terrarium. Switch scenes to meet them.")
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
			_sync_gecko_visibility(gecko)
			_used_names[gecko.gecko_name] = true
			if not _intro_gecko:
				_intro_gecko = gecko
			elif not _spouse_gecko and gecko.sex != _intro_gecko.sex:
				_spouse_gecko = gecko

func _set_info_text(text: String = DEFAULT_INFO_TEXT) -> void:
	info_label.text = text

func _toggle_scenario() -> void:
	var target := SCENARIO_TERRARIUM if _current_scenario == SCENARIO_WILD else SCENARIO_WILD
	_switch_scenario(target)

func _switch_scenario(target: String) -> void:
	_current_scenario = target
	wild_background.visible = target == SCENARIO_WILD
	terrarium_background.visible = target == SCENARIO_TERRARIUM
	if target == SCENARIO_WILD:
		scenario_label.text = "Wild Habitat"
		explore_button.text = "Go to Terrarium"
	else:
		scenario_label.text = "Terrarium"
		explore_button.text = "Explore Wild"
	_apply_scene_visibility()
	_set_info_text()

func _apply_scene_visibility() -> void:
	for gecko in gecko_container.get_children():
		_sync_gecko_visibility(gecko)

func _sync_gecko_visibility(gecko: GeckoEntity) -> void:
	if not gecko:
		return
	gecko.visible = gecko.habitat == _current_scenario

func _random_sex() -> String:
	return "M" if _rng.randi_range(0, 1) == 0 else "F"

func _opposite_sex(value: String) -> String:
	return "F" if value == "M" else "M"

func _spawn_wild_extra(count: int) -> void:
	for _i in range(count):
		if gecko_container.get_child_count() >= MAX_GECKOS:
			return
		_spawn_gecko(GeneticsSystem.create_random_genes(), _pick_unique_name(), 1, [], _random_sex(), SCENARIO_WILD)

func _pick_unique_name() -> String:
	var pool := STARTER_NAMES.duplicate()
	pool.shuffle()
	for candidate in pool:
		if not _used_names.has(candidate):
			_used_names[candidate] = true
			return candidate
	# fallback when pool exhausted
	var suffix := str(_used_names.size() + 1)
	var fallback := "Gecko " + suffix
	_used_names[fallback] = true
	return fallback

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
