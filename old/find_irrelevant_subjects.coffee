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
	# actual final relevant predicates. a subject that has a few of those is very likely a {resource_name}
	attribute_predicates = mapping.relevant_predicates
		.filter (p) =>
			not p.mapTo and (p.export == undefined or p.export == true)
		.map 'predicate'
	
	# console.log attribute_predicates

	try json = JSON.parse await readFile "data/data-#{resource_name}-transformed.json"
	if not json
		console.error 'No matching data file found'
		Deno.exit 3
	data = json.rows
	base_predicates = json.predicates

	likely_irrelevants = data
		.filter (row) =>
			attribute_count = Object.keys(row)
				.filter((predicate) =>
					attribute_predicates.includes(predicate))
			attribute_count < 2

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}-transformed-likely-irrelevant-resources.json", JSON.stringify
		predicates: base_predicates
		rows: likely_irrelevants