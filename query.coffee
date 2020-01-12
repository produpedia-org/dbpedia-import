import { gray, red, magenta } from "https://deno.land/std/fmt/colors.ts"
import { input as readLine } from "https://raw.githubusercontent.com/phil294/read_lines/v3.0.1/input.ts"

prefixes = """
PREFIX dbo: <http://dbpedia.org/ontology/>
PREFIX dbr: <http://dbpedia.org/resource/>
PREFIX dbp: <http://dbpedia.org/property/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
"""

export default (query) =>
	console.debug gray 'querying...'
	format = encodeURIComponent "application/sparql-results+json"
	# format = encodeURIComponent "text/csv"
	timeout = 10000
	default_graph_uri = encodeURIComponent "http://dbpedia.org"
	query = encodeURIComponent "#{prefixes}\n#{query}"
	
	resp = await fetch "https://dbpedia.org/sparql?default-graph-uri=#{default_graph_uri}&format=#{format}&CXML_redir_for_subjs=121&CXML_redir_for_hrefs=&timeout=#{timeout}&debug=on&run=+Run+Query+",
		method: 'POST'
		body: "query=#{query}"
		headers:
			'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8'

	json = try await resp.json()
	if not json
		console.error red await resp.text()
		throw new Error 'is not json'
	results = json.results.bindings.map (row) =>
		subject: row.subject?.value + if row.subject?['xml:lang'] then "@#{row.subject?['xml:lang']}" else ''
		predicate: row.predicate?.value + if row.predicate?['xml:lang'] then "@#{row.predicate?['xml:lang']}" else ''
		object: row.object?.value + if row.object?['xml:lang'] then "@#{row.object?['xml:lang']}" else ''
	console.debug gray "#{results.length} results returned"
	
	if resp.headers.has 'X-SPARQL-MaxRows'
		console.warn magenta "X-SPARQL-MaxRows is set: Return size exceeded return size. This output is truncated."
		await readLine 'continue...'
	
	results