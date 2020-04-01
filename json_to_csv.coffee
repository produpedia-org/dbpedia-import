import './global.js'
import { gray, yellow, italic, green, magenta, dim } from "https://deno.land/std/fmt/colors.ts"
import readFile from "https://raw.githubusercontent.com/phil294/deno-readfile/master/index.ts"
writeFile = (file, txt) => Deno.writeFile(file, (new TextEncoder()).encode(txt)) # ^ integrate?
import query from './query.js'

###
Turns a value json into a respective csv.
Only useful for debugging and inspecting values with a proper excel-like tool
###

do =>
	json_file = Deno.args[1]
	if not json_file
		console.error 'Please pass the json file as first cmd line argument'
		Deno.exit 1

	json = JSON.parse await readFile json_file
	columns = json.predicates
	data = json.rows

	csv_escape = (v) =>
		v = v.replace /"/g, '""'
		"\"#{v}\""
	
	csv = columns.map((col) => csv_escape(col)).join(',') + '\n' +
		data
			.map (row) =>
				columns
					.map (col) =>
						v = row[col] or ''
						csv_escape v
					.join ','
			.join '\n'

	console.debug gray dim 'write out to csv...'
	await writeFile "#{json_file}.csv", csv