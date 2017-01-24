# Mockable HTTP Server

Very simple http server, that is steerable (until some point) from remote.

By default it opens 2 ports:
* on `0.0.0.0:31337` HTTP server routes requests according to rules defined by REST API,
* on `0.0.0.0:31338` HTTP REST server accepts configuration.

# Installation

```shell
$ npm install
```

# Run unittests

```shell
$ gulp test
```

# Usage

```shell
$ coffee main.coffee
Starting public server at 0.0.0.0:31337
Starting API server at :31338
```
... and it will keep running.

# REST API

Go to `http://127.0.0.1:31338/` to see up-to-date documentation of methods exposed by REST API. All requests and responses use JSON as `Content-Type`.
