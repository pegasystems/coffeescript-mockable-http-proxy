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

restService = require 'rest-middleware/server'
uuid = require 'uuid'
arraySort = require 'array-sort'
httpProxy = require 'http-proxy'

clone = (obj) ->
  return JSON.parse(JSON.stringify(obj))

class MockableHttpServer
    constructor: () ->
        @proxy = httpProxy.createProxyServer {}
        @routes = {}
        @loggedRequests = {}
        @internalDataForRoutes = {}
        @sortedRoutes = []
        @areSortedRoutesValid = false

        uthis = this
        printRoutes = () ->
          console.log ''
          console.log "We have #{Object.keys(uthis.routes).length} routes:"
    
          for key in Object.keys(uthis.routes)
            console.log "### #{key}"
            uthis.printRoute uthis.routes[key]

          console.log ''

        setInterval printRoutes, 60000

    sortRoutesIfNeeded: ->
      if @areSortedRoutesValid
        return

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

    invalidateSortedRoutes: ->
      @areSortedRoutesValid = false

    validateRoute: (data) ->
      if !data?
        throw new restService.ServerMethodError 400, 'POST', [],
          'Invalid route data: empty'

      if !data.path? || !data.priority?
        throw new restService.ServerMethodError 400, 'POST', [],
          'Invalid route data: no path or priority'

      if data.times?
        times = parseInt(data.times)
        if isNaN(times) or times <= 0
          throw new restService.ServerMethodError 400, 'POST', [],
            'Invalid route data: times must be a non-negative integer'

      if data.method? and data.method != 'POST' and data.method != 'GET'
        throw new restService.ServerMethodError 400, 'POST', [],
          'Invalid route data: method must be POST or GET'

      if data.response? or data.log? or data.forward?
          if data.response?
            if !data.response.code? || !data.response.body?
              throw new restService.ServerMethodError 400, 'POST', [],
                'Invalid route data: response must have code and body'
          if data.forward?
            if !data.forward.host? or !data.forward.port?
              throw new restService.ServerMethodError 400, 'POST', [],
                'Invalid route data: forward must have host and port'
      else
        throw new restService.ServerMethodError 400, 'POST', [],
          'Invalid route data: no action provided'

    printRoute: (data) ->
      console.log "  with priority: #{data.priority}"
      console.log "  for URL: #{data.path}"

      if data.method?
        console.log "  for method: #{data.method}"

      if data.times?
        console.log "  will expire after #{data.times} calls"

      if data.response?
        console.log "Action is to respond"
        console.log "  with code #{data.response.code}"
        console.log "  with body: #{data.response.body}"

      if data.forward?
        console.log "Action is to forward all requests to #{data.forward.host}:#{data.forward.port}"

      if data.log?
        console.log "Action is to log all requests"

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

      console.log "Added new route #{anId}"
      this.printRoute data
      
      console.log "Now we have #{Object.keys(@routes).length} route(s)."
      console.log ''

      return anId

    methodRoutesDelete: () ->
      console.log "Deleted all routes."
      console.log ''

      @routes = {}
      this.invalidateSortedRoutes()

    methodRouteGet: (id) ->
      if !@routes[id]?
        throw new restService.ServerMethodError 404, 'GET', [id]

      return @routes[id]

    methodRoutePost: (id, data) ->
      if !@routes[id]?
        throw new restService.ServerMethodError 404, 'POST', [id]

      this.validateRoute data

      @routes[id] = data
      @internalDataForRoutes[id].pathRegexp = new RegExp(data.path)
      this.invalidateSortedRoutes()

      console.log "Updated route #{id}"
      this.printRoute data
      console.log ''

    methodRouteDelete: (id) ->
      if !@routes[id]?
        throw new restService.ServerMethodError 404, 'DELETE', [id]

      delete @routes[id]
      this.invalidateSortedRoutes()

      console.log "Deleted route #{id}"
      console.log ''

    methodLogGet: (id, timeout) ->
      ret = this.getLoggedRequestsForRouteIfAny id
      if !ret?
        # We will need to wait for it
        if !timeout? || typeof timeout == 'object'
          timeout = DEFAULT_TIMEOUT

        ticks = timeout * 1000 / TICK
        timeExpired = 0
        console.log "Waiting for logs of #{id} up to #{timeout} seconds"
        console.log ''

        uthis = this

        promise = new Promise (resolve, reject) ->
         interval = null

         intervalFn = () ->
           ret = uthis.getLoggedRequestsForRouteIfAny id

           if ret?
             clearInterval interval
             resolve ret

             console.log "Sent logs for #{id} after #{timeExpired * 0.001} seconds"
             console.log ''
             return

           ticks -= 1
           if ticks < 1
             clearInterval interval
             console.log "Timeout while waiting for logs of #{id}"
             console.log ''

             reject "Did not get logs of #{id} after timeout of #{timeout}"
           else
             timeExpired += TICK

          interval = setInterval intervalFn, TICK
        return promise
    
      console.log "Sent logs of #{id}"
      console.log ''
      return ret

    methodLogsGet: () ->
      return Object.keys(@loggedRequests)
    
    dispatchNoRoutes: (request, response) ->
      response.statusCode = 404
      response.statusMessage = "Not found"
      response.write 'Not found'
      response.end()

    tryDispatchInRoute: (request, response, route) ->
      if route.log?
        buffer = ''
        uthis = this

        request.on 'data', (data) ->
          buffer += data

        request.on 'end', () ->
          log = {headers: request.headers, method: request.method, url: request.url, body: buffer}
          uthis.addLoggedRequestForRoute route.key, log

      if route.times?
        route.times -= 1

        if route.times <= 0
          delete @routes[route.key]
          delete @internalDataForRoutes[route.key]
          this.invalidateSortedRoutes()

          console.log "Route #{route.key} expired"
          console.log ''

      if route.response?
        response.statusCode = route.response.code
        response.write route.response.body
        response.end()
        return true

      if route.forward?
        target = "http://#{route.forward.host}:#{route.forward.port}"
        @proxy.web request, response, {target: target}
        return true

      return false

    dispatch: (request, response) ->
      path = request.url.substring(1)
      console.log "Dispatch: #{path}"

      matchedRoutes = this.findMatchingRoutes {path: path, method: request.method}
      if matchedRoutes.length > 0
        console.log "Matched #{matchedRoutes.length} routes"
        for route in matchedRoutes
          console.log "In route #{route.key}"
          this.printRoute route

          shouldStop = this.tryDispatchInRoute(request, response, route)
          if shouldStop
            console.log "Stop!"
            console.log ''
            return

      console.log "No idea how to process the request"
      this.dispatchNoRoutes request, response

exports. MockableHttpServer = MockableHttpServer
