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

mockRequire = require 'mock-require'
mockProxyServer = jasmine.createSpyObj('proxy', ['web'])
mockCreateProxyServer = jasmine.createSpy('http-proxy.mockCreateProxyServer').andCallFake (opts) ->
    return mockProxyServer

mockRequire 'http-proxy', { createProxyServer: mockCreateProxyServer }

mockableHttpServer = require '../logic'

describe 'mockableHttpServer', () ->
    it 'should be defined', () ->
        expect(global.MockableHttpServer).toBeDefined()
        expect(global.MockableHttpServer.methodRoutesGet).toBeDefined()
        expect(global.MockableHttpServer.methodRoutesPost).toBeDefined()
        expect(global.MockableHttpServer.methodRoutesDelete).toBeDefined()
        expect(global.MockableHttpServer.methodRouteGet).toBeDefined()
        expect(global.MockableHttpServer.methodRoutePost).toBeDefined()
        expect(global.MockableHttpServer.methodRouteDelete).toBeDefined()
        expect(global.MockableHttpServer.dispatch).toBeDefined()

    it 'by default no routes', () ->
        expect(global.MockableHttpServer.methodRoutesGet()).toEqual {}

    it 'many no routes', () ->
        for i in [0..10]
            expect(global.MockableHttpServer.methodRoutesGet()).toEqual {}

    it 'clears routes', () ->
        global.MockableHttpServer.methodRoutesDelete()
        expect(global.MockableHttpServer.methodRoutesGet()).toEqual {}

    it 'many clears', () ->
        global.MockableHttpServer.methodRoutesDelete() for i in [0..10]
        expect(global.MockableHttpServer.methodRoutesGet()).toEqual {}

    it 'does not add/change/delete nonexistent routes', () ->
        surelyNonexistent = "NAPEWNONIEMA"
        expect(() ->global.MockableHttpServer.methodRouteGet(surelyNonexistent)).toThrow
        expect(() ->global.MockableHttpServer.methodRoutePost(surelyNonexistent, {})).toThrow
        expect(() ->global.MockableHttpServer.methodRouteDelete(surelyNonexistent)).toThrow

    it 'does not add invalid entry', () ->
        expect(() ->global.MockableHttpServer.methodRoutesPost()).toThrow

    describe 'adds', () ->
        addedEntry = {
            path: 'rower',
            method: 'GET',
            response: {
                code: 200,
                body: 'ROWER'
            },
            priority: 10
        }
        changedEntry = {
            path: 'rower',
            method: 'GET',
            response: {
                code: 201,
                body: 'KWA'
            },
            priority: 10
        }

        beforeEach () ->
            global.MockableHttpServer.methodRoutesDelete()

        describe 'one route', () ->
            addedId = undefined

            beforeEach () ->
                expected = {}
                addedId = global.MockableHttpServer.methodRoutesPost(addedEntry)
                expected[addedId] = addedEntry
    
                expect(global.MockableHttpServer.methodRoutesGet()).toEqual expected
                expect(global.MockableHttpServer.methodRouteGet(addedId)).toEqual addedEntry

            it 'and deletes it', () ->
                global.MockableHttpServer.methodRouteDelete addedId
                expect(global.MockableHttpServer.methodRoutesGet()).toEqual {}
                expect(() ->global.MockableHttpServer.methodRouteGet(addedId)).toThrow
                expect(() ->global.MockableHttpServer.methodRouteDelete(addedId)).toThrow

            it 'and throw when changing to null', () ->
                expect(() ->global.MockableHttpServer.methodRoutePost(addedId)).toThrow

            it 'and changes it', () ->
                expected = {}
                expected[addedId] = changedEntry

                global.MockableHttpServer.methodRoutePost addedId, changedEntry
                expect(global.MockableHttpServer.methodRoutesGet()).toEqual expected
                expect(global.MockableHttpServer.methodRouteGet(addedId)).toEqual changedEntry

        describe 'invalid entry', () ->
            it 'no path', () ->
                anEntry = {method: 'POST', priority: 1}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: no path or priority'

            it 'method is not any of GET/POST', () ->
                anEntry = {method: 'DELETE', path: 'aaa', priority: 1}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: method must be POST or GET'

            it 'times is not a number', () ->
                anEntry = {method: 'GET', path: 'aaa', priority: 1, times: 'a'}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: times must be a non-negative integer'

            it 'times is not a nonnegative number', () ->
                anEntry = {method: 'GET', path: 'aaa', priority: 1, times: 0}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: times must be a non-negative integer'

            it 'no action', () ->
                anEntry = {method: 'POST', path: 'aaa', priority: 1}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: no action provided'

            it 'no priority', () ->
                anEntry = {method: 'POST', path: 'aaa'}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: no path or priority'

            it 'response: no code', () ->
                anEntry = {method: 'POST', path: 'aaa', priority: 1, response: {body: 'KROWA'}}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: response must have code and body'

            it 'response: no body', () ->
                anEntry = {method: 'POST', path: 'aaa', priority: 1, response: {code: '200'}}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: response must have code and body'

            it 'forward: no host', () ->
                anEntry = {method: 'POST', path: 'aaa', priority: 1, forward: {port: 8080}}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: forward must have host and port'

            it 'forward: no port', () ->
                anEntry = {method: 'POST', path: 'aaa', priority: 1, forward: {host: 'localhost'}}
                expect(() -> global.MockableHttpServer.methodRoutesPost(anEntry)).toThrow 'Invalid route data: forward must have host and port'

        describe 'many routes', () ->
            expected = undefined

            beforeEach ()->
                expected = {}
                for i in [0..10]
                    anId = global.MockableHttpServer.methodRoutesPost(addedEntry)
                    expected[anId] = addedEntry
    
                expect(global.MockableHttpServer.methodRoutesGet()).toEqual expected
                for key in Object.keys(expected)
                    expect(global.MockableHttpServer.methodRouteGet(key)).toEqual addedEntry

            it 'and deletes them', () ->
                while expected.length > 0
                    nextKey = Objects.key(expected)[0]
                    global.MockableHttpServer.methodRouteDelete nextKey
                    del expected[nextKey]
    
                    expect(global.MockableHttpServer.methodRoutesGet()).toEqual expected
                    expect(() -> global.MockableHttpServer.methodRouteGet(nextKey)).toThrow

            it 'and changes them', () ->
                for key in Object.keys(expected)
                    global.MockableHttpServer.methodRoutePost key, changedEntry
                    expected[key] = changedEntry
    
                expect(global.MockableHttpServer.methodRoutesGet()).toEqual expected
                for key in Object.keys(expected)
                    expect(global.MockableHttpServer.methodRouteGet(key)).toEqual changedEntry

    describe 'dispatch', () ->
        request = null
        response = null
        proxy = null

        responseEntry = {
            path: '^response$',
            method: 'GET',
            response: {
                code: 200,
                body: 'ROWER'
            },
            priority: 99
        }
        responseTimesEntry = {
            path: '^response/times$',
            method: 'GET',
            response: {
                code: 200,
                body: 'ROWER'
            },
            priority: 10,
            times: 2
        }
        forwardEntry = {
            path: '^forward$',
            method: 'GET',
            forward: {
                host: 'example.ru'
                port: 1
            },
            priority: 1099
        }

        beforeEach () ->
            global.MockableHttpServer.methodRoutesDelete()
            global.MockableHttpServer.methodRoutesPost(responseEntry)
            global.MockableHttpServer.methodRoutesPost(responseTimesEntry)
            global.MockableHttpServer.methodRoutesPost(forwardEntry)

            request = jasmine.createSpyObj('request', ['anything', 'on'])
            request.on.andCallFake (event, callback) ->
                if event == 'end'
                    callback()

            request.url = "/invalid"
            request.method = 'GET'
    
            response = jasmine.createSpyObj('response', ['end', 'write'])
            proxy = jasmine.createSpyObj('proxy', ['web'])

        it '404s when cannot route', () ->
            global.MockableHttpServer.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual 404
            expect(response.statusMessage).toEqual "Not found"
            expect(response.write).toHaveBeenCalledWith("Not found")
            expect(response.end).toHaveBeenCalledWith

        it 'responses for response route', () ->
            request.url = "/response"
            global.MockableHttpServer.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseEntry.response.body)
            expect(response.end).toHaveBeenCalledWith

        it 'proxies for forward route', () ->
            request.url = "/forward"
            global.MockableHttpServer.dispatch(request, response, proxy)
            expect(mockProxyServer.web).toHaveBeenCalledWith(request, response, {target: "http://#{forwardEntry.forward.host}:#{forwardEntry.forward.port}"})

        it 'decrements times', () ->
            request.url = "/response/times"

            # 2 -> 1
            global.MockableHttpServer.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseTimesEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseTimesEntry.response.body)
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(global.MockableHttpServer.methodRoutesGet()).length).toEqual(3)

            # 1 -> 0
            global.MockableHttpServer.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseTimesEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseTimesEntry.response.body)
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(global.MockableHttpServer.methodRoutesGet()).length).toEqual(2)

            # Already deleted
            global.MockableHttpServer.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual 404
            expect(response.statusMessage).toEqual "Not found"
            expect(response.write).toHaveBeenCalledWith("Not found")
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(global.MockableHttpServer.methodRoutesGet()).length).toEqual(2)
