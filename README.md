[![Docker Automated build](https://img.shields.io/docker/automated/tsieprawskipega/coffeescript-mockable-http-server.svg)](https://hub.docker.com/r/tsieprawskipega/coffeescript-mockable-http-proxy/)
[![Travis](https://img.shields.io/travis/pegasystems/coffeescript-mockable-http-proxy.svg)](https://travis-ci.org/pegasystems/coffeescript-mockable-http-proxy)
[![npm](https://img.shields.io/npm/v/coffeescript-mockable-http-server.svg)](coffeescript-mockable-http-server)

# Mockable HTTP Server

Very simple http proxy, that is steerable (until some point) from remote.

By default it opens 2 ports:
* on `0.0.0.0:31337` HTTP server routes requests according to rules defined by REST API,
* on `0.0.0.0:31338` HTTP REST server accepts configuration.

# Installation

```
$ npm install
```

# Run unittests

```
$ gulp test
```

# Usage

```
$ coffee main.coffee
Starting public server at 0.0.0.0:31337
Starting API server at :31338
```

... and it will keep running.

## Or in docker

```
$ docker pull tsieprawskipega/coffeescript-mockable-http-proxy
$ docker run --rm -p 31338:31338 -p 31337:31337 tsieprawskipega/coffeescript-mockable-http-proxy
```

# REST API

Go to `http://127.0.0.1:31338/` to see up-to-date documentation of methods exposed by REST API. All requests and responses use JSON as `Content-Type`.
