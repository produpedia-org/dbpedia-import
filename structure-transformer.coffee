import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
# import { input } from 'https://raw.githubusercontent.com/johnsonjo4531/read_lines/v2.1.0/input.ts'
import { input as readLine } from "https://raw.githubusercontent.com/phil294/read_lines/v3.0.1/input.ts"
# import readFile from "https://raw.githubusercontent.com/muhibbudins/deno-readfile/master/index.ts"
import readFile from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query from './query.js'

do =>
	resource_name = Deno.args[1]
	if not resource_name
		console.error 'Please pass the case-sensitive resource as argument, e.g. "Smartphone" for mapping-dbr:Smartphone'
		Deno.exit 1

	try mapping = JSON.parse await readFile "mappings/mapping-dbr:#{resource_name}.json"
	if not mapping
		console.error 'No matching mapping file found'
		Deno.exit 2
	relevant_predicates = mapping.relevant_predicates # todo destructuring
	irrelevant_subjects = mapping.irrelevant_subjects # todo

	try json = JSON.parse await readFile "data/data-#{resource_name}.json"
	if not json
		console.error 'No matching data file found'
		Deno.exit 3
	predicates_from_data = json.predicates
	data = json.rows

	### predicates that arent mapped to another predicate ###
	base_predicates = relevant_predicates
		.filter (p) => not p.mapTo
		.map (p) => p.predicate
	invalidly_mapped_predicate = relevant_predicates
		.filter (p) => p.mapTo
		.find (p) => not base_predicates.includes p.mapTo
	if invalidly_mapped_predicate
		throw "Mapping for relevant predicate '#{invalidly_mapped_predicate.predicate}' is invalid: Target mapping '#{invalidly_mapped_predicate.mapTo}' does not exist or is mapped itself"
	base_predicates.unshift 'resource'
		
	transformed_data = []
	for row from data
		if irrelevant_subjects.includes row.resource
			continue
		transformed_row = {}
		transformed_data.push transformed_row
		transformed_row.resource = row.resource
		for predicate from relevant_predicates
			value = row[predicate.predicate]
			if value
				if predicate.mapTo
					if transformed_row[predicate.mapTo]
						transformed_row[predicate.mapTo] = transformed_row[predicate.mapTo] + "," + value
					else
						transformed_row[predicate.mapTo] = value
				else
					if transformed_row[predicate.predicate]
						transformed_row[predicate.predicate] = transformed_row[predicate.predicate] + "," + value
					else
						transformed_row[predicate.predicate] = value
	
	# remove duplicate values
	for row from transformed_data
		for predicate, values of row
			row[predicate] = [...new Set(values.split ',')].sort().join ','

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}-transformed.json", JSON.stringify
		predicates: base_predicates
		rows: transformed_data