class_name Gene
extends RefCounted

## Represents a single Mendelian gene that stores two alleles.
var trait_key: String
var gene_name: String
var allele1: String
var allele2: String
var trait_data: Dictionary

func configure(p_trait_key: String, p_trait_data: Dictionary, p_allele1: String, p_allele2: String) -> void:
	trait_key = p_trait_key
	trait_data = p_trait_data
	gene_name = p_trait_data.get("gene_name", trait_key.capitalize())
	allele1 = p_allele1
	allele2 = p_allele2

func get_genotype() -> String:
	return allele1 + allele2

func get_alleles() -> PackedStringArray:
	return PackedStringArray([allele1, allele2])

func is_homozygous() -> bool:
	return allele1 == allele2

func is_heterozygous() -> bool:
	return allele1 != allele2

func get_allele_data(code: String) -> Dictionary:
	return trait_data.get("alleles", {}).get(code, {})

func get_phenotype_data() -> Dictionary:
	var allele_one := get_allele_data(allele1)
	var allele_two := get_allele_data(allele2)
	if allele_one.get("dominant", false) and not allele_two.get("dominant", false):
		return allele_one
	if allele_two.get("dominant", false) and not allele_one.get("dominant", false):
		return allele_two
	if allele_one.is_empty():
		return allele_two
	if allele_two.is_empty():
		return allele_one
	if allele_one == allele_two:
		return allele_one
	return allele_one

func get_phenotype_description() -> String:
	var phenotype := get_phenotype_data()
	return phenotype.get("description", phenotype.get("name", gene_name))

func get_gamete(random: RandomNumberGenerator = null) -> String:
	var rng := random if random != null else RandomNumberGenerator.new()
	if random == null:
		rng.randomize()
	return allele1 if rng.randi_range(0, 1) == 0 else allele2

func serialize() -> Dictionary:
	return {
		"trait": trait_key,
		"allele1": allele1,
		"allele2": allele2
	}

static func from_serialized(data: Dictionary, p_trait_data: Dictionary) -> Gene:
	var gene := Gene.new()
	gene.configure(data.get("trait", ""), p_trait_data, data.get("allele1", ""), data.get("allele2", ""))
	return gene
