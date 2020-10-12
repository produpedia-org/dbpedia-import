import './global.js'
import { readJson, writeJson } from "https://deno.land/std/fs/mod.ts"
import query, { sparql_uri_escape } from './query.js'

do =>
	category_tree = await readJson 'categories_4.json'

	set_category_parents = (category) =>
		for child from category.children or []
			child.parent = category
			set_category_parents child
	set_category_parents category_tree

	### is target an arbitrarily deep nested child of maybe_parent? ###
	is_parent_category_of = (maybe_parent, target) =>
		while target.parent != maybe_parent and target.parent
			target = target.parent
		target.parent == maybe_parent

	products = {}

	i = 0

	read_category = (category) =>
		i++
		# if i > 3 # for testing purposes only. TODO
		# 	return
		if i == 15
			i = 0
			console.log Object.keys(products).length

		for child from category.children or []
			await read_category child

		console.log category.name

		if category.wrapper
			return
		
		category_sanitized = sparql_uri_escape category.name

		if category.ontology_only
			conditions = "?subject rdf:type dbo:#{category_sanitized}"
		else
			# todo products should have different trust value in this case (but *values* unaltered)
			conditions = """{ ?subject gold:hypernym dbr:#{category_sanitized} } UNION 
				{ ?subject dbp:type dbr:#{category_sanitized} } UNION
				{ ?subject dbo:type dbr:#{category_sanitized} } UNION
				{ ?subject dbp:type "#{category.name}"^^rdf:langString } UNION
				{ ?subject rdf:type dbr:#{category_sanitized} } UNION
				{ ?subject rdf:type dbo:#{category_sanitized} } .
				{ ?subject rdfs:label ?currentExistingWikiArticle }"""
		sql = """select distinct ?subject ?redirect ?thumbnail ?depiction (GROUP_CONCAT(?alias;SEPARATOR=":::::") as ?aliases) where {
			{ #{conditions} } .
			OPTIONAL { ?subject dbo:wikiPageRedirects ?redirect } .
			OPTIONAL {
				?wikidataSameAs owl:sameAs ?subject .
				OPTIONAL { ?wikidataSameAs dbo:thumbnail ?thumbnail } .
				OPTIONAL { ?wikidataSameAs foaf:depiction ?depiction } .
			} .
			OPTIONAL { ?alias dbo:wikiPageRedirects ?subject } .
		}"""
		result = await query sql
		
		for row from result
			product_name = row.redirect or row.subject
			product_name = product_name.replace /^dbr:/, ''
			product = products[product_name]
			if product
				is_new_nonparent_category = not product.categories.some (existing_category) =>
					category == existing_category or is_parent_category_of(category, existing_category)
				if is_new_nonparent_category
					product.categories.push category
			else
				product = products[product_name] = categories: [ category ]
			aliases = []
			if row.redirect
				aliases.push row.subject
			else
				# TODO: Since pics are only set when the product is returned on its own,
				# they will missing when it got here by redirect *and* it isnt part
				# of any category on its own. Example: dbr:7th_Legion is in category dbo:Game and
				# redirects to dbr:Seventh_Legion, which in turn is *not* in any category. In this case,
				# there will be no thumbnail/depiction queried.
				# This constellation is about 1.2% of all data, so not super important. 
				product.thumbnail = row.thumbnail
				product.depiction = row.depiction
			if row.aliases
				aliases.push ...row.aliases.split(':::::')
			if aliases.length
				if not product.aliases
					product.aliases = []
				for alias from aliases
					alias = decodeURIComponent(alias.replace(/^dbr:/, '').replaceAll('_', ' '))
					if not product.aliases.includes alias
						product.aliases.push alias
		
	await read_category category_tree

	# not doing this because of heap overflow
	# entries = Object.entries products

	encoder = new TextEncoder
	file = await Deno.open 'products.txt', { write: true, create: true, truncate: true }

	console.log "writing to file..."
	# entries_percentage = Math.round(entries.length / 100)
	i = 0
	for product_name, info of products
		info.categories = info.categories.map (c) => c.name
		row = [ product_name, info ]
		data = encoder.encode "#{JSON.stringify(row)}\n"
		await Deno.writeAll file, data
		i++
		if i % 10000 == 0
			console.log Math.round(i / 4100000 * 100) + "%"

	Deno.close file.rid
