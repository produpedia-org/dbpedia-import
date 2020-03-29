import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
# import readFile from "https://raw.githubusercontent.com/muhibbudins/deno-readfile/master/index.ts"
import readFile from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query from './query.js'
import { moment } from "https://deno.land/x/moment/moment.ts"

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
	labels = json.labels

	### target mapping targets become the new base predicates ###
	base_predicates = [
		...relevant_predicates
			.filter (p) => not p.mapTo
			.map 'predicate'
	,
		...relevant_predicates
			.map 'mapTo'
	].filter(Boolean).uniq()
	base_predicates.unshift 'resource'
	base_predicates.unshift 'rdfs:label'
	
	transformed_data = []
	for row from data
		if irrelevant_subjects.includes row.resource
			continue
		transformed_row = {}
		transformed_row.resource = row.resource
		transformed_row['rdfs:label'] = row['rdfs:label']
		if not transformed_row['rdfs:label']
			console.warn "#{row.resource} does not have an rdfs:label!"
			continue
		transformed_data.push transformed_row
		for predicate from relevant_predicates
			value = row[predicate.predicate]
			if value
				if predicate.type == 'date'
					value = value
						.split(';')
						.map((v) =>
							if v.length < 4
								return v
							date = Date.parse v
							# chrono also works as a nice fallback
							# (with import 'https://cdn.jsdelivr.net/npm/chrono-node@1.4.3/chrono.min.js')
							# but v8 Date.parse actually supports stuff like
							# "February 2019" natively (contrary to Firefox), so
							# native Date parse suffices here
							# date = window.chrono.parseDate v
							if date
								date = moment(date).format 'YYYY-MM-DD'
							else
								date = v
							date
						)
						.join(';')
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
	
	# each row: remove duplicate values & sort them
	for row from transformed_data
		for predicate, values of row
			row[predicate] = values.split(';').uniq().sort().join ';'

	console.debug gray dim 'write out json...'
	await writeFile "data/data-#{resource_name}-transformed.json", JSON.stringify
		predicates: base_predicates
		rows: transformed_data
		# todo: could save space by omitting the labels for those objects that
		# are now gone
		labels: labels