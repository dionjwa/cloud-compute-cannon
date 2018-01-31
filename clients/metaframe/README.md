# Metaframe page for CCC jobs

## Development

	npm run set-build:client-metaframe

	pushd clients/metaframe
	npm i
	npm run libs
	popd

	docker-compose up

Then in the `metapage` repo

	cd docs
	docker-compose up
	http://0.0.0.0:4000/metapage/tools/metaframeview/?url=http://localhost:8080/metaframe/


To get live reloading of css/js assets

docker-compose -f docker-compose.tools.yml run metapage-livereload