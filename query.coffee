import { gray, red, magenta } from "https://deno.land/std/fmt/colors.ts"
import { input as readLine } from "https://raw.githubusercontent.com/phil294/read_lines/v3.0.1/input.ts"

### also see
http://prefix.cc/popular/all.file.sparql
###
prefixes = [
	{ resource: "http://dbpedia.org/ontology/", shorty: "dbo:" }
	{ resource: "http://dbpedia.org/resource/", shorty: "dbr:" }
	{ resource: "http://dbpedia.org/property/", shorty: "dbp:" }
	{ resource: "http://www.w3.org/2001/XMLSchema#", shorty: "xsd:" }
	{ resource: "http://www.w3.org/2002/07/owl#", shorty: "owl:" }
	{ resource: "http://www.wikidata.org/entity/", shorty: "wikidata:" }
	{ resource: "http://dbpedia.org/class/yago/", shorty: "yago:" }

	{ resource: "http://purl.org/dc/terms/", shorty: "dct:" }
	{ resource: "http://www.w3.org/1999/02/22-rdf-syntax-ns#", shorty: "rdf:" }
	{ resource: "http://www.w3.org/2000/01/rdf-schema#", shorty: "rdfs:" }
	{ resource: "http://purl.org/linguistics/gold/", shorty: "gold:" }
	{ resource: "http://xmlns.com/foaf/0.1/", shorty: "foaf:" }
	{ resource: "http://www.w3.org/2003/01/geo/wgs84_pos#", shorty: "wgs84:" }
	{ resource: "http://www.w3.org/ns/prov#", shorty: "prov:" }
	{ resource: "http://www.georss.org/georss/", shorty: "georss:" }

	{ resource: "http://www.ontologydesignpatterns.org/ont/dul/DUL.owl#", shorty: "dul:" }
	{ resource: "http://schema.org/", shorty: "sdo:" }
	{ resource: "http://umbel.org/umbel/rc/", shorty: "umbelrc:" }

	{ resource: "http://purl.org/linguistics/gold/", shorty: "gold:" }
]

prefix_resource = (entity) =>
	for { resource, shorty } in prefixes
		entity = entity.replace resource, shorty
	entity

sparql_prefixes = prefixes
	.map (prefix) => "PREFIX #{prefix.shorty} <#{prefix.resource}>"
	.join '\n'

export sparql_uri_escape = (uri) =>
	# todo probably not complete
	uri.replace /([,()+'/&.])/g, '\\$1'

export default (query) =>
	console.debug gray 'querying...'
	if query.includes 'http'
		console.warn query
		console.warn magenta "query includes 'http'"
		await readLine 'continue...'

	format = encodeURIComponent "application/sparql-results+json"
	# format = encodeURIComponent "text/csv"
	timeout = 10000
	# default_graph_uri = encodeURIComponent "http://dbpedia.org"
	default_graph_uri = ""
	# base_uri = "https://dbpedia.org"
	base_uri = "http://localhost:8891"
	# query = "select * { ?s ?o ?p . } limit 10"
	query = encodeURIComponent "#{sparql_prefixes}\n#{query}"
	
	url = "#{base_uri}/sparql?default-graph-uri=#{default_graph_uri}&format=#{format}&CXML_redir_for_subjs=121&CXML_redir_for_hrefs=&timeout=#{timeout}&debug=on&run=+Run+Query+"
	resp = await fetch url,
		method: 'POST'
		body: "query=#{query}"
		headers:
			'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'

	json = try await resp.json()
	if not json
		console.error query
		console.error red await resp.text()
		throw new Error "is not json"
	results = json.results.bindings.map (row) =>
		t = {}
		for prop, propvalue of row
			t[prop] = prefix_resource(propvalue.value) + if propvalue['xml:lang'] then "@#{propvalue['xml:lang']}" else ''
			# if t[prop].includes 'http'
			# 	console.warn magenta "#{t[prop]} includes 'http' even after prefixing"
			# 	await readLine 'continue...' # doesnt work in this spot, for some reason
			# 	# Deno.exit()
		t
	console.debug gray "#{results.length} results returned"

	if resp.headers.has 'X-SPARQL-MaxRows'
		console.warn magenta "X-SPARQL-MaxRows is set: Return size exceeded return size. This output is truncated."
		await readLine 'continue...'
	
	results