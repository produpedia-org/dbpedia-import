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
	
	defining_identifiers = [
		{ predicate: 'rdf:type', object: "dbo:#{resource_name}" }
	]

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

	relevant_predicates = new Set

	console.debug "get each relevant values"
	for subject, i in subjects
		data_row = {}
		data.push data_row
		data_row.resource = subject
		console.debug dim "#{i+1} / #{subjects.length}"
		subject_results = await query """
				select ?predicate ?object ?objectRedirectsTo ?objectLabel ?predicateLabel where {
				#{sparql_uri_escape subject} ?predicate ?object .
				OPTIONAL { ?object dbo:wikiPageRedirects ?objectRedirectsTo } .
				OPTIONAL { ?object rdfs:label ?objectLabel } .
				OPTIONAL { ?predicate rdfs:label ?predicateLabel } .
			}"""
		for identifier from subject_results
			if identifier.predicate.match(/^dbo:.+/) or identifier.predicate == 'rdfs:label'
				relevant_predicates.add identifier.predicate
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
				# console.dir identifier
				if identifier.predicateLabel
					# This will be done unnecessarily over and over again, only
					# would need this once per predicate
					# but that's ok as the performance problem is
					# neglectible here
					labels[identifier.predicate] = identifier.predicateLabel
		for predicate, values of data_row
			if Array.isArray(values)
				data_row[predicate] = values.map((v) => v.split(';')).flat().filter(Boolean).uniq().sort().join ';'

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}.json", JSON.stringify
		predicates: [ 'resource', ...relevant_predicates ]
		rows: data
		labels: labels