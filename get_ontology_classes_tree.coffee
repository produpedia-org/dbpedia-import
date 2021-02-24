import './global.js'
import { writeJson } from "https://deno.land/std/fs/mod.ts"
import query, { sparql_uri_escape } from './query.js'

do =>
	get_children_classes = (parent) =>
		# TODO: querying labels here is missing I think or where did they come from?
		children = await query """select distinct ?s {
			?s rdfs:subClassOf #{parent.name} }"""
		parent.name = parent.name.replace /.{3}:(.+)/, '$1'

		# not 100% the same as in get_products but as a rough clue
		count_result = await query """
			select count(*) as ?count {
				select distinct ?subject where {
					{ ?subject gold:hypernym dbr:#{parent.name} } UNION 
					{ ?subject dbp:type dbr:#{parent.name} } UNION
					{ ?subject dbo:type dbr:#{parent.name} } UNION
					{ ?subject dbp:type "#{parent.name}"^^rdf:langString } UNION
					{ ?subject rdf:type dbr:#{parent.name} } UNION
					{ ?subject rdf:type dbo:#{parent.name} } .
					{ ?subject rdfs:label ?currentExistingWikiArticle } .
					FILTER ( NOT EXISTS { ?subject dbo:wikiPageRedirects ?redirect } )
				}
			}"""
		parent.count = count_result[0].count * 1

		parent.children = []
		for { s } from children
			child = name: s
			parent.children.push child
			await get_children_classes child
	
	root = name: 'owl:Thing'
	await get_children_classes root
	
	# await writeFile 'ontology_classes_tree.json', JSON.stringify root
	await writeJson 'categories_.json', root, spaces: 4