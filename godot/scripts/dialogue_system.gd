class_name DialogueSystem
extends Node

signal dialogue_started(topic)
signal dialogue_line_displayed(line)
signal dialogue_ended(topic)

const BREEDING_EXPLANATION := [
	{"speaker": "", "text": "When two geckos breed, each contributes one allele for every gene. The combination defines the offspring's genotype."},
	{"speaker": "", "text": "Pick one male and one female partner to make a viable clutch."},
	{"speaker": "", "text": "Dominant alleles mask recessive partners, but recessives can hide within heterozygous pairs."}
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

func build_intro_primary(speaker_name: String) -> Array:
	return [
		{"speaker": speaker_name, "text": "Hi! I'm %s. You must be new around here, right?" % [speaker_name]},
		{"speaker": speaker_name, "text": "Don’t worry, you’ll fit right in. Our little gecko community is always growing."},
		{"speaker": speaker_name, "text": "Around here, no two geckos are exactly alike."},
		{"speaker": speaker_name, "text": "That’s not random — it all comes down to how traits are passed on."},
	]

func build_spouse_intro(guide_name: String, spouse_name: String) -> Array:
	return [
		{"speaker": guide_name, "text": "Oh! And this is %s — my partner." % [spouse_name]},
		{"speaker": spouse_name, "text": "Hi there! Nice to meet you."},
		{"speaker": guide_name, "text": "Together, we each pass along genes to our offspring."},
		{"speaker": guide_name, "text": "Some traits are dominant and easy to spot, while others are recessive and can stay hidden for generations."},
		{"speaker": spouse_name, "text": "Think of it like a genetic coin flip — each parent contributes one allele."},
	]

func build_breeding_prompt(guide_name: String, spouse_name: String) -> Array:
	return [
		{"speaker": guide_name, "text": "Try selecting me and %s. You'll see our Punnett square and hatch a baby in the terrarium." % spouse_name},
		{"speaker": spouse_name, "text": "Remember: you need one male and one female to breed. Switch scenes any time with the Explore button."}
	]

func get_dialogue(topic: String) -> Array:
	match topic:
		"intro":
			return []
		"breeding":
			return BREEDING_EXPLANATION.duplicate(true)
		"punnett":
			return PUNNETT_SQUARE_EXPLANATION.duplicate(true)
		_:
			return []

func get_active_topic() -> String:
	return _active_topic
