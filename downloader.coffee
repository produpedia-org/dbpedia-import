import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
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

	relevant_predicates.push 'rdfs:label'

	data = []
	
	console.debug dim "get all subjects"
	subject_query_conditions = defining_identifiers
		.map (identifier) =>
			"{ ?subject <#{identifier.predicate}> #{
				if not identifier.object.match /^[a-z]+:.+/
					# TODO
					"\"#{identifier.object}\"^^rdf:langString"
			} }"
		.join "\nUNION\n"
	all_results = await query """
		select distinct ?subject ?redirectsTo where {
			#{subject_query_conditions}
			OPTIONAL { ?subject dbo:wikiPageRedirects ?redirectsTo }
			LIMIT 1
		}""" # fixme try out formatting at the end of file first
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
		subject_results = await query "select * where { #{subject} ?predicate ?object }"
		for identifier from subject_results
			if relevant_predicates.includes identifier.predicate
				if data_row[identifier.predicate]
					data_row[identifier.predicate] = data_row[identifier.predicate] + "," + identifier.object
				else
					data_row[identifier.predicate] = identifier.object

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}.json", JSON.stringify
		predicates: [ 'resource', ...relevant_predicates ]
		rows: data