Very simple http server, that is steerable (until some point) from remote.

By default it opens 2 ports:
- on 0.0.0.0:31337 HTTP server routes requests according to rules defined by REST API,
- on 0.0.0.0:31338 HTTP REST server accepts configuration.

Installation:

$ npm install

Run unittests:

$ jasmine-node --coffee --verbose spec

Usage:

$ coffee main.coffee

REST API:
All requests and responses are JSON.

GET http://127.0.0.1:31338/routes
    Prints current routes. By default empty.
    Return: object[string->object]
        Each key is route id.
        Each value is the body of request that created that route.
    Example response body:
        {
            "05310fd0-701e-11e6-bf06-bd0e3cf367e9":
            {
                "path":"^ajax$",
                "times":1,
                "priority":99,
                "log":true,
                "response":
                {
                    "code":500,
                    "body":"Internal server error"
                }
            },
            "07153920-701e-11e6-bf06-bd0e3cf367e9":{...}
       }

POST http://127.0.0.1:31338/routes
    Adds a route.
    Expected body:
        path: string
            REQUIRED. Regexp of URL to match.
        times: uint
            OPTIONAL. The route will expire after these number of calls.
        method:  string
            OPTIONAL. Matches only specified method. If absent, all methods are matched.
        log: true
            OPTIONAL. If present, you can issue http://127.0.0.1:31337/log/{route_id} to receive logged request.
        priority: int
            REQUIRED. Priority of the route. Routes with higher priority are processed first.
        response:
            REQUIRED, conflicts with forward.
            This action will send predefined static response.
            code: uint
                HTTP code to send.
            body: string
                Body of HTTP response.
        forward:
            REQUIRED, conflicts with response.
            Will silently relay HTTP request to specified server. And relay back the response.
            host: string
            port: uint
    Return: string
        ID of the route.
    Example request body:
        {
            path: '^ajax$',
            times: 1,
            priority: 99,
            log: true,
            method: 'POST'
            response:
            {
                code: 500,
                body: 'Internal server error'
            }
        }
    Example response body:
        "rower"

DELETE http://127.0.0.1:31337/routes
    Deletes all routes.

GET http://127.0.0.1:31338/route/{route_id}
    Returns the body of request that created that route.
    Example response body:
        {
            path: '^ajax$',
            times: 1,
            priority: 99,
            log: true,
            method: 'POST'
            response:
            {
                code: 500,
                body: 'Internal server error'
            }
        }

POST http://127.0.0.1:31338/route/{route_id}
    Replaces route's content. See POST http://127.0.0.1:31338/routes for syntax.
    Example request body:
        {
            path: '^ajax$',
            times: 1,
            priority: 99,
            log: true,
            method: 'POST'
            response:
            {
                code: 500,
                body: 'Internal server error'
            }
        }

DELETE http://127.0.0.1:31338/route/{route_id}
    Deletes the route.

GET http://127.0.0.1:31338/logs
    Returns the array of route IDs such that:
    - it has log: true
    - any logged responses appeared.
    By default this is empty.
    Example response body:
        ["05310fd0-701e-11e6-bf06-bd0e3cf367e9","07153920-701e-11e6-bf06-bd0e3cf367e9"]

GET http://127.0.0.1:31338/log/{route_id}
GET http://127.0.0.1:31338/log/{route_id}?timeout={timeout}
    Returns the array of logged requests for this route ID.
    If there are already requests, there are returned.
    If there are no requests yet, the server will hold the request for up to {timeout} seconds.
    If there are still no requests, it should return 404 error.
    Otherwise it returns the array of requests.
    If not specified, timeout is 60 seconds.
    After the requests are returned, they are removed from the cache.

    Params:
        timeout: int
            OPTIONAL.
    Expected response: array[object]
        headers: object
        body: string
        method: string
        url: string
    Example response:
        [
            {
                "headers":
                {
                    "accept-language":"pl-PL",
                },
                "method":"POST",
                "url":"/ajax",
                "body": "..."
            }
            , ....
        ]
