import './global.js'
# import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
import { readJson } from 'https://deno.land/std/fs/mod.ts';
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query, { sparql_uri_escape } from './query.js'

do =>
	resource_name = Deno.args[0]
	if not resource_name
		console.error 'Please pass the case-sensitive resource as argument, e.g. "Smartphone" for mapping-dbr:Smartphone'
		Deno.exit 1

	try mapping = await readJson "mappings/mapping-dbr:#{resource_name}.json"
	if not mapping
		console.error 'No matching mapping file found'
		Deno.exit 2

	for identifier from mapping.defining_identifiers
		result = await query """
			select distinct ?subject where {
				?subject #{sparql_uri_escape identifier.predicate} #{
					if not identifier.object.match /^[a-z]+:.+/
						# TODO
						"\"#{identifier.object}\"^^rdf:langString"
					else
						sparql_uri_escape identifier.object
				}
			}"""
		identifier.subjects = result.map (s) => s.subject

	all_subjects = [...new Set(mapping.defining_identifiers
		.map (i) => i.subjects
		.flat())]

	for identifier from mapping.defining_identifiers
		identifier.unique_subjects = identifier.subjects.filter (s) =>
			not mapping.defining_identifiers
				.filter (other) => other != identifier
				.some (other) => other.subjects.includes s
	
	mapping.defining_identifiers.sort (a,b) => b.subjects.length - a.subjects.length
	
	console.log mapping.defining_identifiers.map (i) =>
		{ ...i, subjects: i.subjects.length }
	### actual final relevant predicates. a subject that has a few of those is very likely a {resource_name}
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
	###