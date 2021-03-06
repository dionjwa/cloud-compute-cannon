################################################
# Docker multi-stage build
# Clients and server are built separately
# Then smallest build artifacts are combined at
# the final step.
################################################

################################################
# Build metaframe client libs and resources
################################################
FROM dionjwa/haxe-watch:v0.15.0 as builder-metaframe

# Package the npm dependencies and package with browserify into a single file (libs.js)
COPY ./package.json /app/package.json
COPY ./package-lock.json /app/package-lock.json

WORKDIR /app

RUN npm install

COPY ./clients/shared/hxml /app/clients/shared/hxml
COPY ./build-metaframe.hxml /app/build-metaframe.hxml

RUN mkdir -p .haxelib && haxelib -notimeout --always install build-metaframe.hxml

# Add web media files
COPY ./clients/shared/src /app/clients/shared/src
COPY ./clients/metaframe/web /app/clients/metaframe/web
COPY ./clients/metaframe/src /app/clients/metaframe/src
COPY ./webpack.config.js /app/webpack.config.js

COPY ./Makefile /app/Makefile

# This is not copied, but it's easier to expect it
RUN touch .env

RUN node_modules/.bin/webpack --mode=production

################################################
# Build server npm libraries
################################################

FROM node:8.6.0-alpine as builder-server-npm

WORKDIR /app

RUN apk update
RUN apk add g++ gcc make python linux-headers udev git
ADD package.json /app/package.json
ADD package-lock.json /app/package-lock.json
RUN npm install --quiet


################################################
# Build all haxe (works)
################################################

FROM haxe:3.4.4-alpine3.7 as builder-haxe-all

RUN apk update && apk upgrade && \
    apk add --no-cache bash git openssh

# Install the haxelibs
COPY ./clients/shared/hxml /app/clients/shared/hxml
COPY ./src/lambda-autoscaling/build.hxml /app/src/lambda-autoscaling/build.hxml
COPY ./etc/hxml /app/etc/hxml
COPY ./test/services/stand-alone-tester/build.hxml /app/test/services/stand-alone-tester/build.hxml
COPY ./test/services/local-scaling-server/build.hxml /app/test/services/local-scaling-server/build.hxml
WORKDIR /app
RUN haxelib newrepo
RUN haxelib -notimeout --always install ./etc/hxml/build-all.hxml

# Add the src, and compile all
COPY ./clients/dashboard/src /app/clients/dashboard/src
COPY ./clients/metaframe/src /app/clients/metaframe/src
COPY ./clients/shared/src /app/clients/shared/src
COPY ./src /app/src
COPY ./test /app/test
COPY ./package.json /app/package.json
COPY ./.git /app/.git
COPY ./src/web /app/build/web
RUN haxe etc/hxml/build-all.hxml


################################################
# Final image build
################################################

FROM node:8.6.0-alpine
MAINTAINER Dion Amago Whitehead

ENV APP /app
RUN mkdir -p $APP
WORKDIR $APP

RUN npm install -g forever && touch $APP/.foreverignore

COPY --from=builder-server-npm /app/node_modules /app/node_modules
COPY --from=builder-haxe-all /app/build/server /app/server
COPY --from=builder-haxe-all /app/build/test /app/test
COPY --from=builder-haxe-all /app/build/web /app/web
COPY --from=builder-metaframe /app/build/clients/metaframe /app/clients/metaframe

COPY ./.version /app/.version

ENV PORT 9000
EXPOSE 9000

CMD forever server/docker-cloud-compute-server.js
