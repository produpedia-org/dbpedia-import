import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
# import readFile from "https://raw.githubusercontent.com/muhibbudins/deno-readfile/master/index.ts"
import readFile from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query, { sparql_uri_escape } from './query.js'

do =>
	resource_name = Deno.args[0]
	if not resource_name
		console.error 'Please pass the case-sensitive resource as argument, e.g. "Smartphone" for mapping-dbr:Smartphone'
		Deno.exit 1

	mappings_file = "mappings/mapping-dbr:#{resource_name}.json"
	try existing_mapping = JSON.parse await readFile mappings_file
	if not existing_mapping
		console.error "No matching file found (#{mappings_file})"
		Deno.exit 2
		
	{ defining_identifiers, relevant_predicates } = existing_mapping

	relevant_predicates = relevant_predicates.map 'predicate'
	relevant_predicates.push 'rdfs:label'

	data = []
	
	console.debug dim "get all subjects"
	subject_query_conditions = defining_identifiers
		.map (identifier) =>
			"{ ?subject #{identifier.predicate} #{
				if not identifier.object.match /^[a-z]+:.+/
					# TODO
					"\"#{identifier.object}\"^^rdf:langString"
				else
					sparql_uri_escape identifier.object
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
		.uniq()

	labels = {}

	console.debug "get each relevant values"
	for subject, i in subjects
		data_row = {}
		data.push data_row
		data_row.resource = subject
		console.debug dim "#{i+1} / #{subjects.length}"
		subject_results = await query """
				select ?predicate ?object ?objectRedirectsTo ?objectLabel where {
				#{sparql_uri_escape subject} ?predicate ?object .
				OPTIONAL { ?object dbo:wikiPageRedirects ?objectRedirectsTo } .
				OPTIONAL { ?object rdfs:label ?objectLabel } .
			}"""
		for identifier from subject_results
			if relevant_predicates.includes identifier.predicate
				# Some basic escaping (leading asterisks, whitespace...)
				object = (identifier.objectRedirectsTo or identifier.object)
					.replace(/&[a-zA-Z]+;/g, '')
					.replace(/\n/g, ';')
					.replace(/ +/g, ' ')
					.replace(/(^|;) *\*? */g, '$1')
					.replace(/(^|;);/g, '$1')
					.trim()
				if not object
					continue
				if data_row[identifier.predicate]
					data_row[identifier.predicate].push object
				else
					data_row[identifier.predicate] = [ object ]
				if identifier.objectLabel
					labels[object] = identifier.objectLabel
		for predicate, values of data_row
			if Array.isArray(values)
				data_row[predicate] = values.map((v) => v.split(';')).flat().filter(Boolean).uniq().sort().join ';'

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}.json", JSON.stringify
		predicates: [ 'resource', ...relevant_predicates ]
		rows: data
		labels: labels