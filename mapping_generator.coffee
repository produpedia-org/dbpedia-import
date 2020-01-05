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
when querying: label etc @lang?
###

open_objects = new Set [ "http://dbpedia.org/resource/Smartphone" ]
open_subjects = new Set
open_identifiers = {}

# d, r, i
definite_identifiers = {} # identifier == predicate-object combo
relevant_predicates = []
irrelevant_predicates = []

# tmp note while still dev: check for the checked_Es before adding E to d, r, or i, *not* before investigate_E
# because checked means 'no need to ask the user again', not 'i queried everything for it'. for the latter,
# open_E is in place
checked_subjects = []
checked_predicates = []
checked_objects = []
checked_identifiers = []

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
		console.log italic "Find more out about it (multiple choices possible): its [p]roperties, as [o]bject, [nothing] not relevant? "
		choice = await read_line ''
		if choice.includes 'p'
			open_subjects.add subject
		else
			checked_subjects.push subject
		if choice.includes 'o'
			open_objects.add subject
		else
			checked_objects.push subject
	checked_identifiers.push predicate + " " + object

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
		.reduce (all, result) =>
			all[result.predicate] = [ ...(all[result.predicate] or []), result ]
			all
		, {}
	for predicate, results of predicate_infos
		ask_for_identifier = (object) =>
			console.debug gray dim "(ask_for_identifier)"
			console.log "### Statement: ?subject <#{yellow predicate}> <#{yellow object}> ###"
			console.log italic "This statement is: [d]efinite, [r]elevant, [i]rrelevant but [i]nvestigate, [nothing] not relevant? "
			choice = await read_line ''
			switch choice
				when 'd'
					definite_identifiers[predicate] = results[0].object
				when 'r'
					relevant_predicates.push predicate
				when 'i'
					irrelevant_predicates.push predicate
					open_identifiers[predicate] = object
				else
					irrelevant_predicates.push predicate
		choice = ''
		if results.length == 1
			await ask_for_identifier results[0].object
		else
			console.log "### Statement: ?subject <#{yellow predicate}> ?object ###"
			console.log gray "Sample objects: " +
				green "#{results[0..5].map 'object'}, #{results.length} in total"
			console.log italic "This predicate is: [i] investigate: ask again seperately for all #{results.length} identifiers, [nothing] not relevant? "
			choice = await read_line ''
			switch choice
				when 'i'
					for result from results
						await ask_for_identifier result.object
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
		.reduce (all, result) =>
			all[result.predicate] = [ ...(all[result.predicate] or []),  result ]
			all
		, {}
	for predicate, results of predicate_infos
		console.log "### Statement: ?subject <#{yellow predicate}> <#{yellow object}> ###"
		console.log gray "Used i.a. by..."
		console.log green "#{results[0..5].map 'subject'}, #{results.length} in total"
		console.log italic "This statement is: [d]efinite, [r]elevant, [i]rrelevant but [i]nvestigate, [nothing] not relevant? "
		choice = await read_line ''
		switch choice
			when 'd'
				# definite_identifiers["#{predicate} #{object}"]
				definite_identifiers[predicate] = object
				# open_identifiers[predicate] = object # is already in open_subjects
				for result from results
					if not checked_subjects.includes result.subject
						open_subjects.add result.subject
						# checked_subjects.push result.subject
			when 'r'
				relevant_predicates.push predicate
			when 'i'
				irrelevant_predicates.push predicate
				open_identifiers[predicate] = object
			else
				irrelevant_predicates.push predicate
		checked_predicates.push predicate
	checked_objects.push object
				
do =>
	investigate = true
	while investigate
		console.debug gray 'investigate: next iteration'
		investigate = false
		for object from open_objects
			investigate = true
			open_objects.delete object
			if not checked_objects.includes object
				await investigate_object object
			else
				console.warn magenta "omitting already checked object #{object}"
		for predicate, object of open_identifiers
			investigate = true
			delete open_identifiers[predicate]
			if not checked_identifiers.includes(predicate + " " + object)
				await investigate_identifier predicate, object
		for subject from open_subjects
			investigate = true
			open_subjects.delete subject
			if not checked_subjects.includes subject
				await investigate_subject subject
			else
				console.warn magenta "omitting already checked object #{object}"
	console.log 'finished. writing to file...'
	end_result = { definite_identifiers, relevant_predicates, irrelevant_predicates }
	# outfile = "mapping_#{Date.now()}.json"
	outfile = 'mapping.json'
	await write_file outfile, JSON.stringify end_result
