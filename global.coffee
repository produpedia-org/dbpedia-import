# in case you wonder: the answer is yes.

Object.defineProperty Array.prototype, 'delete',
	enumerable: false
	value: (val) ->
		this.splice(this.indexOf(val), 1)
Object.defineProperty Array.prototype, 'move',
	enumerable: false
	value: (i_from, i_to) ->
		this.splice i_to, 0, this.splice(i_from, 1)[0]
arrayMapOriginal = Array.prototype.map
Object.defineProperty Array.prototype, 'map',
	enumerable: false
	value: (key) ->
		if typeof key == 'string'
			return arrayMapOriginal.call this, (e) => e[key]
		arrayMapOriginal.call this, key

window.sleep = (ms) =>
	new Promise (ok) => setTimeout(ok, ms)