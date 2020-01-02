# File to be translated with coffee and to be run with deno
# e.g. (after `yarn install coffeescript`): `yarn run coffee -c -b mapping_generator.coffee && deno mapping_generator.js`
# Just like Python, just cooler.
# probably deno will be able to read/compile coffeescript files natively at some point so this will be only
# `deno mapping_generator.coffee` but this doesnt work yet

# todo rm at some point
do =>
    query = encodeURIComponent """
    PREFIX dbo: <http://dbpedia.org/ontology/>
    PREFIX dbr: <http://dbpedia.org/resource/>
    PREFIX dbp: <http://dbpedia.org/property/>
    PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
    
    select * where {
        # ?s ?p 
        ?s dbp:type dbr:Smartphone
    } LIMIT 3
    """
    format = encodeURIComponent "application/sparql-results+json"
    format = encodeURIComponent "text/csv"
    timeout = 10000
    default_graph_uri = encodeURIComponent "http://dbpedia.org"
    resp = await fetch "https://dbpedia.org/sparql?default-graph-uri=#{default_graph_uri}&query=#{query}&format=#{format}&CXML_redir_for_subjs=121&CXML_redir_for_hrefs=&timeout=#{timeout}&debug=on&run=+Run+Query+"
    json = try await resp.json()
    if not json
        console.error await resp.text()
        return

    console.log json.results.bindings