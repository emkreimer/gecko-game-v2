class_name GeneDictionaryOverlay
extends CanvasLayer

const GeneticsSystem = preload("res://scripts/mechanics/genetics_system.gd")

@onready var dimmer := $Dimmer
@onready var panel := $Panel
@onready var title_label: Label = %Title
@onready var content_label: RichTextLabel = %Content
@onready var close_button: Button = %CloseButton
@onready var input_catcher := $InputCatcher

var _active := false

func _ready() -> void:
	hide_overlay()
	close_button.pressed.connect(hide_overlay)
	input_catcher.gui_input.connect(_on_input_catcher_gui_input)

func show_dictionary() -> void:
	_set_content(_build_content())
	_active = true
	visible = true
	dimmer.visible = true
	panel.visible = true
	input_catcher.visible = true
	title_label.text = tr("gene_dictionary")
	close_button.grab_focus()

func hide_overlay() -> void:
	_active = false
	visible = false
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

func _build_content() -> String:
	var blocks: PackedStringArray = []
	blocks.append("[b]" + tr("gene_dictionary") + "[/b]")
	for trait_key in _sorted_keys(GeneticsSystem.TRAITS):
		var trait_data: Dictionary = GeneticsSystem.TRAITS[trait_key]
		blocks.append(_build_trait_section(trait_key, trait_data))
	blocks.append("[b]Allele Interaction[/b]")
	blocks.append(_build_interaction_text())
	return "\n\n".join(blocks)

func _sorted_keys(data: Dictionary) -> Array:
	var keys: Array = data.keys()
	keys.sort_custom(func(a, b): return String(a).to_lower() < String(b).to_lower())
	return keys

func _build_trait_section(trait_key: String, trait_data: Dictionary) -> String:
	var lines: PackedStringArray = []
	var gene_title: String = trait_data.get("gene_name", trait_key.capitalize())
	lines.append("[color=#9ad4ff][b]%s[/b][/color]" % gene_title)
	var alleles: Dictionary = trait_data.get("alleles", {})
	var allele_keys := _sorted_keys(alleles)
	if allele_keys.is_empty():
		lines.append("[i](no alleles defined)[/i]")
		return "\n".join(lines)
	for key in allele_keys:
		var data: Dictionary = alleles.get(key, {})
		var is_dominant: bool = data.get("dominant", false)
		var dominance_rank: int = data.get("dominance_rank", 0)
		var dominance_text := tr("dominant") if is_dominant else tr("recessive")
		var dominance_color := "#ffd166" if is_dominant else "#9ee7a3"
		var name: String = data.get("name", String(key))
		var desc: String = data.get("description", "")
		lines.append("- [code]%s[/code] [color=%s]%s (rank %d)[/color] | %s" % [key, dominance_color, dominance_text, dominance_rank, name])
		if not desc.is_empty():
			lines.append("  %s" % desc)
	return "\n".join(lines)

func _build_interaction_text() -> String:
	var lines: PackedStringArray = []
	lines.append("- [b]Dominance Rank:[/b] The allele with the higher rank is expressed in the phenotype.")
	lines.append("- Dominant alleles have positive ranks, recessive alleles have non-positive ranks.")
	lines.append("- When two alleles have the same rank, they're co-dominant (first one shown).")
	lines.append("- Identical alleles: that allele shows; the gecko is homozygous for the trait.")
	lines.append("- [i]Example:[/i] RO genotype → Red shows (rank 2 > rank 1)")
	lines.append("- [i]Example:[/i] wb genotype → White shows (rank -2 > rank -3)")
	lines.append("- Uppercase letters usually mark dominant alleles; lowercase are recessive.")
	return "\n".join(lines)

func _set_content(text: String) -> void:
	if content_label.has_method("clear"):
		content_label.clear()
	if text.is_empty():
		content_label.text = ""
		return
	content_label.text = text
