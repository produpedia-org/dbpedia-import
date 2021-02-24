This repo contains some of the few helper scripts to transform the DBpedia dataset into Produpedia's database (also downloadable from https://produpedia.org/static/download.html).

Generally, this process works but is scattered accross multiple files, even repositories. It could probably be unified all into one script. To reproduce it all, here are the necessary steps:

`*.coffee` files below refer to scripts meant to be run with [deno](https://deno.land). Deno does not yet support transpiling coffeescript, so you need to run `npm run coffee -c -b *.coffee` beforehand and run the resulting `.js` file. (I know)

`product` and `subject` mean the same thing.

1. Spin up a local DBpedia instance
   - See https://www.dbpedia.org/resources/latest-core/ and https://github.com/dbpedia/virtuoso-sparql-endpoint-quickstart
   - Because there is no paging implemented in the scripts and the operations can break computation limits, you should increase the thresholds inside `virtuoso.ini` in your instance, for example the ridiculously high values from [virtuoso.ini.modifications](virtuoso.ini.modifications). But also, please read the documentation about NumberOfBuffers and MaxDirtyBuffers in your generated virtuoso.ini file.
   - The collection in use is https://databus.dbpedia.org/phil294/collections/dbpedia-latest-core-produpedia (mirrored at [databus-collection-mirror.json](databus-collection-mirror.json))
   - You will also need:
      - The missing properties `givenName`, `surname` and `gender` from the 2016 (!) persondata dataset because [they are missing in the latest ones](https://forum.dbpedia.org/t/dbpedia-dataset-2019-08-30-pre-release/219/22). You could probably just add the whole dataset to the collection (or put [it](https://downloads.dbpedia.org/repo/dbpedia/generic/persondata/2016.10.01/persondata_lang=en.ttl.bz2) into the downloads folder manually). When I did it I `grep`ed for those three properties only, for some reason.
      - https://databus.dbpedia.org/dbpedia/wikidata/images because they are missing ([see "Current issues"](https://www.dbpedia.org/resources/latest-core/)) and https://databus.dbpedia.org/dbpedia/wikidata/sameas-all-wikis/ to connect both datasets (used in [get_products.coffee](get_products.coffee). The SameAs all wikis is rather big, you can also extract it and grep for the lines referencing the english wiki only with `grep '<http://dbpedia.org/resource/' > outfile`
      - With the above steps, the resulting `virtuoso-db` folder will be about 14 GB in size.    
1. Get `categories.json`, the json representation of the browsable category tree
   - You can either just take the one from the [data repo](https://github.com/produpedia-org/data/blob/master/categories.json). This is the maintained one. Or, if you want to do it yourself,
   - Create and maintain one yourself, e.g. using
      - [get_ontology_classes_tree.coffee](get_ontology_classes_tree.coffee). This gets all ontology classes listed at http://mappings.dbpedia.org/server/ontology/classes ([archive.org mirror](https://web.archive.org/web/20200802111242/http://mappings.dbpedia.org/server/ontology/classes))
      - Manual edits (compare: [Edits to categories.json over time](https://github.com/produpedia-org/data/commits/master/categories.json))
      - [dbpedia-additional-categories-manually](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-additional-categories-manually.ts): uses `gold:hypernym` to print out further interesting categories. Only a helper script, does not extend `categories.json` for you. Every time before you use it, you should also have run [dbpedia-categories](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-categories.ts) because it populates the DB with the categories from `categories.json`. Both scripts are in the main repo.
1. Import `categories.json` into the main repo DB with [dbpedia-categories](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-categories.ts). It requires you to have the mongodb database set up (documented over there).
1. Generate category aliases with [dbpedia-categories-aliases](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-categories-aliases.ts). The output should probably be integrated into `categories.json` above instead
1. Generate `categories_dump.json` with e.g. `mongoexport -d database_name -c category --jsonArray --pretty > categories_dump.json`. Necessary because the up to date categories state now lies in the DB.
1. Use it to run [get_products.coffee](get_products.coffee) (in this repo again). It produces `products.txt`. Please note that this script consumes a *lot* of RAM because all >4 million products with their categories stay in memory. You will need something along the lines of `deno run --unstable --v8-flags=--max-old-space-size=8192 get_products.js`. Can easily take half an hour or so.
1. Run [dbpedia-attributes](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-attributes.ts). It gets (more or less) [all DBpedia attributes](http://mappings.dbpedia.org/index.php?title=Special%3AAllPages&from=&to=&namespace=202) and saves them to the db.
1. Run [dbpedia-products](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-products.ts). It reads `products.txt`, gets all relevant values in small batches and saves them to the db. Can take many hours.
1. Create the DB indexes listed in the comments at the top of [Product.ts](https://github.com/produpedia-org/produpedia.org/tree/master/api/models/Product.ts), [Attribute.ts](https://github.com/produpedia-org/produpedia.org/tree/master/api/models/Attribute.ts) and [Category.ts](https://github.com/produpedia-org/produpedia.org/tree/master/api/models/Category.ts).
1. Generate `Category.showers` and `Category.products_count` properties with [dbpedia-categories-showers](https://github.com/produpedia-org/produpedia.org/tree/master/api/initializers/dbpedia-categories-showers.ts). This script also eats up a lot of ram.

If you actually do all of that, you might experience some minor errors because I haven't all done it again myself. Just open a issue and we will resolve it quickly.
