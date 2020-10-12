# File to be translated with coffee and to be run with deno
# e.g. (after `yarn install coffeescript`): `yarn run coffee -c -b *.coffee && deno mapping_generator.js`
# Just like Python, just cooler.
# probably deno will be able to read/compile coffeescript files natively at some point so this will be only
# `deno mapping_generator.coffee` but this doesnt work yet

import { readLine } from './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"

import readFile from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query from './query.js'

###
Some small TODOs and notes to self while this whole thing is still in development.
- skip option e.g. while iterating over subject props when subject not valid
- undefining_identifiers, undefining_predicates

strategy:
revised:
data-X-transformed-manually						- present: [data (just in case)], final output
mapping_generator > data-X						- mapping generator on latest databus collection
													defining_identifiers OR single categories enough?
json_to_csv										- temporary, while writing transforms: get data as table via
find_irrelevant_subjects						- debugging
structure-transformer > data-X-transformed		- mapping transformer: automizable stuff, e.g. same-as-ize predicates; autom value transforms
manual-transformer > data-X-transformed-manually- manual transformations based on last data diff: if any row value changes/deletes/adds, prompt. simple as that
diff_datas > data-X-diff						- diff to last output
												- check/edit diff
												- apply diff to db
###

class RelevantPredicate
	# TODO: Automatically extract and save name, description, unit etc. from dbo: predicates
	constructor: (@predicate, @mapTo = null, @export = false, @unit = "", @structured = false) ->

open_subjects = new Set
open_objects = new Set
open_identifiers = []

# d, r, i
defining_identifiers = [] # identifier == predicate-object combo
irrelevant_identifiers = []
relevant_predicates = []
irrelevant_predicates = []

# tmp note while still dev: check for the checked_Es before adding E to d, r, or i, *not* before investigate_E
# because checked means 'no need to ask the user again', not 'i queried everything for it'. for the latter,
# open_E is in place
checked_subjects = []
checked_predicates = []
checked_objects = []
checked_identifiers = []

ask_for_identifier = (subjects, predicate, object) =>
	console.log "### Statement: ?subject #{yellow predicate} #{yellow object} ###"
	if subjects
		console.log gray "?subject is i.a. ..." +
			green "#{subjects[0..5]}, #{subjects.length} in total"
	console.log italic "This statement is: [d]efining, [nothing] predicate is irrelevant, predicate is [r]elevant, [i] predicate is irrelevant but investigate, [ii] only statement irrelevant but investigate, [s] only statement is irrelevant. ? "
	defining = defining_identifiers.find (i) => i.predicate == predicate and i.object == object
	relevant = relevant_predicates.map('predicate').includes predicate
	irrelevant_identifier = irrelevant_identifiers.find (i) => i.predicate == predicate and i.object == object
	irrelevant = irrelevant_predicates.includes predicate
	if defining or relevant or irrelevant_identifier or irrelevant
		console.log dim "Already saved as #{if defining then "defining predicate"}, #{if relevant then "relevant predicate"}, #{if irrelevant_identifier then "irrelevant statement"}, #{if irrelevant then "irrelevant predicate"}."
	choice = await readLine '> '
	switch choice
		when 'd'
			# defining_identifiers["#{predicate} #{object}"]
			# defining_identifiers[predicate] = object
			defining_identifiers.push { predicate, object }
			relevant_predicates.push new RelevantPredicate predicate
			checked_identifiers.push "#{predicate} #{object}"
			# open_identifiers[predicate] = object # is already in open_subjects
			if not subjects
				console.log 'QUERYING SUBJECTS FOR NEW DEFINING IDENTIFIER, ALL TO BE ADDED TO OPEN_SUBJECTS'
				results = await query """
				select ?subject where {
					?subject #{predicate} #{object}
				}"""
				subjects = results.map 'subject'
			for subject from subjects
				if not checked_subjects.includes subject
					open_subjects.add subject
		when 'r'
			relevant_predicates.push new RelevantPredicate predicate
			checked_predicates.push predicate
		when 'i'
			irrelevant_predicates.push predicate
			# [i]nvestigate this statement==identifier, meaning
			# have a look at the possible respective subjects
			open_identifiers.push { predicate, object }
			checked_predicates.push predicate
		when 'ii'
			irrelevant_identifiers.push { predicate, object }
			open_identifiers.push { predicate, object }
			checked_identifiers.push "#{predicate} #{object}"
		when 's'
			irrelevant_identifiers.push { predicate, object }
			checked_identifiers.push "#{predicate} #{object}"
		else
			irrelevant_predicates.push predicate
			checked_predicates.push predicate

investigate_identifier = (predicate, object) =>
	console.debug gray "investigate identifier: ?subject #{predicate} #{object}"
	results = await query """
	select ?subject where {
		?subject #{predicate} #{object}
	}
	# limit 2"""
	# console.dir results
	for { subject } from results
		console.log "### #{yellow subject} ###"
		console.log italic "Find more out about it (multiple choices possible): its [p]roperties, as [o]bject, [nothing] irrelevant? "
		choice = await readLine '> '
		if choice.includes 'p'
			open_subjects.add subject
		else
			checked_subjects.push subject
		if choice.includes 'o'
			open_objects.add subject
		else
			checked_objects.push subject
	checked_identifiers.push "#{predicate} #{object}"

investigate_subject = (subject) =>
	console.debug gray "investigate subject: #{subject} ?predicate ?object"
	results = await query """
	select * where {
		#{subject} ?predicate ?object
	}
	# limit 2"""
	# console.dir results
	predicate_infos = results
		.filter (result) => not checked_predicates.includes result.predicate
		.filter (result) => not checked_identifiers.includes "#{result.predicate} #{result.object}"
		.reduce (all, result) =>
			all[result.predicate] = [ ...(all[result.predicate] or []), result ]
			all
		, {}
	for predicate, results of predicate_infos
		choice = ''
		if results.length == 1
			await ask_for_identifier null, predicate, results[0].object
		else
			console.log "### Statement: ?subject #{yellow predicate} ?object ###"
			console.log gray "Sample objects: " +
				green "#{results[0..5].map 'object'}, #{results.length} in total"
			console.log italic "This predicate is: [r]elevant, [t]raverse investigate: ask again seperately for all #{results.length} identifiers, [nothing] irrelevant? "
			if relevant_predicates.map('predicate').includes predicate
				console.log dim "Already saved as relevant predicate"
			choice = await readLine '> '
			switch choice
				when 't'
					for result from results
						await ask_for_identifier null, predicate, result.object
				when 'r'
					relevant_predicates.push new RelevantPredicate predicate
					checked_predicates.push predicate
				else
					irrelevant_predicates.push predicate
					checked_predicates.push predicate
	checked_subjects.push subject

investigate_object = (object) =>
	console.debug gray "investigate object: ?subject ?predicate #{object}"
	results = await query """
	select * where {
		?subject ?predicate #{object}
	}
	# limit 2"""
	# console.dir results
	predicate_infos = results
		.filter (result) => not checked_predicates.includes result.predicate
		.filter (result) => not checked_identifiers.includes "#{result.predicate} #{object}"
		.reduce (all, result) =>
			all[result.predicate] = [ ...(all[result.predicate] or []),  result ]
			all
		, {}
	for predicate, results of predicate_infos
		subjects = results.map 'subject'
		await ask_for_identifier subjects, predicate, object
	checked_objects.push object

write_out = =>
	console.debug gray dim 'write out to file...'
	end_result = {
		irrelevant_identifiers, defining_identifiers, relevant_predicates, irrelevant_predicates
		# not actually needed, only here while for testing purposes while developing this script
		checked: { checked_identifiers, checked_objects, checked_predicates, checked_subjects }
		open:
			open_identifiers: open_identifiers
			open_objects: [...open_objects]
			open_subects: [...open_subjects]
	}
	outfile = "tmp/mapping_#{Date.now()}.json"
	await writeFile outfile, JSON.stringify end_result

do =>

	start_resource = Deno.args[1]
	if not start_resource
		console.error 'Please pass the case-sensitive starting object resource as argument, e.g. "Smartphone" for dbr:Smartphone'
		Deno.exit(1)

	try existing_mapping = JSON.parse await readFile "mappings/mapping-dbr:#{start_resource}.json"

	### minimalistic approach ###
	##
	if existing_mapping
		{ defining_identifiers, relevant_predicates, irrelevant_predicates, irrelevant_identifiers } = existing_mapping
		# for each defining identifier, get all subjects and recheck them,
		# in case new attributes were added. this is somewhat the automation of
		# bulk investigate_identifier
		
		# v1: all at once
		####
		query_conditions = defining_identifiers
			.map (identifier) =>
				"{ ?subject #{identifier.predicate} #{
					if identifier.object.match /^http:\/\/dbpedia\.org/
						"#{identifier.object}"
					# TODO:
					else "\"#{identifier.object}\"^^rdf:langString"
				} }"
			.join "\nUNION\n"
		results = await query "select distinct ?subject where { #{query_conditions} }"
		open_subjects = new Set results.map 'subject'
		####

		# v2: one after another
		###
		open_subjects = new Set
		console.debug dim "Finding all subjects for existing defining_identifiers..."
		for identifier from defining_identifiers
			query_condition = "?subject #{identifier.predicate} #{
					if identifier.object.match /^http:\/\/dbpedia\.org/
						"#{identifier.object}"
					# TODO:
					else "\"#{identifier.object}\"^^rdf:langString"
			}"
			results = await query "select ?subject where { #{query_condition} }"
			subjects = results.map 'subject'
			for subject from subjects
				open_subjects.add subject
		###

		console.debug dim "Found #{open_subjects.size} subjects matching existing defining_identifiers that will now be queried"
		checked_subjects = [] 
		#
		checked_predicates = [ ...relevant_predicates.map('predicate'), ...irrelevant_predicates ]
		# checked_objects =
		checked_identifiers = [ ...defining_identifiers, ...irrelevant_identifiers ]
			.map (identifier) => "#{identifier.predicate} #{identifier.object}"
		open_identifiers = []
		open_objects = new Set
	else
		open_objects = new Set [ "http://dbpedia.org/resource/#{start_resource}" ]
	##
	### full approach ###
	###
	# in this case, values from existing mapping will simply be shown again in prompts
	if existing_mapping
		{ defining_identifiers, relevant_predicates, irrelevant_predicates, irrelevant_identifiers } = existing_mapping
	open_objects = new Set [ "http://dbpedia.org/resource/#{start_resource}" ]
	###

	investigate = true
	while investigate
		await write_out()
		console.debug gray 'investigate: next iteration'
		investigate = false
		for object from open_objects
			investigate = true
			open_objects.delete object
			if not checked_objects.includes object
				await investigate_object object
			else
				console.warn magenta "omitting already checked object #{object}"
		for identifier of open_identifiers
			investigate = true
			{ predicate, object } = identifier
			delete open_identifiers[identifier]
			if not checked_identifiers.includes("#{predicate} #{object}")
				await investigate_identifier predicate, object
		for subject from open_subjects
			investigate = true
			open_subjects.delete subject
			if not checked_subjects.includes subject
				await investigate_subject subject
			else
				console.warn magenta "omitting already checked object #{object}"
	console.log 'finished'
	await write_out()
