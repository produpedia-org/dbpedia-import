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

	try existing_mapping = JSON.parse await readFile "mappings/mapping-dbr:#{resource_name}.json"

	if not existing_mapping
		console.error 'No matching file found'
		Deno.exit 2
		
	{ defining_identifiers, relevant_predicates } = existing_mapping

	relevant_predicates.push 'http://www.w3.org/2000/01/rdf-schema#label'

	data = []
	
	console.debug dim "get all subjects"
	subject_query_conditions = defining_identifiers
		.map (identifier) =>
			"{ ?subject <#{identifier.predicate}> #{
				if identifier.object.match /^http:\/\/dbpedia\.org/
					"<#{identifier.object}>"
				# TODO:
				else "\"#{identifier.object}\"^^rdf:langString"
			} }"
		.join "\nUNION\n"
	all_results = await query """
		select distinct ?subject ?redirectsTo where {
			#{subject_query_conditions}
			OPTIONAL { ?subject dbo:wikiPageRedirects ?redirectsTo }
		}"""
	subjects = all_results
		# todo do this in the query directly? I didnt manage to :(
		.map (r) => r.redirectsTo or r.subject
	# filter out duplicates from redirects
	subjects = [...new Set(subjects)]

	console.debug "get each relevant values"
	for subject, i in subjects
		data_row = {}
		data.push data_row
		data_row.resource = subject
		console.debug dim "#{i+1} / #{subjects.length}"
		subject_results = await query "select * where { <#{subject}> ?predicate ?object }"
		for identifier from subject_results
			if relevant_predicates.includes identifier.predicate
				if data_row[identifier.predicate]
					data_row[identifier.predicate] = data_row[identifier.predicate] + "," + identifier.object
				else
					data_row[identifier.predicate] = identifier.object

	csv_escape = (v) =>
		v = v.replace /"/g, '""'
		"\"#{v}\""
	columns = [ 'resource', ...relevant_predicates ]
	csv = columns.map((col) => csv_escape(col)).join(',') + '\n' +
		data
			.map (row) =>
				columns
					.map (col) =>
						v = row[col] or ''
						csv_escape v
					.join ','
			.join '\n'

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}.json", JSON.stringify data
	console.debug gray dim 'write out to csv...'
	await writeFile "data/data-#{resource_name}.csv", csv