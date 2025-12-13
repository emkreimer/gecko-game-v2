class_name DialogueBox
extends PanelContainer

signal advance_requested

@export var characters_per_second := 40.0

@onready var speaker_label := %SpeakerLabel
@onready var text_label := %TextLabel
@onready var continue_label := %ContinueLabel
@onready var type_timer := %TypeTimer

var _full_text := ""
var _visible_chars := 0
var _typing := false

func display_line(line: Dictionary) -> void:
	visible = true
	_full_text = line.get("text", "")
	_visible_chars = 0
	_typing = true
	speaker_label.text = line.get("speaker", "")
	text_label.text = ""
	continue_label.visible = false
	var cps: float = max(characters_per_second, 1.0)
	type_timer.wait_time = 1.0 / cps
	type_timer.start()

func hide_dialogue() -> void:
	visible = false
	_typing = false
	type_timer.stop()
	continue_label.visible = false

func request_advance() -> void:
	if _typing:
		_finish_typing()
		return
	advance_requested.emit()

func _finish_typing() -> void:
	_typing = false
	type_timer.stop()
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
