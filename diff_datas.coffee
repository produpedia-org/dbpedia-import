import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
# import { input } from 'https://raw.githubusercontent.com/johnsonjo4531/read_lines/v2.1.0/input.ts'
import { input as readLine } from "https://raw.githubusercontent.com/phil294/read_lines/v3.0.1/input.ts"
# import readFile from "https://raw.githubusercontent.com/muhibbudins/deno-readfile/master/index.ts"
import readFile from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query from './query.js'

do =>
	json_2016 = JSON.parse await readFile "data/data-Smartphone-transformed_2016.json"
	json_2019 = JSON.parse await readFile "data/data-Smartphone-transformed_2019.json"

	mapping = JSON.parse await readFile "mappings/mapping-dbr:Smartphone.json"
	nonexportable_predicates = mapping.relevant_predicates
		.filter (p) => p.export == false
		.map 'predicate'

	resources_2019 = json_2019.rows.map 'resource'
	resources_2016 = json_2016.rows.map 'resource'
	# predicates = json_2019.predicates

	deleted_resources = resources_2016.filter (resource) =>
		not resources_2019.includes resource

	added_rows = json_2019.rows.filter (row) =>
		not resources_2016.includes row.resource

	kept_rows1 = json_2016.rows.filter (row) =>
		resources_2019.includes row.resource
	kept_rows2 = json_2019.rows.filter (row) =>
		resources_2016.includes row.resource

	# json_2016 = undefined; json_2019 = undefined; resources_2016 = undefined; resources_2019 = undefined
	
	# console.log deleted_resources.length, added_rows.length, kept_rows1.length, kept_rows2.length

	changed_rows = []
	
	for row1 from kept_rows1
		row2 = kept_rows2.find (r) => r.resource == row1.resource

		changes = {}
		
		predicates1 = Object.keys(row1).filter (p) => not nonexportable_predicates.includes p
		predicates2 = Object.keys(row2).filter (p) => not nonexportable_predicates.includes p
		
		changes.deleted_predicates = predicates1.filter (p) =>
			not predicates2.includes p
		
		changes.added_identifiers = predicates2
			.filter (p) =>
				not predicates1.includes p
			.map (p) =>
				row2[p]

		kept_predicates = predicates1.filter (p) =>
			predicates2.includes p

		changes.updated_identifiers = kept_predicates
			.filter (p) =>
				row1[p] != row2[p]
			.map (p) =>
				predicate: p
				from: row1[p]
				to: row2[p]
		
		for k, v of changes
			if not v.length
				delete changes[k]
		
		if Object.keys(changes).length
			#console.log row1.resource, changes
			#await readLine 'continue...'
			changed_rows.push
				resource: row1.resource
				diffs: changes

	diffs = { deleted_resources, added_rows, changed_rows }

	console.debug "#{resources_2016.length} rows 2016, #{resources_2019.length} rows 2019: #{deleted_resources.length} deleted, #{added_rows.length} added, #{changed_rows.length} changed"

	console.debug gray dim 'write out json...'
	await writeFile "data/data-diff.json", JSON.stringify { diffs } 