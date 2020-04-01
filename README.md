Expect proper documentation and a clear import workflow some time later this year. Until then, everything here is subject to utter change

These `.coffee` files are Coffeescript files to be run with Deno. The only way to do this right now is something along the lines of... (taken from the head of `mapping_generator.coffee`)
```
e.g. (after `yarn install coffeescript`): `yarn run coffee -c -b *.coffee && deno mapping_generator.js`
Just like Python, just cooler.
probably deno will be able to read/compile coffeescript files natively at some point so this will be only
`deno mapping_generator.coffee` but this doesnt work yet
```
