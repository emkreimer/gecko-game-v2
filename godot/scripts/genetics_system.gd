class_name GeneticsSystem
extends RefCounted

const TRAITS := {
	"color": {
		"gene_name": "Body Color",
		"alleles": {
			"B": {"name": "Midnight Black", "dominant": false, "color": Color(0.1, 0.1, 0.1), "description": "Black hide."},
			"R": {"name": "Ruby Red", "dominant": true, "color": Color(0.91, 0.32, 0.32), "description": "Ruby hide."},
			"O": {"name": "Sunset Orange", "dominant": true, "color": Color(0.99, 0.55, 0.21), "description": "Orange hide."},
			"y": {"name": "Lemon Yellow", "dominant": false, "color": Color(0.99, 0.91, 0.37), "description": "Lemon hide."},
			"w": {"name": "White", "dominant": false, "color": Color(1, 1, 1), "description": "White hide."},
			"p": {"name": "Pale Pink", "dominant": false, "color": Color(1.0, 0.75, 0.8), "description": "Pale pink hide."}
		}
	},
	"eye_color": {
		"gene_name": "Eye Color",
		"alleles": {
			"G": {"name": "Emerald", "dominant": true, "color": Color(0.3, 0.78, 0.43), "description": "Bright emerald eyes."},
			"B": {"name": "Cobalt", "dominant": true, "color": Color(0.24, 0.48, 0.93), "description": "Cool cobalt eyes."},
			"g": {"name": "Hazel", "dominant": false, "color": Color(0.59, 0.44, 0.18), "description": "Mellow hazel eyes."},
			"y": {"name": "Yellow", "dominant": false, "color": Color(0.91, 0.65, 0.26), "description": "Warm yellow eyes."}
		}
	},
	"pattern": {
		"gene_name": "Pattern",
		"alleles": {
			"S": {"name": "Spotted", "dominant": true, "spots_visible": true, "description": "Spotted hide."},
			"s": {"name": "Smooth", "dominant": false, "spots_visible": false, "description": "Uniform scales."}
		}
	},
	"size": {
		"gene_name": "Size",
		"alleles": {
			"L": {"name": "Large", "dominant": true, "scale": 1.15, "description": "Large."},
			"m": {"name": "Medium", "dominant": false, "scale": 1.0, "description": "Balanced."},
			"s": {"name": "Small", "dominant": false, "scale": 0.85, "description": "Small."}
		}
	},
	"tail": {
		"gene_name": "Tail",
		"alleles": {
			"T": {"name": "Thick", "dominant": true, "scale": 1.1, "description": "Thick tail."},
			"t": {"name": "Slender", "dominant": false, "scale": 0.9, "description": "Whip-like tail."}
		}
	}
}

static func create_gene(trait_key: String, allele_a: String, allele_b: String) -> Gene:
	var trait_data: Dictionary = TRAITS.get(trait_key, {})
	var gene := Gene.new()
	gene.configure(trait_key, trait_data, allele_a, allele_b)
	return gene

static func create_random_gene(trait_key: String, rng: RandomNumberGenerator) -> Gene:
	var alleles: Dictionary = TRAITS.get(trait_key, {}).get("alleles", {})
	var keys: Array = alleles.keys()
	var allele_a: String = keys[rng.randi_range(0, keys.size() - 1)]
	var allele_b: String = keys[rng.randi_range(0, keys.size() - 1)]
	return create_gene(trait_key, allele_a, allele_b)

static func create_random_genes() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var genes := {}
	for trait_key in TRAITS.keys():
		genes[trait_key] = create_random_gene(trait_key, rng)
	return genes

static func create_diverse_starting_pair() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var color_alleles: Array = TRAITS["color"]["alleles"].keys()
	color_alleles.shuffle()
	
	var genes_a := {}
	for trait_key in TRAITS.keys():
		if trait_key == "color":
			genes_a[trait_key] = create_gene(trait_key, color_alleles[0], color_alleles[1])
		else:
			genes_a[trait_key] = create_random_gene(trait_key, rng)
	
	var genes_b := {}
	for trait_key in TRAITS.keys():
		if trait_key == "color":
			var idx_a := 2 if color_alleles.size() > 2 else 0
			var idx_b := 3 if color_alleles.size() > 3 else 1
			genes_b[trait_key] = create_gene(trait_key, color_alleles[idx_a], color_alleles[idx_b])
		else:
			genes_b[trait_key] = create_random_gene(trait_key, rng)
	
	return [genes_a, genes_b]

static func breed(parent_a: Dictionary, parent_b: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var child := {}
	for trait_key in TRAITS.keys():
		var gene_a: Gene = parent_a.get(trait_key)
		var gene_b: Gene = parent_b.get(trait_key)
		if gene_a == null or gene_b == null:
			continue
		child[trait_key] = create_gene(trait_key, gene_a.get_gamete(rng), gene_b.get_gamete(rng))
	return child

static func get_phenotype_summary(genes: Dictionary) -> Dictionary:
	var summary := {}
	for trait_key in TRAITS.keys():
		var gene: Gene = genes.get(trait_key)
		if gene == null:
			continue
		summary[trait_key] = {
			"title": gene.gene_name,
			"genotype": gene.get_genotype(),
			"description": gene.get_phenotype_description(),
			"data": gene.get_phenotype_data()
		}
	return summary

static func build_info_text(genes: Dictionary) -> String:
	var parts: PackedStringArray = []
	var summary := get_phenotype_summary(genes)
	for trait_key in TRAITS.keys():
		if not summary.has(trait_key):
			continue
		var data: Dictionary = summary[trait_key]
		parts.append("%s: %s (%s)" % [data.get("title", trait_key.capitalize()), data.get("description", ""), data.get("genotype", "??")])
	return "\n".join(parts)

static func serialize_genes(genes: Dictionary) -> Array:
	var serialized: Array = []
	for trait_key in TRAITS.keys():
		var gene: Gene = genes.get(trait_key)
		if gene == null:
			continue
		serialized.append(gene.serialize())
	return serialized

static func deserialize_genes(serialized: Array) -> Dictionary:
	var genes := {}
	for entry in serialized:
		if not entry is Dictionary:
			continue
		var trait_key: String = entry.get("trait", "")
		if not TRAITS.has(trait_key):
			continue
		genes[trait_key] = create_gene(trait_key, entry.get("allele1", ""), entry.get("allele2", ""))
	return genes

static func clamp_trait_order(genes: Dictionary) -> Array:
	var ordered: Array = []
	for trait_key in TRAITS.keys():
		var gene: Gene = genes.get(trait_key)
		if gene:
			ordered.append(gene)
	return ordered

static func build_punnett_data(parent_a_genes: Dictionary, parent_b_genes: Dictionary) -> Array:
	var entries: Array = []
	for trait_key in TRAITS.keys():
		var gene_a: Gene = parent_a_genes.get(trait_key)
		var gene_b: Gene = parent_b_genes.get(trait_key)
		if gene_a == null or gene_b == null:
			continue
		var alleles_a: PackedStringArray = gene_a.get_alleles()
		var alleles_b: PackedStringArray = gene_b.get_alleles()
		var grid: Array = []
		for allele_a in alleles_a:
			var row: Array = []
			for allele_b in alleles_b:
				row.append(String(allele_a) + String(allele_b))
			grid.append(row)
		entries.append({
			"trait_key": trait_key,
			"trait_name": gene_a.gene_name,
			"parent_a": alleles_a.duplicate(),
			"parent_b": alleles_b.duplicate(),
			"grid": grid
		})
	return entries
