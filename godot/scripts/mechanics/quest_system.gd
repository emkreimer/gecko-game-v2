class_name QuestSystem
extends RefCounted

const QUESTS := [
	{
		"id": "blind_gecko",
		"title": "Breed a blind gecko",
		"description": "Hatch a gecko with white eyes (eye color genotype ww)."
	},
	{
		"id": "pale_pink_gecko",
		"title": "Hatch a pale pink gecko",
		"description": "Produce a gecko with pale pink body color (Body Color genotype pp)."
	},
	{
		"id": "tiny_slender_gecko",
		"title": "Raise a tiny slender gecko",
		"description": "Hatch a gecko that is small and slender-tailed (Size ss and Tail tt)."
	},
	{
		"id": "full_house",
		"title": "Fill the terrarium",
		"description": "Keep at least eight geckos alive at once."
	}
]

func evaluate(geckos: Array) -> Array:
	var statuses: Array = []
	for quest in QUESTS:
		var quest_id: String = quest.get("id", "")
		var completed := _is_completed(quest_id, geckos)
		var progress_text := _build_progress_text(quest_id, geckos, completed)
		statuses.append({
			"id": quest_id,
			"title": quest.get("title", quest_id),
			"description": quest.get("description", ""),
			"completed": completed,
			"progress": progress_text
		})
	return statuses

func _is_completed(quest_id: String, geckos: Array) -> bool:
	match quest_id:
		"blind_gecko":
			return _count_genotype(geckos, "eye_color", "w", "w") > 0
		"pale_pink_gecko":
			return _count_genotype(geckos, "color", "p", "p") > 0
		"tiny_slender_gecko":
			return _count_matching_tiny_slender(geckos) > 0
		"full_house":
			return geckos.size() >= 8
		_:
			return false

func _build_progress_text(quest_id: String, geckos: Array, completed: bool) -> String:
	if completed:
		return "Completed!"
	match quest_id:
		"blind_gecko":
			return "Blind geckos owned: %d" % _count_genotype(geckos, "eye_color", "w", "w")
		"pale_pink_gecko":
			return "Pale pink geckos owned: %d" % _count_genotype(geckos, "color", "p", "p")
		"tiny_slender_gecko":
			return "Tiny slender geckos owned: %d" % _count_matching_tiny_slender(geckos)
		"full_house":
			return "Current collection: %d / 8" % geckos.size()
		_:
			return ""

func _count_genotype(geckos: Array, genTrait: String, allele_first: String, allele_second: String) -> int:
	var count := 0
	for gecko in geckos:
		if gecko == null:
			continue
		if _gene_equals(gecko, genTrait, allele_first, allele_second):
			count += 1
	return count

func _count_matching_tiny_slender(geckos: Array) -> int:
	var count := 0
	for gecko in geckos:
		if gecko == null:
			continue
		if _gene_equals(gecko, "size", "s", "s") and _gene_equals(gecko, "tail", "t", "t"):
			count += 1
	return count

func _gene_equals(gecko: Variant, genTrait: String, allele_first: String, allele_second: String) -> bool:
	if gecko == null:
		return false
	if not gecko.genes.has(genTrait):
		return false
	var gene = gecko.genes[genTrait]
	if gene == null:
		return false
	# Check both possible orders of alleles (e.g., Ww = wW)
	return (gene.allele1 == allele_first and gene.allele2 == allele_second) or (gene.allele1 == allele_second and gene.allele2 == allele_first)
