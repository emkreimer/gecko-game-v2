class_name QuestOverlay
extends CanvasLayer

signal closed

@onready var dimmer: ColorRect = %Dimmer
@onready var root: Control = %Root
@onready var quest_list_label: RichTextLabel = %QuestList
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	hide_overlay()
	close_button.pressed.connect(_on_close_pressed)

func show_quests(quests: Array) -> void:
	root.visible = true
	dimmer.visible = true
	visible = true
	quest_list_label.text = _build_text(quests)
	close_button.grab_focus()

func hide_overlay() -> void:
	dimmer.visible = false
	root.visible = false
	visible = false

func _build_text(quests: Array) -> String:
	var blocks: PackedStringArray = []
	for quest in quests:
		var status_symbol := "[color=lime]✔[/color]" if quest.get("completed", false) else "[color=yellow]○[/color]"
		var title := quest.get("title", quest.get("id", "Quest")) as String
		var description := quest.get("description", "") as String
		var progress := quest.get("progress", "") as String
		var block := "%s  [b]%s[/b]\n%s" % [status_symbol, title, description]
		if not progress.is_empty():
			block += "\n[i]%s[/i]" % progress
		blocks.append(block)
	if blocks.is_empty():
		return "No quests yet."
	return "\n\n".join(blocks)

func _on_close_pressed() -> void:
	hide_overlay()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()
