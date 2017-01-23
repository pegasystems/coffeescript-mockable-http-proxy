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

MockableHttpServer = require('./logic').MockableHttpServer
restService = require 'rest-middleware/server'
http = require 'http'
commandLineArgs = require 'command-line-args'

options = [
    { name: 'port', alias: 'p', type: Number, defaultValue: 31337 },
    { name: 'host', alias: 'h', type: String, defaultValue: '0.0.0.0' },
    { name: 'api-port', type: Number, defaultValue: 31338 }
]

args = commandLineArgs options
mockable_http_server = new MockableHttpServer

publicServerRequestListener = (request, response) ->
  mockable_http_server.dispatch(request, response)

console.log "Starting public server at #{args.host}:#{args.port}"
publicServer = http.createServer publicServerRequestListener
publicServer.listen args.port, args.host

apiServer = restService {name: 'mockable_http_server'}
apiServer.methods {
  'routes': {
    docs: "",
    url: '/routes',

    get: () ->
      return mockable_http_server.methodRoutesGet()
    ,
    post: (data) ->
      return mockable_http_server.methodRoutesPost(data)
    ,
    delete: () ->
      return mockable_http_server.methodRoutesDelete()
  },
  'route': {
    docs: "",
    url: '/route/:id',

    get: (id) ->
      return mockable_http_server.methodRouteGet(id)
    ,
    post: (id, data) ->
      return mockable_http_server.methodRoutePost(id, data)
    ,
    delete: (id) ->
      mockable_http_server.methodRouteDelete(id)
  },
  'logs': {
    docs: "",
    url: '/logs',

    get: () ->
      return mockable_http_server.methodLogsGet()
  }
  'log': {
    docs: "",
    url: '/log/:id?timeout=:timeout',

    get: (id, timeout) ->
      return mockable_http_server.methodLogGet(id, timeout)
  }
}

console.log "Starting API server at :#{args['api-port']}"
apiServer.start {port: args['api-port'], silent: true}

console.log ''
