class_name InventoryOverlay
extends CanvasLayer

signal breed_requested(gecko_a, gecko_b)
signal rename_requested(gecko)
signal delete_requested(gecko)
signal closed()

const GeneticsSystem = preload("res://scripts/genetics_system.gd")

@export var gecko_scene: PackedScene = preload("res://scenes/gecko.tscn")

@onready var dimmer: ColorRect = %Dimmer
@onready var root: Control = %Root
@onready var gecko_list: ItemList = %GeckoList
@onready var name_label: Label = %NameLabel
@onready var sex_label: Label = %SexLabel
@onready var habitat_label: Label = %HabitatLabel
@onready var generation_label: Label = %GenerationLabel
@onready var info_label: RichTextLabel = %InfoLabel
@onready var punnett_label: RichTextLabel = %PunnettLabel
@onready var partner_option: OptionButton = %PartnerOption
@onready var breed_button: Button = %BreedButton
@onready var rename_button: Button = %RenameButton
@onready var delete_button: Button = %DeleteButton
@onready var close_button: Button = %CloseButton

var _geckos: Array = []
var _selected: GeckoEntity
var _partner: GeckoEntity
var _preview_instance: GeckoEntity

func _ready() -> void:
	hide_overlay()
	gecko_list.item_selected.connect(_on_list_selected)
	gecko_list.item_clicked.connect(_on_list_item_clicked)
	gecko_list.item_activated.connect(_on_list_selected)
	partner_option.item_selected.connect(_on_partner_selected)
	breed_button.pressed.connect(_on_breed_pressed)
	rename_button.pressed.connect(_on_rename_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(_on_close_pressed)

func show_inventory(geckos: Array, _current_scenario: String = "") -> void:
	root.visible = true
	dimmer.visible = true
	visible = true
	_geckos = []
	for entry in geckos:
		if entry is GeckoEntity:
			_geckos.append(entry)
	_populate_list()
	gecko_list.grab_focus()

func refresh_inventory(geckos: Array, _current_scenario: String = "") -> void:
	var previous := _selected
	var previous_partner := _partner
	_geckos = []
	for entry in geckos:
		if entry is GeckoEntity:
			_geckos.append(entry)
	_populate_list(previous, previous_partner)

func hide_overlay() -> void:
	dimmer.visible = false
	root.visible = false
	visible = false
	_clear_preview()
	_selected = null
	_partner = null

func _populate_list(preselected: GeckoEntity = null, pre_partner: GeckoEntity = null) -> void:
	gecko_list.clear()
	for gecko in _geckos:
		var label := "%s [%s] (%s)" % [gecko.gecko_name, gecko.sex, gecko.habitat.capitalize()]
		gecko_list.add_item(label)
	if _geckos.is_empty():
		_set_selected(null)
		return
	var index: int = max(_geckos.find(preselected), 0)
	gecko_list.select(index)
	_set_selected(_geckos[index])
	if pre_partner and pre_partner in _geckos and pre_partner != _selected:
		_set_partner(pre_partner)
	else:
		_set_partner(_find_first_partner())

func _on_list_selected(index: int) -> void:
	if index < 0 or index >= _geckos.size():
		return
	_set_selected(_geckos[index])
	_set_partner(_find_first_partner())

func _on_list_item_clicked(index: int, _at_position: Vector2, _button_index: int, _shift_pressed: bool = false) -> void:
	_on_list_selected(index)

func _set_selected(gecko: GeckoEntity) -> void:
	_selected = gecko
	_update_details()
	_update_action_buttons()
	_update_preview()
	_update_partner_options()

func _set_partner(gecko: GeckoEntity) -> void:
	_partner = gecko
	_update_partner_options()
	_update_punnett_preview()

func _find_first_partner() -> GeckoEntity:
	if not _selected:
		return null
	for gecko in _geckos:
		if gecko != _selected and gecko.sex != _selected.sex:
			return gecko
	return null

func _update_details() -> void:
	if not _selected:
		name_label.text = "No gecko selected"
		sex_label.text = "Sex: -"
		habitat_label.text = "Habitat: -"
		generation_label.text = "Gen: -"
		info_label.text = ""
		return
	name_label.text = _selected.gecko_name
	sex_label.text = "Sex: %s" % _selected.sex
	habitat_label.text = "Habitat: %s" % _selected.habitat.capitalize()
	generation_label.text = "Gen: %d" % _selected.generation
	info_label.text = _selected.get_info_text()

func _update_action_buttons() -> void:
	var has_selection := _selected != null
	breed_button.disabled = not has_selection or _partner == null
	rename_button.disabled = not has_selection
	delete_button.disabled = not has_selection
	partner_option.disabled = not has_selection

func _on_partner_selected(index: int) -> void:
	if index < 0 or index >= partner_option.item_count:
		return
	var partner_id: GeckoEntity = partner_option.get_item_metadata(index) as GeckoEntity
	_partner = partner_id
	_update_action_buttons()
	_update_punnett_preview()

func _on_breed_pressed() -> void:
	if not _selected or not _partner:
		return
	breed_requested.emit(_selected, _partner)
	hide_overlay()
	closed.emit()

func _on_rename_pressed() -> void:
	if not _selected:
		return
	rename_requested.emit(_selected)

func _on_delete_pressed() -> void:
	if not _selected:
		return
	delete_requested.emit(_selected)

func _on_close_pressed() -> void:
	hide_overlay()
	closed.emit()

func _update_preview() -> void:
	_clear_preview()
	if not _selected or not gecko_scene:
		return
	_preview_instance = gecko_scene.instantiate()
	_preview_instance.initialize(_selected.genes, _selected.gecko_name, _selected.generation, _selected.parents, _selected.sex, _selected.habitat)
	_preview_instance.set_selected(false)

func _clear_preview() -> void:
	if _preview_instance and is_instance_valid(_preview_instance):
		_preview_instance.queue_free()
	_preview_instance = null

func _update_partner_options() -> void:
	partner_option.clear()
	if not _selected:
		partner_option.disabled = true
		return
	var index := 0
	var selected_index := -1
	for gecko in _geckos:
		if gecko == _selected:
			continue
		var label := "%s [%s]" % [gecko.gecko_name, gecko.sex]
		partner_option.add_item(label)
		partner_option.set_item_metadata(index, gecko)
		if gecko == _partner:
			selected_index = index
		index += 1
	if partner_option.item_count == 0:
		partner_option.disabled = true
		partner_option.text = "No partner"
		_partner = null
		_update_punnett_preview()
		_update_action_buttons()
		return
	partner_option.disabled = false
	partner_option.select(max(selected_index, 0))
	_partner = partner_option.get_item_metadata(partner_option.get_selected()) as GeckoEntity
	_update_punnett_preview()
	_update_action_buttons()

func _update_punnett_preview() -> void:
	if not _selected or not _partner:
		punnett_label.text = "Select two geckos to preview the Punnett square."
		return
	var data := GeneticsSystem.build_punnett_data(_selected.genes, _partner.genes)
	if data.is_empty():
		punnett_label.text = "Punnett data unavailable for this pairing."
		return
	punnett_label.text = _build_punnett_text(data)

func _build_punnett_text(entries: Array) -> String:
	var blocks: PackedStringArray = []
	for entry in entries:
		var trait_name: String = entry.get("trait_name", entry.get("trait_key", "Trait"))
		blocks.append("[b]%s[/b]" % trait_name)
		var table := _build_punnett_table(entry)
		if not table.is_empty():
			blocks.append("[code]%s[/code]" % table)
	return "\n\n".join(blocks)

func _build_punnett_table(entry: Dictionary) -> String:
	var parent_a: PackedStringArray = entry.get("parent_a", PackedStringArray())
	var parent_b: PackedStringArray = entry.get("parent_b", PackedStringArray())
	var grid: Array = entry.get("grid", [])
	if parent_a.is_empty() or parent_b.is_empty():
		return ""
	var cell_width := 3
	for allele in parent_a:
		cell_width = max(cell_width, String(allele).length())
	for allele in parent_b:
		cell_width = max(cell_width, String(allele).length())
	for row in grid:
		for cell in row:
			cell_width = max(cell_width, String(cell).length())
	cell_width += 2
	var lines: Array = []
	var header := [""]
	for allele in parent_b:
		header.append(String(allele))
	lines.append(_format_row(header, cell_width))
	lines.append(_build_separator(header.size(), cell_width))
	for i in range(min(parent_a.size(), grid.size())):
		var row := [String(parent_a[i])]
		var combos: Array = grid[i]
		for cell in combos:
			row.append(String(cell))
		lines.append(_format_row(row, cell_width))
	return "\n".join(lines)

func _format_row(cells: Array, cell_width: int) -> String:
	var padded: Array = []
	for cell in cells:
		padded.append(_pad_cell(String(cell), cell_width))
	return " | ".join(padded)

func _build_separator(columns: int, cell_width: int) -> String:
	var segment := _repeat_char("-", cell_width)
	var parts: Array = []
	for _i in range(columns):
		parts.append(segment)
	return "+".join(parts)

func _pad_cell(value: String, cell_width: int) -> String:
	var text := value
	if text.is_empty():
		text = " "
	var diff := cell_width - text.length()
	if diff <= 0:
		return text
	var left := diff / 2
	var right := diff - left
	return _repeat_char(" ", left) + text + _repeat_char(" ", right)

func _repeat_char(char: String, count: int) -> String:
	var result := ""
	for _i in range(max(count, 0)):
		result += char
	return result
