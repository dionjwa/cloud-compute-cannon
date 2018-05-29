# First default:
# "develop". It should depend on being able to quickly determine if 'init' has
# already ran.
# Then "init" should be ran.

# Build and test commands

SHELL                      = /bin/bash
VERSION                    = 0.4.4
IMAGE_NAME                 = docker-cloud-compute
export REMOTE_REPO        ?= dionjwa/docker-cloud-compute
COMPOSE_DEV_BASE           = docker-compose -f docker-compose.yml -f docker-compose.override.yml
COMPOSE_TOOLS              = docker-compose -f docker-compose.tools.yml run
export GIT_TAG             = $$(git rev-parse --short=8 HEAD)

HAXE := $(shell command -v haxe 2> /dev/null)

# Develop with tests running on code changes
.PHONY: develop
develop: develop-check
	TEST=true TEST_SCALING=false docker-compose up

# Quick check if "init" has been called
.PHONY: develop-check
develop-check:
	@if [ ! -d ".haxelib" ]; then echo 'Requires "make init"'; exit 1; fi

.PHONY: init
init: npm haxelib compile

# Build the docker image
.PHONY: image
image:
	docker build -t ${IMAGE_NAME}:${VERSION} .

.PHONY: prerequisites
prerequisites:
ifndef HAXE
    $(error "haxe is not available please install haxe")
endif

.PHONY: server
server: prerequisites
	haxe etc/hxml/server-build.hxml

.PHONY: metaframe
metaframe: webpack

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
	TRAVIS=1 VERSION=${VERSION} docker-compose -f docker-compose.travis.yml up --abort-on-container-exit --exit-code-from dcc.tests

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
	npm install

.PHONY: compile
compile: prerequisites webpack
	haxe etc/hxml/build-all.hxml

.PHONY: develop-extra
develop-extra: compile
	TEST=true TEST_SCALING=false docker-compose up

.PHONY: haxelib
haxelib: haxelib-client
	haxelib --always install etc/hxml/build-all.hxml

.PHONY: haxelib-client
haxelib-client: prerequisites
	mkdir -p .haxelib && haxelib --always install build-metaframe.hxml

.PHONY: webpack
webpack: prerequisites
	node_modules/.bin/webpack

.PHONY: set-build-server
set-build-server:
	rm -f build.hxml && ln -s etc/hxml/server-build.hxml build.hxml

.PHONY: set-build-metaframe
set-build-metaframe:
	rm -f build.hxml && ln -s build-metaframe.hxml build.hxml

.PHONY: set-build-test
set-build-test:
	rm -f build.hxml && ln -s test/services/stand-alone-tester/build.hxml build.hxml

.PHONY: set-build-all
set-build-all:
	rm -f build.hxml && ln -s etc/hxml/build-all.hxml build.hxml

.PHONY: webpack-watch
webpack-watch: prerequisites
	node_modules/.bin/webpack-dev-server --watch --content-base clients/

# More obscure develop options
.PHONY: develop-server-workers
develop-server-workers: develop-check compile
	TEST=true ${COMPOSE_DEV_BASE} -f docker-compose.extras-logging.yml  -f docker-compose.extras-workers.yml up
