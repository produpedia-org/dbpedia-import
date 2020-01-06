# File to be translated with coffee and to be run with deno
# e.g. (after `yarn install coffeescript`): `yarn run coffee -c -b *.coffee && deno mapping_generator.js`
# Just like Python, just cooler.
# probably deno will be able to read/compile coffeescript files natively at some point so this will be only
# `deno mapping_generator.coffee` but this doesnt work yet

import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
# import { input } from 'https://raw.githubusercontent.com/johnsonjo4531/read_lines/v2.1.0/input.ts'
import { input as read_line } from "https://raw.githubusercontent.com/phil294/read_lines/v3.0.1/input.ts"
# import read_file from "https://raw.githubusercontent.com/muhibbudins/deno-readfile/master/index.ts"
import read_file from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
write_file = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query from './query.js'

###
TODOs
- omit mappingbased? (/ontology/* for all s p o), as this parses everything anyway. would there be any values lost by doing so?
	  or other way round, subtraction so all in best possible quality but no dups?
	  or maybe work with mappings only
- when querying: label etc @lang?
- find and add predicates that always apply to relevant_predicates
- dbp:imagesize??
- range vs array vs single value
- add all defining_identifiers to relevant_predicates, e.g. <form>

strategy:
- mapping generator on 2016
- mapping generator on latest: dbpedia live or better, latest databus dumps
      merge properly
- get data as table
- mapping transformer: automizable stuff, e.g. same-as-ize predicates
- commit data on new branch
- manual transformations
- commit/merge data onto dbpedia branch
- merge dbpedia into master
###

open_objects = new Set [ "http://dbpedia.org/resource/Smartphone" ]
open_subjects = new Set
open_identifiers = []

# d, r, i
defining_identifiers = [] # identifier == predicate-object combo
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
	console.log "### Statement: ?subject <#{yellow predicate}> <#{yellow object}> ###"
	if subjects
		console.log gray "?subject is i.a. ..." +
			green "#{subjects[0..5]}, #{subjects.length} in total"
	console.log italic "This statement is: [d]efinite, [nothing] predicate is irrelevant, predicate is [r]elevant, [i] predicate is irrelevant but investigate, [ii] only statement irrelevant but investigate, [s] only statement is irrelevant. ? "
	choice = await read_line '> '
	switch choice
		when 'd'
			# defining_identifiers["#{predicate} #{object}"]
			# defining_identifiers[predicate] = object
			defining_identifiers.push { predicate, object }
			checked_identifiers.push "#{predicate} #{object}"
			# open_identifiers[predicate] = object # is already in open_subjects
			if subjects
				for subject from subjects
					if not checked_subjects.includes subject
						open_subjects.add subject
						# checked_subjects.push subject
		when 'r'
			relevant_predicates.push predicate
			checked_predicates.push predicate
		when 'i'
			irrelevant_predicates.push predicate
			# [i]nvestigate this statement==identifier, meaning
			# have a look at the possible respective subjects
			open_identifiers.push { predicate, object }
			checked_predicates.push predicate
		when 'ii'
			open_identifiers.push { predicate, object }
			# note: there is no irrelevant_identifiers. any remaining identifier that
			# is not defining is automatically irrelevant.
			checked_identifiers.push "#{predicate} #{object}"
		when 's'
			# same
			checked_identifiers.push "#{predicate} #{object}"
		else
			irrelevant_predicates.push predicate
			checked_predicates.push predicate

investigate_identifier = (predicate, object) =>
	console.debug gray "investigate identifier: ?subject <#{predicate}> <#{object}>"
	results = await query """
	select * where {
		?subject <#{predicate}> <#{object}>
	}
	# limit 2"""
	# console.dir results
	for { subject } from results
		console.log "### <#{yellow subject}> ###"
		console.log italic "Find more out about it (multiple choices possible): its [p]roperties, as [o]bject, [nothing] irrelevant? "
		choice = await read_line '> '
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
	console.debug gray "investigate subject: <#{subject}> ?predicate ?object"
	results = await query """
	select * where {
		<#{subject}> ?predicate ?object
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
			console.log "### Statement: ?subject <#{yellow predicate}> ?object ###"
			console.log gray "Sample objects: " +
				green "#{results[0..5].map 'object'}, #{results.length} in total"
			console.log italic "This predicate is: [r]elevant, [t]raverse investigate: ask again seperately for all #{results.length} identifiers, [nothing] irrelevant? "
			choice = await read_line '> '
			switch choice
				when 't'
					for result from results
						await ask_for_identifier null, predicate, result.object
				when 'r'
					relevant_predicates.push predicate
					checked_predicates.push predicate
				else
					irrelevant_predicates.push predicate
					checked_predicates.push predicate
	checked_subjects.push subject

investigate_object = (object) =>
	console.debug gray "investigate object: ?subject ?predicate <#{object}>"
	results = await query """
	select * where {
		?subject ?predicate <#{object}>
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
		defining_identifiers, relevant_predicates, irrelevant_predicates
		# dev
		checked: { checked_identifiers, checked_objects, checked_predicates, checked_subjects }
		open:
			open_identifiers: open_identifiers
			open_objects: [...open_objects]
			open_subects: [...open_subjects]
	}
	outfile = "tmp/mapping_#{Date.now()}.json"
	await write_file outfile, JSON.stringify end_result

do =>
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
