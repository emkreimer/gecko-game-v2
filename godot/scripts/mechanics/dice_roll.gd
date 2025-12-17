class_name DiceRoll
extends Control

signal roll_completed(success: bool)

const ROLL_ANIMATION_DURATION := 1.0
const DICE_FACES := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
const SUCCESS_THRESHOLD := 4  # Need 4 or higher to find a gecko

@onready var dice_label: Label = %DiceLabel
@onready var result_label: Label = %ResultLabel
@onready var roll_button: Button = %RollButton
@onready var close_button: Button = %CloseButton

var _rng := RandomNumberGenerator.new()
var _is_rolling := false

func _ready() -> void:
	_rng.randomize()
	hide()
	roll_button.pressed.connect(_on_roll_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	result_label.hide()

func show_dice_roll() -> void:
	_reset_ui()
	show()
	roll_button.grab_focus()

func _reset_ui() -> void:
	dice_label.text = "🎲"
	result_label.text = ""
	result_label.hide()
	roll_button.disabled = false
	close_button.disabled = true

func _on_roll_button_pressed() -> void:
	if _is_rolling:
		return
	_is_rolling = true
	roll_button.disabled = true
	_animate_roll()

func _animate_roll() -> void:
	var elapsed := 0.0
	var interval := 0.1
	
	while elapsed < ROLL_ANIMATION_DURATION:
		await get_tree().create_timer(interval).timeout
		var random_face := _rng.randi_range(0, DICE_FACES.size() - 1)
		dice_label.text = DICE_FACES[random_face]
		elapsed += interval
	
	var final_roll := _rng.randi_range(1, 6)
	dice_label.text = DICE_FACES[final_roll - 1]
	
	var success := final_roll >= SUCCESS_THRESHOLD
	if success:
		result_label.text = "🎉 You found a gecko!"
		result_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		result_label.text = "😔 Nothing here..."
		result_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	
	result_label.show()
	close_button.disabled = false
	close_button.grab_focus()
	_is_rolling = false
	
	await get_tree().create_timer(0.5).timeout
	roll_completed.emit(success)

func _on_close_button_pressed() -> void:
	hide()
