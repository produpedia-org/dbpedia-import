import './global.js'
import { readJson, writeJson } from "https://deno.land/std/fs/mod.ts"
import query, { sparql_uri_escape } from './query.js'

do =>
	category_tree = await readJson 'categories_3.json'

	check_category = (cat) =>
		if not cat.wrapper
			cat_sanitized = sparql_uri_escape cat.name

			sql = """select count(?subject) as ?count where {
				?subject rdf:type dbo:#{cat_sanitized} }"""
			result = await query sql
			if result[0].count > 10
				cat.ontology_only = true

			sql = """select ?label where {
				dbo:#{cat_sanitized} rdfs:label ?label
				FILTER(LANGMATCHES(LANG(?label), "en"))
			}"""
			result = await query sql
			cat.label = result[0]?.label

		for child from cat.children or []
			await check_category child

	await check_category category_tree

	await writeJson 'categories_4.json', category_tree, spaces: 4