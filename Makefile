# MIGRATION NOTE (TODO):
# I did not know much about Makefiles when I created this system,
# so there are a bunch of interlinked scripts in ./bin that really
# belong in here. Moving them will be part of tech debt.

# Build and test commands

SHELL                      = /bin/bash
VERSION                    = 0.4.4
IMAGE_NAME                 = docker-cloud-compute
export REMOTE_REPO        ?= dionjwa/docker-cloud-compute
COMPOSE_TOOLS              = docker-compose -f docker-compose.tools.yml run

# Build the docker image
.PHONY: image
image:
	docker build -t ${IMAGE_NAME}:${VERSION} .

.PHONY: clean
clean:
	TEST=false TEST_SCALING=false docker-compose rm -fv
	rm -rf .haxelib
	rm -rf tmp
	rm -rf build
	rm -rf node_modules
	rm -rf node_modules_docker

# Functional tests
.PHONY: test
test: image test-post-image

.PHONY: test-post-image
test-post-image:
	./bin/compile
	TRAVIS=1 VERSION=$GIT_TAG docker-compose -f docker-compose.travis.yml run --rm ccc.tests

.PHONY: push
push: image push-post-image

.PHONY: push-post-image
push-post-image:
	docker tag ${IMAGE_NAME}:${VERSION} ${REMOTE_REPO}:${VERSION}
	docker push ${REMOTE_REPO}:${VERSION}

# Tag and push tags (triggers a build, push, that then tells circleci to deploy)
.PHONY: tag
tag:
	git tag "v${VERSION}"
	# Update dependent files:
	sed -i '' "s/default = .*/default = \"${VERSION}\"/g" etc/terraform/version.tf
	sed -i '' "s/docker-cloud-compute:.*/docker-cloud-compute:${VERSION}\"/g" etc/docker-compose/single-server/docker-compose.yml
	sed -i '' "s/\"version\": .*/\"version\": \"${VERSION}\",/" package.json
	git add etc/terraform/version.tf etc/docker-compose/single-server/docker-compose.yml Makefile package.json
	git commit -m "Version update > ${VERSION}"
	git push
	git tag --delete "v${VERSION}"
	git tag -f "v${VERSION}"
	git push --tags

.PHONY: npm
npm:
	${COMPOSE_TOOLS} node_modules

.PHONY: init
init: npm
	${COMPOSE_TOOLS} haxelibs
	cd clients/metaframe && npm i && cd ../../
	./bin/compile

# Develop with tests running on code changes
.PHONY: develop
develop:
	./bin/compile
	TEST=true TEST_SCALING=false docker-compose up

