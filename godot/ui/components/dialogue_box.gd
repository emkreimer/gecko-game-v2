class_name DialogueBox
extends PanelContainer

signal advance_requested
signal punnett_closed

@export var characters_per_second := 40.0

@onready var speaker_label := $MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_wrapper := $MarginContainer/VBoxContainer/TextWrapper
@onready var text_label := $MarginContainer/VBoxContainer/TextWrapper/TextLabel
@onready var continue_label := $MarginContainer/VBoxContainer/ContinueLabel
@onready var type_timer := $TypeTimer
@onready var punnett_container := $MarginContainer/VBoxContainer/PunnettWrapper
@onready var punnett_label: RichTextLabel = $MarginContainer/VBoxContainer/PunnettWrapper/PunnettVBox/PunnettScroll/PunnettLabel
@onready var punnett_close_button: Button = $MarginContainer/VBoxContainer/PunnettWrapper/PunnettVBox/PunnettCloseButton
@onready var typing_player: AudioStreamPlayer = $TypingAudioPlayer

var _full_text := ""
var _visible_chars := 0
var _typing := false
var _punnett_active := false

func display_line(line: Dictionary) -> void:
	_hide_punnett()
	visible = true
	_full_text = line.get("text", "")
	_visible_chars = 0
	_typing = true
	speaker_label.text = line.get("speaker", "")
	text_label.text = ""
	continue_label.visible = false
	_set_text_visibility(true)
	_start_typing_audio()
	var cps: float = max(characters_per_second, 1.0)
	type_timer.wait_time = 1.0 / cps
	type_timer.start()

func show_punnett(entries: Array) -> void:
	if entries.is_empty():
		_hide_punnett()
		return
	visible = true
	_typing = false
	type_timer.stop()
	_stop_typing_audio()
	_set_text_visibility(false)
	_punnett_active = true
	punnett_container.visible = true
	punnett_label.text = _build_punnett_text(entries)
	continue_label.visible = false
	punnett_close_button.grab_focus()

func hide_dialogue() -> void:
	visible = false
	_typing = false
	type_timer.stop()
	_stop_typing_audio()
	continue_label.visible = false
	_hide_punnett()

func hide_punnett() -> void:
	_hide_punnett()

func request_advance() -> void:
	if _punnett_active:
		_on_punnett_close_pressed()
		return
	if _typing:
		_finish_typing()
		return
	advance_requested.emit()

func _finish_typing() -> void:
	_typing = false
	type_timer.stop()
	_stop_typing_audio()
	text_label.text = _full_text
	continue_label.visible = true

func _on_type_timer_timeout() -> void:
	if not _typing:
		type_timer.stop()
		return
	_visible_chars += 1
	text_label.text = _full_text.substr(0, _visible_chars)
	if _visible_chars >= _full_text.length():
		_finish_typing()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		request_advance()
	elif event.is_action_pressed("ui_accept"):
		request_advance()

func _set_text_visibility(show_text: bool) -> void:
	speaker_label.visible = show_text
	text_wrapper.visible = show_text
	continue_label.visible = show_text and _typing == false and not _full_text.is_empty()

func _hide_punnett() -> void:
	_punnett_active = false
	punnett_container.visible = false
	punnett_label.text = ""
	_set_text_visibility(true)
	_stop_typing_audio()

func _on_punnett_close_pressed() -> void:
	_hide_punnett()
	punnett_closed.emit()

func _build_punnett_text(entries: Array) -> String:
	var blocks: PackedStringArray = []
	for entry in entries:
		var trait_name: String = entry.get("trait_name", entry.get("trait_key", "Trait"))
		blocks.append("[b]%s[/b]" % trait_name)
		var table := _build_punnett_table(entry)
		if not table.is_empty():
			blocks.append("[code]%s[/code]" % table)
	return "\n\n".join(blocks)

func _start_typing_audio() -> void:
	if not typing_player:
		return
	if typing_player.stream is AudioStreamWAV:
		var wav: AudioStreamWAV = typing_player.stream
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if not typing_player.playing:
		typing_player.play()

func _stop_typing_audio() -> void:
	if typing_player:
		typing_player.stop()

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
