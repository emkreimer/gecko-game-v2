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
@onready var info_label := %InfoLabel
@onready var wild_background := %WildBackground
@onready var terrarium_background := %TerrariumBackground
@onready var actions_button: Button = %ActionsButton
@onready var actions_menu: PopupPanel = %ActionsMenu
@onready var change_scenario_button: Button = %ChangeScenarioButton
@onready var open_inventory_button: Button = %OpenInventoryButton
@onready var inventory_overlay: InventoryOverlay = %InventoryOverlay
@onready var rename_dialog: AcceptDialog = %RenameDialog
@onready var rename_line_edit: LineEdit = %RenameLineEdit
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog
@onready var terrarium_spawn_points := %TerrariumSpawnPoints
@onready var wild_spawn_points := %WildSpawnPoints

var _dialogue_system := DialogueSystem.new()
var _selected: Array = []
var _gecko_scene := preload("res://scenes/gecko.tscn")
var _breeding_hint_shown := false
var _current_scenario := SCENARIO_WILD
var _intro_gecko: GeckoEntity
var _spouse_gecko: GeckoEntity
var _used_names := {}
var _rng := RandomNumberGenerator.new()
var _pending_punnett_entries: Array = []
var _context_gecko: GeckoEntity

func _ready() -> void:
	randomize()
	_rng.randomize()
	add_child(_dialogue_system)
	_dialogue_system.dialogue_line_displayed.connect(_on_dialogue_line)
	_dialogue_system.dialogue_started.connect(_on_dialogue_started)
	_dialogue_system.dialogue_ended.connect(_on_dialogue_ended)
	dialogue_box.advance_requested.connect(_advance_dialogue)
	dialogue_box.punnett_closed.connect(_on_punnett_closed)
	pause_overlay.game_exited.connect(_save_game)
	actions_button.pressed.connect(_on_actions_button_pressed)
	change_scenario_button.pressed.connect(_on_change_scenario_pressed)
	open_inventory_button.pressed.connect(_on_open_inventory_pressed)
	if inventory_overlay:
		inventory_overlay.breed_requested.connect(_on_inventory_breed_requested)
		inventory_overlay.delete_requested.connect(_on_inventory_delete_requested)
		inventory_overlay.rename_requested.connect(_on_inventory_rename_requested)
		inventory_overlay.closed.connect(_on_inventory_closed)
	rename_dialog.confirmed.connect(_on_rename_confirmed)
	rename_line_edit.text_submitted.connect(func(_text): _on_rename_confirmed())
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	actions_menu.hide()
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
	var spawn_points_parent := terrarium_spawn_points if habitat == SCENARIO_TERRARIUM else wild_spawn_points
	
	if not spawn_points_parent:
		print(LOG_PREFIX, " ERROR: spawn points parent not found for habitat: ", habitat)
		print(LOG_PREFIX, " terrarium_spawn_points: ", terrarium_spawn_points)
		print(LOG_PREFIX, " wild_spawn_points: ", wild_spawn_points)
		return _get_random_spawn_position()
	
	var available_points: Array[Marker2D] = []
	for child in spawn_points_parent.get_children():
		if child is Marker2D:
			available_points.append(child)
	
	if available_points.is_empty():
		print(LOG_PREFIX, " no spawn points available, using fallback")
		return _get_random_spawn_position()
	
	# find occupied spawn points
	var occupied_positions: Array[Vector2] = []
	for gecko in gecko_container.get_children():
		if gecko is GeckoEntity and gecko.habitat == habitat:
			occupied_positions.append(gecko.position)
	
	# find an unoccupied spawn point
	available_points.shuffle()
	for spawn_point in available_points:
		var is_occupied := false
		# convert spawn point (from world position to gecko_container local space
		var local_pos: Vector2 = gecko_container.to_local(spawn_point.global_position)
		for occupied_pos in occupied_positions:
			if local_pos.distance_to(occupied_pos) < MIN_GECKO_DISTANCE:
				is_occupied = true
				break
		if not is_occupied:
			return local_pos
	
	print(LOG_PREFIX, " all spawn points occupied, reusing point")
	return gecko_container.to_local(available_points[0].global_position)


func _get_random_spawn_position() -> Vector2:
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


func _is_spawn_position_valid(spawn_position: Vector2) -> bool:
	for child in gecko_container.get_children():
		if child is GeckoEntity and child.position.distance_to(spawn_position) < MIN_GECKO_DISTANCE:
			return false
	return true

func _on_gecko_selected(gecko: GeckoEntity) -> void:
	if _dialogue_system.is_active():
		var active_topic: String = _dialogue_system.get_active_topic()
		if active_topic != "breeding":
			print(LOG_PREFIX, " selection ignored due to dialogue", active_topic)
			return
	print(LOG_PREFIX, " gecko clicked", gecko.gecko_name)
	_context_gecko = gecko
	_set_info_text(gecko.get_info_text(), true)
	if not inventory_overlay.visible:
		_clear_selection_visuals()
		gecko.set_selected(true)

func _clear_selection_visuals() -> void:
	for gecko in _get_geckos():
		gecko.set_selected(false)

func _show_gecko_info(gecko: GeckoEntity) -> void:
	if not gecko:
		return
	_set_info_text(gecko.get_info_text(), true)

func _toggle_breed_selection(gecko: GeckoEntity) -> void:
	if not gecko:
		return
	if gecko in _selected:
		_selected.erase(gecko)
		gecko.set_selected(false)
		print(LOG_PREFIX, " deselected", gecko.gecko_name, "remaining", _selected.size())
		return
	if _selected.size() >= 2:
		for entry in _selected:
			entry.set_selected(false)
		_selected.clear()
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

func _open_rename_dialog(gecko: GeckoEntity) -> void:
	if not gecko or not rename_dialog or not rename_line_edit:
		return
	rename_line_edit.text = gecko.gecko_name
	rename_line_edit.caret_column = gecko.gecko_name.length()
	rename_line_edit.select_all()
	rename_dialog.title = "Rename Gecko"
	rename_dialog.popup_centered(Vector2(360, 140))
	rename_line_edit.grab_focus()

func _on_rename_confirmed() -> void:
	if not _context_gecko or not rename_line_edit:
		return
	var new_name := rename_line_edit.text.strip_edges()
	if new_name.is_empty():
		_set_info_text("Name cannot be empty.", true)
		rename_line_edit.grab_focus()
		return
	if _used_names.has(new_name) and new_name != _context_gecko.gecko_name:
		_set_info_text("Name already used. Pick another.", true)
		rename_line_edit.grab_focus()
		rename_line_edit.select_all()
		return
	_used_names.erase(_context_gecko.gecko_name)
	_used_names[new_name] = true
	_context_gecko.set_gecko_name(new_name)
	_set_info_text("Renamed to %s" % new_name, true)
	rename_dialog.hide()
	_refresh_inventory_overlay()

func _open_delete_dialog(gecko: GeckoEntity) -> void:
	if not gecko or not delete_dialog:
		return
	delete_dialog.dialog_text = "Delete %s?" % gecko.gecko_name
	delete_dialog.popup_centered(Vector2(360, 160))

func _on_delete_confirmed() -> void:
	_delete_gecko(_context_gecko)

func _delete_gecko(gecko: GeckoEntity) -> void:
	if not gecko or not is_instance_valid(gecko):
		return
	if gecko in _selected:
		_selected.erase(gecko)
	gecko.set_selected(false)
	if gecko == _intro_gecko:
		_intro_gecko = null
	if gecko == _spouse_gecko:
		_spouse_gecko = null
	_used_names.erase(gecko.gecko_name)
	gecko.queue_free()
	_pending_punnett_entries.clear()
	dialogue_box.hide_punnett()
	_set_info_text("Gecko deleted.", true)
	_context_gecko = null
	_refresh_inventory_overlay()

func _on_dialogue_line(line: Dictionary) -> void:
	dialogue_box.display_line(line)

func _on_dialogue_started(_topic: String) -> void:
	dialogue_box.hide_punnett()
	_set_info_text(DIALOGUE_INFO_TEXT)
	pause_overlay.visible = false

func _on_dialogue_ended(topic: String) -> void:
	dialogue_box.hide_dialogue()
	if topic == "punnett":
		_show_pending_punnett()
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
		_pending_punnett_entries.clear()
		_refresh_inventory_overlay()
		return
	print(LOG_PREFIX, " hatch failed - terrarium full")
	for entry in _selected:
		entry.set_selected(false)
	_selected.clear()
	_set_info_text(TERRARIUM_FULL_TEXT)
	_pending_punnett_entries.clear()

func _show_punnett_square(parent_a: GeckoEntity, parent_b: GeckoEntity) -> void:
	var data := GeneticsSystem.build_punnett_data(parent_a.genes, parent_b.genes)
	print(LOG_PREFIX, " punnett data entries", data.size())
	_pending_punnett_entries = data
	if data.is_empty():
		dialogue_box.hide_punnett()
		return

func _on_gecko_hovered(_gecko: GeckoEntity, info: String) -> void:
	_set_info_text(info if not info.is_empty() else DEFAULT_INFO_TEXT, not info.is_empty())

func _on_punnett_closed() -> void:
	if _pending_punnett_entries.is_empty():
		return
	_hatch_selected_gecko()
	_pending_punnett_entries.clear()

func _show_pending_punnett() -> void:
	if _pending_punnett_entries.is_empty():
		_hatch_selected_gecko()
		return
	dialogue_box.show_punnett(_pending_punnett_entries)
	_set_info_text("Review the Punnett square, then close to hatch.", true)

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

func _set_info_text(text: String = DEFAULT_INFO_TEXT, show_box: bool = false) -> void:
	info_label.text = text
	info_label.visible = show_box and not text.is_empty()

func _on_actions_button_pressed() -> void:
	if not actions_menu:
		return
	if actions_menu.visible:
		actions_menu.hide()
		return
	actions_menu.reset_size()
	var button_global: Rect2 = actions_button.get_global_rect()
	var popup_size: Vector2 = Vector2(240, 0)
	if actions_menu.has_method("get_size"): # compat fallback
		popup_size = actions_menu.get_size()
	elif actions_menu.has_method("get_combined_minimum_size"):
		popup_size = actions_menu.get_combined_minimum_size()
	elif actions_menu.has_method("get_minimum_size"):
		popup_size = actions_menu.get_minimum_size()
	if popup_size == Vector2.ZERO:
		popup_size = Vector2(240, 0)
	actions_menu.position = Vector2(button_global.position.x + button_global.size.x - popup_size.x, button_global.end.y + 4)
	actions_menu.popup()
	actions_menu.grab_focus()

func _on_change_scenario_pressed() -> void:
	_toggle_scenario()
	actions_menu.hide()

func _on_open_inventory_pressed() -> void:
	actions_menu.hide()
	_show_inventory_overlay()

func _show_inventory_overlay() -> void:
	if not inventory_overlay:
		return
	inventory_overlay.show_inventory(_get_geckos(), _current_scenario)
	_set_info_text("", false)

func _on_inventory_closed() -> void:
	_set_info_text()

func _on_inventory_breed_requested(gecko_a: GeckoEntity, gecko_b: GeckoEntity) -> void:
	if not gecko_a or not gecko_b:
		return
	if gecko_a.sex == gecko_b.sex:
		_set_info_text("Pick one male and one female to breed.", true)
		return
	_selected.clear()
	_selected.append_array([gecko_a, gecko_b])
	gecko_a.set_selected(true)
	gecko_b.set_selected(true)
	_show_punnett_square(gecko_a, gecko_b)
	_dialogue_system.start_dialogue(_dialogue_system.get_dialogue("punnett"), "punnett")

func _on_inventory_rename_requested(gecko: GeckoEntity) -> void:
	if not gecko:
		return
	_context_gecko = gecko
	_open_rename_dialog(gecko)

func _on_inventory_delete_requested(gecko: GeckoEntity) -> void:
	if not gecko:
		return
	_context_gecko = gecko
	_open_delete_dialog(gecko)

func _refresh_inventory_overlay() -> void:
	if inventory_overlay:
		inventory_overlay.refresh_inventory(_get_geckos(), _current_scenario)

func _get_geckos() -> Array:
	var result: Array = []
	for child in gecko_container.get_children():
		if child is GeckoEntity:
			result.append(child)
	return result

func _toggle_scenario() -> void:
	var target := SCENARIO_TERRARIUM if _current_scenario == SCENARIO_WILD else SCENARIO_WILD
	_switch_scenario(target)

func _switch_scenario(target: String) -> void:
	_current_scenario = target
	wild_background.visible = target == SCENARIO_WILD
	terrarium_background.visible = target == SCENARIO_TERRARIUM
	_update_change_scenario_button()
	_apply_scene_visibility()
	_set_info_text()
	actions_menu.hide()

func _update_change_scenario_button() -> void:
	if not change_scenario_button:
		return
	if _current_scenario == SCENARIO_WILD:
		change_scenario_button.text = "Go to Terrarium"
	else:
		change_scenario_button.text = "Explore Wild"

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
