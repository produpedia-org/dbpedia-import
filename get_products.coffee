import './global.js'
import query, { sparql_uri_escape } from './query.js'

do =>
	categories = JSON.parse(await Deno.readTextFile("categories_dump.json"))

	get_anchestors = (category) =>
		anchestors = []
		for parent from category.parents
			anchestors.push parent
			parent_ref = categories.find (c) => c.name == parent
			if parent_ref
				anchestors.push ...get_anchestors(parent_ref)
		anchestors
	for category from categories
		category.anchestors = get_anchestors category

	products = {}

	i = 0

	for category from categories
		i++
		# if i > 3
		# 	break
		if i == 15
			i = 0
			console.log Object.keys(products).length

		console.log category.name

		if category.wrapper
			# This also means that products from wrapper categories wont have these saved
			continue

		name_to_resource = (name) =>
			sparql_uri_escape(name[0].toUpperCase() + name.slice(1))
		
		name_to_non_ontology_conditions = (name) =>
			category_sanitized = name_to_resource(name)
			"""
				{ ?subject gold:hypernym dbr:#{category_sanitized} } UNION
				{ ?subject dbp:type dbr:#{category_sanitized} } UNION
				{ ?subject dbo:type dbr:#{category_sanitized} } UNION
				{ ?subject dbp:type "#{name}"^^rdf:langString } UNION
				{ ?subject rdf:type dbr:#{category_sanitized} } UNION
				{ ?subject rdf:type dbo:#{category_sanitized} }"""

		if category.ontology_only
			conditions = "{ ?subject rdf:type dbo:#{name_to_resource category.name} }"
		else
			# todo products should have different trust value in this case (but *values* unaltered)
			conditions = name_to_non_ontology_conditions category.name
		if category.alternative_names
			conditions += " UNION " + category.alternative_names
				.map (alter) => name_to_non_ontology_conditions alter
				.join " UNION "
		sql = """select distinct ?subject ?redirect ?thumbnail ?depiction (GROUP_CONCAT(?alias;SEPARATOR=":::::") as ?aliases) where {
			{ #{conditions} } .
			{ ?subject rdfs:label ?currentExistingWikiArticle } .
			OPTIONAL { ?subject dbo:wikiPageRedirects ?redirect } .
			OPTIONAL {
				?wikidataSameAs owl:sameAs ?subject .
				OPTIONAL { ?wikidataSameAs dbo:thumbnail ?thumbnail } .
				OPTIONAL { ?wikidataSameAs foaf:depiction ?depiction } .
			} .
			OPTIONAL { ?alias dbo:wikiPageRedirects ?subject } .
		}"""
		# console.log sql
		result = await query sql
		
		for row from result
			product_name = row.redirect or row.subject
			product_name = product_name.replace /^dbr:/, ''
			product = products[product_name]
			
			if not product
				product = products[product_name] = categories: []
			aliases = []
			if row.redirect
				aliases.push row.subject
				# But do not push the category into product.categories, because
				# by no means does the category of a redirect-subject also fit the
				# redirect-object (ex. dbr:Minas_Morgul dbo:wikiPageRedirects dbr:Nazgûl,
				# Morgul is rdf:type dbo:City, but Nazgul isnt.)
				# But also, ignoring these leads to 0.179% data loss.
			else
				is_new_nonparent_category = not product.categories.some (existing_category) =>
					category == existing_category or existing_category.anchestors.includes(category.name)
				if is_new_nonparent_category
					product.categories.push category
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
		
	# not doing this because of heap overflow
	# entries = Object.entries products

	encoder = new TextEncoder
	file = await Deno.open 'products.txt', { write: true, create: true, truncate: true }

	console.log "writing to file..."
	# entries_percentage = Math.round(entries.length / 100)
	i = 0
	for product_name, info of products
		if not info.categories.length
			continue
		info.categories = info.categories.map (c) => c.name
		row = [ product_name, info ]
		data = encoder.encode "#{JSON.stringify(row)}\n"
		await Deno.writeAll file, data
		i++
		if i % 10000 == 0
			console.log Math.round(i / 4100000 * 100) + "%"

	Deno.close file.rid
