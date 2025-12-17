class_name PunnettOverlay
extends CanvasLayer

@onready var dimmer := $Dimmer
@onready var panel := $Panel
@onready var title_label: Label = %Title
@onready var content_label: RichTextLabel = %Content
@onready var close_button: Button = %CloseButton
@onready var input_catcher := $InputCatcher

var _active := false

func _ready() -> void:
	visible = true
	hide_overlay()
	close_button.pressed.connect(hide_overlay)
	input_catcher.gui_input.connect(_on_input_catcher_gui_input)

func show_punnett(entries: Array) -> void:
	if entries.is_empty():
		hide_overlay()
		return
	_active = true
	dimmer.visible = true
	panel.visible = true
	input_catcher.visible = true
	_set_content(_build_punnett_text(entries))
	close_button.grab_focus()

func hide_overlay() -> void:
	_active = false
	dimmer.visible = false
	panel.visible = false
	input_catcher.visible = false
	_set_content("")

func is_visible_overlay() -> bool:
	return _active

func _on_input_catcher_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		hide_overlay()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_overlay()

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
	lines.append(_format_punnett_row(header, cell_width))
	lines.append(_build_separator(header.size(), cell_width))
	for i in range(min(parent_a.size(), grid.size())):
		var row := [String(parent_a[i])]
		var combos: Array = grid[i]
		for cell in combos:
			row.append(String(cell))
		lines.append(_format_punnett_row(row, cell_width))
	return "\n".join(lines)

func _format_punnett_row(cells: Array, cell_width: int) -> String:
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

func _set_content(text: String) -> void:
	if content_label.has_method("clear"):
		content_label.clear()
	if text.is_empty():
		content_label.text = ""
		print_debug("[PunnettOverlay] content cleared")
		return
	print_debug("[PunnettOverlay] displaying text length %d" % text.length())
	content_label.text = text
