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

DEFAULT_TIMEOUT = 60
TICK = 100

restService = require "rest-middleware/server"
uuid = require "uuid"
arraySort = require "array-sort"
httpProxy = require "http-proxy"

clone = (obj) ->
  JSON.parse(JSON.stringify(obj))

class MockableHttpServer
  constructor: (printCallback=console.log, \
                setIntervalCallback=global.setInterval,
                setTimeoutCallback=global.setTimeout,
                promiseClassCallback=Promise) ->
    @proxy = httpProxy.createProxyServer {}
    @routes = {}
    @loggedRequests = {}
    @internalDataForRoutes = {}
    @sortedRoutes = []
    @areSortedRoutesValid = false

    @printCallback = printCallback
    @setIntervalCallback = setIntervalCallback
    @setTimeoutCallback = setTimeoutCallback
    @PromiseClassCallback = promiseClassCallback

    uthis = this
    printRoutes = () ->
      uthis.printCallback ""
      uthis.printCallback "We have #{Object.keys(uthis.routes).length} " + \
                          "routes:"

      for key in Object.keys(uthis.routes)
        uthis.printCallback "### #{key}"
        uthis.printRoute uthis.routes[key]

      uthis.printCallback ""

    @setIntervalCallback printRoutes, 60000

  sortRoutesIfNeeded: ->
    if @areSortedRoutesValid
      return null

    compareFunction = (left, right) ->
      return right.priority - left.priority

    values = []
    for key in Object.keys(@routes)
      value = @routes[key]
      nvalue = clone(value)
      nvalue.key = key
      values.push nvalue

    @sortedRoutes = arraySort values, compareFunction
    @areSortedRoutesValid = true
    null

  invalidateSortedRoutes: ->
    @areSortedRoutesValid = false
    null

  validateRoute: (data) ->
    if !data?
      throw new restService.ServerMethodError 400, "POST", [],
        "Invalid route data: empty"

    if !data.path? || !data.priority?
      throw new restService.ServerMethodError 400, "POST", [],
        "Invalid route data: no path or priority"

    if data.times?
      times = parseInt(data.times)
      if isNaN(times) or times <= 0
        throw new restService.ServerMethodError 400, "POST", [],
          "Invalid route data: times must be a non-negative integer"

    if data.method? and data.method != "POST" and data.method != "GET"
      throw new restService.ServerMethodError 400, "POST", [],
        "Invalid route data: method must be POST or GET"

    if data.delay?
      if !data.forward?
        throw new restService.ServerMethodError 400, "POST", [],
          "Invalid route data: delay requires forward"
      if data.log?
        throw new restService.ServerMethodError 400, "POST", [],
          "Invalid route data: delay conflicts with log"

    if data.response? or data.log? or data.forward?
      if data.response?
        if !data.response.code? || !data.response.body?
          throw new restService.ServerMethodError 400, "POST", [],
            "Invalid route data: response must have code and body"
      if data.forward?
        if !data.forward.host? or !data.forward.port?
          throw new restService.ServerMethodError 400, "POST", [],
            "Invalid route data: forward must have host and port"
    else
      throw new restService.ServerMethodError 400, "POST", [],
        "Invalid route data: no action provided"

  printRoute: (data) ->
    @printCallback "  with priority: #{data.priority}"
    @printCallback "  for URL: #{data.path}"

    if data.method?
      @printCallback "  for method: #{data.method}"

    if data.times?
      @printCallback "  will expire after #{data.times} calls"

    if data.response?
      @printCallback "Action is to respond"
      @printCallback "  with code #{data.response.code}"
      @printCallback "  with body: #{data.response.body}"

    if data.forward?
      @printCallback "Action is to forward all requests to " +
                     "#{data.forward.host}:#{data.forward.port}"
      if data.delay?
        @printCallback "  and delay HTTP request by #{data.delay} seconds"

    if data.log?
      @printCallback "Action is to log all requests"

  findMatchingRoutes: (opts) ->
    this.sortRoutesIfNeeded()
    matched = []

    for route in @sortedRoutes
      pathRegexp = @internalDataForRoutes[route.key].pathRegexp

      if not pathRegexp.test(opts.path)
        continue

      if route.method? and opts.method != route.method
        continue

      matched.push route

    return matched

  addLoggedRequestForRoute: (id, request) ->
    if !@loggedRequests[id]?
      @loggedRequests[id] = []
    @loggedRequests[id].push request

  getLoggedRequestsForRouteIfAny: (id) ->
    ret = @loggedRequests[id]
    if ret?
      delete @loggedRequests[id]
    return ret

  methodRoutesGet: () ->
    return @routes

  methodRoutesPost: (data) ->
    this.validateRoute data

    anId = uuid.v1()
    @routes[anId] = data
    @internalDataForRoutes[anId] = {pathRegexp: new RegExp(data.path)}
    this.invalidateSortedRoutes()

    @printCallback "Added new route #{anId}"
    this.printRoute data
    
    @printCallback "Now we have #{Object.keys(@routes).length} route(s)."
    @printCallback ""

    return anId

  methodRoutesDelete: () ->
    @printCallback "Deleted all routes."
    @printCallback ""

    @routes = {}
    this.invalidateSortedRoutes()

  methodRouteGet: (id) ->
    if !@routes[id]?
      throw new restService.ServerMethodError 404, "GET", [id]

    return @routes[id]

  methodRoutePost: (id, data) ->
    if !@routes[id]?
      throw new restService.ServerMethodError 404, "POST", [id]

    this.validateRoute data

    @routes[id] = data
    @internalDataForRoutes[id].pathRegexp = new RegExp(data.path)
    this.invalidateSortedRoutes()

    @printCallback "Updated route #{id}"
    this.printRoute data
    @printCallback ""

  methodRouteDelete: (id) ->
    if !@routes[id]?
      throw new restService.ServerMethodError 404, "DELETE", [id]

    delete @routes[id]
    this.invalidateSortedRoutes()

    @printCallback "Deleted route #{id}"
    @printCallback ""

  methodLogGet: (id, timeout) ->
    ret = this.getLoggedRequestsForRouteIfAny id
    if !ret?
      # We will need to wait for it
      if !timeout? || typeof timeout == "object"
        timeout = DEFAULT_TIMEOUT

      ticks = timeout * 1000 / TICK
      timeExpired = 0
      @printCallback "Waiting for logs of #{id} up to #{timeout} seconds"
      @printCallback ""

      uthis = this

      promise = new @PromiseClassCallback (resolve, reject) ->
        interval = null

        intervalFn = () ->
          ret = uthis.getLoggedRequestsForRouteIfAny id

          if ret?
            clearInterval interval
            resolve ret

            uthis.printCallback "Sent logs for #{id} after " +
                                "#{timeExpired * 0.001} seconds"
            uthis.printCallback ""
          else
            ticks -= 1
            if ticks < 1
              clearInterval interval
              uthis.printCallback "Timeout while waiting for logs of #{id}"
              uthis.printCallback ""

              reject "Did not get logs of #{id} after timeout of #{timeout}"
            else
              timeExpired += TICK
          null

        interval = uthis.setIntervalCallback intervalFn, TICK
        null

      return promise
  
    @printCallback "Sent logs of #{id}"
    @printCallback ""
    return ret

  methodLogsGet: () ->
    return Object.keys(@loggedRequests)
  
  dispatchNoRoutes: (request, response) ->
    response.statusCode = 404
    response.statusMessage = "Not found"
    response.write "Not found"
    response.end()

  tryDispatchInRoute: (request, response, route) ->
    uthis = this
    if route.log?
      buffer = ""

      request.on "data", (data) ->
        buffer += data
        uthis.printCallback "Request more data #{data.length}"
        null

      request.on "end", () ->
        uthis.printCallback "Request end"
        log = {headers: request.headers, method: request.method, \
               url: request.url, body: buffer}
        uthis.addLoggedRequestForRoute route.key, log
        null

    if route.times?
      route.times -= 1

      if route.times <= 0
        delete @routes[route.key]
        delete @internalDataForRoutes[route.key]
        this.invalidateSortedRoutes()

        @printCallback "Route #{route.key} expired"
        @printCallback ""

    if route.response?
      response.statusCode = route.response.code
      response.write route.response.body
      response.end()
      return true

    if route.forward?
      target = "http://#{route.forward.host}:#{route.forward.port}"

      if route.delay?
        @printCallback "Delaying by #{route.delay} seconds"

        cbk = () ->
          uthis.proxy.web request, response, {target: target}

        @setTimeoutCallback cbk, (route.delay) * 1000
      else
        @proxy.web request, response, {target: target}

      return true

    return false

  dispatch: (request, response) ->
    path = request.url.substring(1)
    @printCallback "Dispatch: #{path}"

    matchedRoutes = this.findMatchingRoutes {path: path, \
                                             method: request.method}
    if matchedRoutes.length > 0
      @printCallback "Matched #{matchedRoutes.length} routes"
      for route in matchedRoutes
        @printCallback "In route #{route.key}"
        this.printRoute route

        shouldStop = this.tryDispatchInRoute(request, response, route)
        if shouldStop
          return null

    @printCallback "No idea how to process the request!"
    this.dispatchNoRoutes request, response
    null

# eslint no-unused-expressions: "allow"
exports.MockableHttpServer = MockableHttpServer
