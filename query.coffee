import { gray, red } from "https://deno.land/std/fmt/colors.ts"

prefixes = """
PREFIX dbo: <http://dbpedia.org/ontology/>
PREFIX dbr: <http://dbpedia.org/resource/>
PREFIX dbp: <http://dbpedia.org/property/>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
"""

export default (query) =>
	console.debug gray 'querying...'
	query = encodeURIComponent "#{prefixes}\n#{query}"
	format = encodeURIComponent "application/sparql-results+json"
	# format = encodeURIComponent "text/csv"
	timeout = 10000
	default_graph_uri = encodeURIComponent "http://dbpedia.org"
	resp = await fetch "https://dbpedia.org/sparql?default-graph-uri=#{default_graph_uri}&query=#{query}&format=#{format}&CXML_redir_for_subjs=121&CXML_redir_for_hrefs=&timeout=#{timeout}&debug=on&run=+Run+Query+"
	json = try await resp.json()
	if not json
		console.error red await resp.text()
		throw new Error 'is not json'
	json.results.bindings.map (row) =>
		subject: row.subject?.value
		predicate: row.predicate?.value
		object: row.object?.value