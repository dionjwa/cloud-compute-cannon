# First default:
# "develop". It should depend on being able to quickly determine if 'init' has
# already ran.
# Then "init" should be ran.

# Build and test commands

SHELL                      := /bin/bash
VERSION                    = 0.4.4
IMAGE_NAME                 = docker-cloud-compute
export REMOTE_REPO        ?= dionjwa/docker-cloud-compute
COMPOSE_DEV_BASE           = docker-compose -f docker-compose.yml -f docker-compose.override.yml
COMPOSE_MINIMAL            = docker-compose -f docker-compose.yml -f docker-compose.minimal.yml
COMPOSE_TOOLS              = docker-compose -f docker-compose.tools.yml run
export GIT_TAG             = $$(git rev-parse --short=8 HEAD)

HAXE := $(shell command -v haxe 2> /dev/null)

# Develop with tests running on code changes
.PHONY: develop
develop: develop-check compile
	COMPOSE_HTTP_TIMEOUT=300 docker-compose up

# Quick check if "init" has been called
.PHONY: develop-check
develop-check:
	@if [ ! -d ".haxelib" ]; then echo 'Requires "make init"'; exit 1; fi

.PHONY: init
init: npm haxelib compile

# Build the docker image
.PHONY: image
image:
	echo ${VERSION} > .version
	docker build -t ${IMAGE_NAME}:${VERSION} .

.PHONY: version
version:
	@echo ${VERSION}

.PHONY: travis
travis:
	@if [ "${TRAVIS_BRANCH}" == "master" ] && [ "${TRAVIS_PULL_REQUEST}" != "false" ] && [ "${TRAVIS_REPO_SLUG}" == "dionjwa/docker-cloud-compute" ]; \
		then make test-ci; \
	fi
	@if [ "${TRAVIS_PULL_REQUEST}" == "false" ] && [ "${TRAVIS_REPO_SLUG}" == "dionjwa/docker-cloud-compute" ] && [ "${VERSION}" == "${TRAVIS_TAG}" ] && [ ! -z "${DOCKER_USERNAME}" ] && [ ! -z "${DOCKER_PASSWORD}" ]; \
	then \
		docker login --username ${DOCKER_USERNAME} --password ${DOCKER_PASSWORD}; \
		make push; \
	fi

.PHONY: compile-server
compile-server: prerequisites
	haxe etc/hxml/server-build.hxml

.PHONY: metaframe
metaframe:
	node_modules/.bin/webpack --mode=development

.PHONY: compile-test-server
compile-test-server: prerequisites
	haxe test/services/stand-alone-tester/build.hxml

.PHONY: compile-scaling-server
compile-scaling-server: prerequisites
	haxe test/services/stand-alone-tester/build.hxml

.PHONY: clean
clean:
	TEST=false TEST_SCALING=false docker-compose rm -fv
	rm -rf .haxelib
	rm -rf tmp
	rm -rf build
	rm -rf node_modules
	rm -rf node_modules_docker

# Functional tests
.PHONY: test-ci
test-ci: image test-post-image

.PHONY: test-post-image
test-post-image:
	VERSION=${VERSION} docker-compose -f docker-compose.ci.yml up --remove-orphans --abort-on-container-exit --exit-code-from dcc.tests

.PHONY: test-scaling
test-scaling: compile
	@echo "This is currently broken"
	#TEST=false TEST_SCALING=true docker-compose up --remove-orphans --abort-on-container-exit --exit-code-from dcc.tests

.PHONY: push
push: image push-post-image

.PHONY: push-post-image
push-post-image:
	docker tag ${IMAGE_NAME}:${VERSION} ${REMOTE_REPO}:${VERSION}
	docker push ${REMOTE_REPO}:${VERSION}

# Tag and push tags (triggers a build, push, that then tells circleci to deploy)
.PHONY: tag-update-files
tag-update-files:
	# Update dependent files:
	sed -i '' "s/default = \"dionjwa\/docker-cloud-compute:.*\"/default = \"dionjwa\/docker-cloud-compute:${VERSION}\"/g" etc/terraform/aws/modules/asg/variables.tf
	sed -i '' "s/docker-cloud-compute:.*/docker-cloud-compute:${VERSION}\"/g" etc/docker-compose/single-server/docker-compose.yml
	sed -i '' "s/\"version\": .*/\"version\": \"${VERSION}\",/" package.json
	sed -i '' "s/\"version\": .*/\"version\": \"${VERSION}\",/" src/lambda-autoscaling/package.json

# Tag and push tags (triggers a build, push, that then tells circleci to deploy)
.PHONY: tag
tag: tag-update-files
	git tag "v${VERSION}"
	git add etc/terraform/aws/modules/asg/variables.tf etc/docker-compose/single-server/docker-compose.yml Makefile package.json
	git commit -m "Version update > ${VERSION}"
	git push
	git tag --delete "v${VERSION}"
	git tag -f "v${VERSION}"
	git push --tags

.PHONY: npm
npm:
	${COMPOSE_TOOLS} node_modules

.PHONY: prerequisites
prerequisites:
	@command -v haxe >/dev/null 2>&1 || { echo >&2 "I require haxe but it's not installed.  Aborting."; exit 1; }

.PHONY: compile
compile: prerequisites
	haxe etc/hxml/build-all.hxml

.PHONY: develop-extra
develop-extra: compile
	TEST=true TEST_SCALING=false ${COMPOSE_DEV_BASE} -f docker-compose.extras-logging.yml -f docker-compose.extras-redis.yml up

.PHONY: haxelib
haxelib: haxelib-metaframe
	mkdir -p .haxelib && haxelib --always install etc/hxml/build-all.hxml

.PHONY: haxelib-metaframe
haxelib-metaframe:
	mkdir -p .haxelib && haxelib --always install build-metaframe.hxml

.PHONY: set-build-metaframe
set-build-metaframe:
	rm -f build.hxml && ln -s build-metaframe.hxml build.hxml

.PHONY: set-build-server
set-build-server:
	rm -f build.hxml && ln -s etc/hxml/server-build.hxml build.hxml

.PHONY: set-build-test
set-build-test:
	rm -f build.hxml && ln -s test/services/stand-alone-tester/build.hxml build.hxml

.PHONY: set-build-lambda
set-build-lambda:
	rm -f build.hxml && ln -s src/lambda-autoscaling/build.hxml build.hxml

.PHONY: set-build-test-scaling
set-build-test-scaling:
	rm -f build.hxml && ln -s test/services/local-scaling-server/build.hxml build.hxml

.PHONY: set-build-all
set-build-all:
	rm -f build.hxml && ln -s etc/hxml/build-all.hxml build.hxml

.PHONY: webpack-watch
webpack-watch: prerequisites
	node_modules/.bin/webpack-dev-server --watch --content-base clients/

# If your host has issues with compiling packages, you cannot update package-lock.json
# so this helper reinstalls in a docker container.
.PHONY: rebuild-package-lock.json
rebuild-package-lock.json:
	docker run --rm -v $$PWD:/code -w /code node:8.6.0-alpine /bin/sh -c 'apk update && apk add g++ gcc make python linux-headers udev && npm i'

.PHONY: lambda
lambda: tag-update-files
	(	haxe src/lambda-autoscaling/build.hxml && \
		export LAMBDA_ZIP_FOLDER="$${PWD}/etc/terraform/aws/modules/asg" && \
		export LAMBDA_SRC="$${PWD}/build/lambda-autoscaling" && \
		mkdir -p $${LAMBDA_ZIP_FOLDER} && \
		export LAMBDA_ZIP_NAME="lambda" && \
		rm -rf $${LAMBDA_ZIP_FOLDER}/$${LAMBDA_ZIP_NAME}.zip && \
		docker run --rm -ti -v $${LAMBDA_SRC}:/src -v $${LAMBDA_ZIP_FOLDER}:/destination dionjwa/aws-lambda-builder -s /src -d /destination --name $${LAMBDA_ZIP_NAME}	)

.PHONY: lambda-validate
lambda-validate:
	${COMPOSE_TOOLS} lambda-compile
	${COMPOSE_TOOLS} lambda-npm-install
	${COMPOSE_TOOLS} lambda-validate

# Oscure develop options: testing gpus
.PHONY: terraform-gpu-test-stack
terraform-gpu-test-stack:
	@echo $$'locals {\n    dcc_version = "${VERSION}"\n}' > test/gpus/terraform/version.tf
	@cd test/gpus/terraform && terraform apply -auto-approve

# Oscure develop options: testing gpus
.PHONY: terraform-gpu-full-deploy
terraform-gpu-full-deploy: push lambda terraform-gpu-test-stack
