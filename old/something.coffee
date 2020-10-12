import './global.js'
# import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
import { readJson } from 'https://deno.land/std/fs/mod.ts';
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query, { sparql_uri_escape } from './query.js'

do =>
	resource = "MobilePhone"
	conditions = [
		{ predicate: "gold:hypernym", object: "dbr:#{resource}" }
		{ predicate: "dbp:type", object: "dbr:#{resource}" }
		{ predicate: "dbo:type", object: "dbr:#{resource}" }
		{ predicate: "dbp:type", object: resource }
		{ predicate: "rdf:type", object: "dbr:#{resource}" }
		{ predicate: "rdf:type", object: "dbo:#{resource}" }
	]
	for condition from conditions 
		result = await query """
			select count(*) as ?count where {
				?subject #{sparql_uri_escape condition.predicate} #{
					if not condition.object.match /^[a-z]+:.+/
						# TODO
						"\"#{condition.object}\"^^rdf:langString"
					else
						sparql_uri_escape condition.object
				}
			}"""
		# condition.subjects = result.map (s) => s.subject
		console.log "#{result[0].count} x #{JSON.stringify condition}"