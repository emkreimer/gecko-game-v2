class_name DialogueSystem
extends Node

signal dialogue_started(topic)
signal dialogue_line_displayed(line)
signal dialogue_ended(topic)

const INTRO_DIALOGUE := [
	{"speaker": "Professor Lado", "text": "Welcome to Geckolado Lab! Today we will learn how Mendelian genetics shapes our gecko friends."},
	{"speaker": "Professor Lado", "text": "Each gecko carries two alleles per trait. Uppercase alleles are dominant, lowercase are recessive."},
	{"speaker": "Lab Assistant", "text": "Try selecting two starter geckos. We will help you predict what their hatchling might look like."}
]

const BREEDING_EXPLANATION := [
	{"speaker": "Professor Lado", "text": "When two geckos breed, each contributes one allele for every gene. The combination defines the offspring's genotype."},
	{"speaker": "Professor Lado", "text": "Remember: dominant alleles mask recessive partners, but recessives can hide within heterozygous pairs."}
]

const PUNNETT_SQUARE_EXPLANATION := [
	{"speaker": "Lab Assistant", "text": "Nice pairing! Let's review their Punnett square to see the possible allele mixes."},
	{"speaker": "Lab Assistant", "text": "After the explanation finishes we will hatch the baby and add it to your terrarium."}
]

var _active_topic := ""
var _lines: Array = []
var _index := -1
var _active := false

func is_active() -> bool:
	return _active

func start_dialogue(lines: Array, topic: String = "custom") -> void:
	if lines.is_empty():
		return
	_active_topic = topic
	_lines = lines
	_index = -1
	_active = true
	dialogue_started.emit(topic)
	advance()

func advance() -> void:
	if not _active:
		return
	_index += 1
	if _index >= _lines.size():
		_finish_dialogue()
		return
	dialogue_line_displayed.emit(_lines[_index])

func _finish_dialogue() -> void:
	var topic := _active_topic
	_active = false
	_active_topic = ""
	_lines.clear()
	dialogue_ended.emit(topic)

func get_dialogue(topic: String) -> Array:
	match topic:
		"intro":
			return INTRO_DIALOGUE.duplicate(true)
		"breeding":
			return BREEDING_EXPLANATION.duplicate(true)
		"punnett":
			return PUNNETT_SQUARE_EXPLANATION.duplicate(true)
		_:
			return []

func get_active_topic() -> String:
	return _active_topic
