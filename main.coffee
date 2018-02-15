# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

MockableHttpServer = require("./logic").MockableHttpServer
restService = require "rest-middleware/server"
http = require "http"
commandLineArgs = require "command-line-args"
accesslog = require "access-log"

options = [
    { name: "port", alias: "p", type: Number, defaultValue: 31337 },
    { name: "host", alias: "h", type: String, defaultValue: "0.0.0.0" },
    { name: "api-port", type: Number, defaultValue: 31338 },
    { name: "timeout", alias: "t", type: Number, defaultvalue: 300 }
]

args = commandLineArgs options
mockableHttpServer = new MockableHttpServer()

publicServerRequestListener = (request, response) ->
  accesslog(request, response)
  mockableHttpServer.dispatch(request, response)

console.log "Starting public server at #{args.host}:#{args.port}"
publicServer = http.createServer publicServerRequestListener
publicServer.listen args.port, args.host
console.info args
if args.timeout > 0
  publicServer.timeout = args.timeout * 1000

apiServer = restService {name: "mockableHttpServer"}
apiServer.methods {
  "routes": {
    docs: """
    Manages the list of all known routes.

    GET returns object, where key is a route ID and value is content
      that was previously passed to POST /routes.

    POST creates a new route, and returns new route ID.

    Route's content:
    * path: string
      REQUIRED. Regexp of URL to match.
    * times: uint
      OPTIONAL. The route will expire after these number of calls.
    * method:  string
      OPTIONAL. Matches only specified method. If absent, all methods are
      matched.
    * log: true
      OPTIONAL. If present, you can issue http://127.0.0.1:31337/log/{route_id}
      to receive logged request.
    * priority: int
      REQUIRED. Priority of the route. Routes with higher priority are
      processed first.
    * response:
      REQUIRED, conflicts with forward. This action will send predefined static
      response.
        code: uint. HTTP code to send.
        body: string. Body of HTTP response.
    * forward:
      REQUIRED, conflicts with response.
      Will silently relay HTTP request to specified server. And relay back
      the response.
      * host: string
      * port: uint
    * delay:
      OPTIONAL, requires forward, conflicts with log.
      Will delay relaying the HTTP request by specified time.
      * time: uint

    Example request body:
      ```
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
      ```

    DELETE removes all routes.

    @param {object} data: Route's content.
    """,
    url: "/routes",

    get: () ->
      return mockableHttpServer.methodRoutesGet()
    ,
    post: (data) ->
      return mockableHttpServer.methodRoutesPost(data)
    ,
    delete: () ->
      return mockableHttpServer.methodRoutesDelete()
  },
  "route": {
    docs: """
    Manages a specific route.

    * GET returns the route's content.

    POST replaces route's content with given one.

    DELETE removes the route.

    @param {string} id: Route's ID.
    @param {object} data: Route's content.
    """,
    url: "/route/:id",

    get: (id) ->
      return mockableHttpServer.methodRouteGet(id)
    ,
    post: (id, data) ->
      return mockableHttpServer.methodRoutePost(id, data)
    ,
    delete: (id) ->
      mockableHttpServer.methodRouteDelete(id)
  },
  "logs": {
    docs: """
    Manages routes with `log: true` that have responses logged.

    GET returns array of IDs for such routes.
    By default this is empty.

    Example response body:
    ```
        ["05310fd0-701e-11e6-bf06-bd0e3cf367e9",
          "07153920-701e-11e6-bf06-bd0e3cf367e9"]
    ```

    """,
    url: "/logs",

    get: () ->
      return mockableHttpServer.methodLogsGet()
  }
  "log": {
    docs: """
    Manages responses for routes with `log: true`.

    GET returns array of logged answers for given route ID.
    This is the flow:

    * if there are any answers right now, they are returned.
    * otherwise server will hold the request for up to given timeout. Treat this
    as slow polling.
    * if there are still no answers after the timeout, this will return
    404 error.

    This call is destructive - after a successful GET, the answers are removed
    from the cache, and they won't appear in next requests.

    Returns array of objects:
    * headers: object
    * body: string
    * method: string
    url: string

    Example response:
    ```
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
    ```

    @param {string} id: Route's ID.
    @param {int} timeout: Timeout to wait for requests, in seconds.
    If not given, defaults to 60 seconds.
    """,
    url: "/log/:id?timeout=:timeout",

    get: (id, timeout) ->
      return mockableHttpServer.methodLogGet(id, timeout)
  }
}

console.log "Starting API server at :#{args["api-port"]}"
apiServer.start {port: args["api-port"], silent: true}

console.log ""
