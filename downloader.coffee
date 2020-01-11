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
	
	query_conditions = defining_identifiers
		.map (identifier) =>
			"{ ?subject <#{identifier.predicate}> #{
				if identifier.object.match /^http:\/\/dbpedia\.org/
					"<#{identifier.object}>"
				# TODO:
				else "\"#{identifier.object}\"^^rdf:langString"
			} }"
		.join "\nUNION\n"
	query_optionals = relevant_predicates
		.map (predicate) =>
			varname = predicate.replace /[^a-zA-Z_0-9]/g, '_'
			"\nOPTIONAL { ?subject <#{predicate}> ?#{varname} } "
		.join ''
	results = await query """
		select * where { 
			{
				select distinct ?subject where { 
					#{query_conditions} 
				}
			} 
			#{query_optionals}
		}
		LIMIT 10"""

	console.debug dim "#{results.length} rows"
	
	console.debug gray dim 'write out to file...'
	outfile = "tmp/data_#{Date.now()}.json"
	await writeFile outfile, JSON.stringify results