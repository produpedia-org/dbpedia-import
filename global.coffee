# in case you wonder: the answer is yes.

Object.defineProperty Array.prototype, 'delete',
	enumerable: false
	value: (val) ->
		@splice @indexOf(val), 1
Object.defineProperty Array.prototype, 'move',
	enumerable: false
	value: (i_from, i_to) ->
		@splice i_to, 0, @splice(i_from, 1)[0]
arrayMapOriginal = Array.prototype.map
Object.defineProperty Array.prototype, 'map',
	enumerable: false
	value: (key) ->
		if typeof key == 'string'
			return arrayMapOriginal.call this, (e) => e[key]
		arrayMapOriginal.call @, key
Object.defineProperty Array.prototype, 'uniq',
	enumerable: false
	value: ->
		[...new Set @]

window.sleep = (ms) =>
	new Promise (ok) => setTimeout ok, ms