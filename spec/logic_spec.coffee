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

mockRequire = require "mock-require"
mockProxyServer = jasmine.createSpyObj("proxy", ["web"])
mockCreateProxyServer = jasmine.createSpy("http-proxy.mockCreateProxyServer").and.callFake (opts) ->
    opts = opts
    return mockProxyServer

mockRequire "http-proxy", { createProxyServer: mockCreateProxyServer }

mockableHttpServer = require "../logic"

describe "MockableHttpServer", () ->
    tested =  null

    beforeEach () ->
        printCallback = jasmine.createSpy("printCallback")
        tested = new mockableHttpServer.MockableHttpServer(printCallback)

    it "should be defined", () ->
        expect(tested.methodRoutesGet).toBeDefined()
        expect(tested.methodRoutesPost).toBeDefined()
        expect(tested.methodRoutesDelete).toBeDefined()
        expect(tested.methodRouteGet).toBeDefined()
        expect(tested.methodRoutePost).toBeDefined()
        expect(tested.methodRouteDelete).toBeDefined()
        expect(tested.dispatch).toBeDefined()

    it "by default no routes", () ->
        expect(tested.methodRoutesGet()).toEqual {}

    it "many no routes", () ->
        for i in [0..10]
            i = i
            expect(tested.methodRoutesGet()).toEqual {}

    it "clears routes", () ->
        tested.methodRoutesDelete()
        expect(tested.methodRoutesGet()).toEqual {}

    it "many clears", () ->
        for i in [0..10]
            i = i
            tested.methodRoutesDelete() 
        expect(tested.methodRoutesGet()).toEqual {}

    it "does not add/change/delete nonexistent routes", () ->
        surelyNonexistent = "NAPEWNONIEMA"
        expect(() ->tested.methodRouteGet(surelyNonexistent)).toThrow
        expect(() ->tested.methodRoutePost(surelyNonexistent, {})).toThrow
        expect(() ->tested.methodRouteDelete(surelyNonexistent)).toThrow

    it "does not add invalid entry", () ->
        expect(() ->tested.methodRoutesPost()).toThrow

    describe "adds", () ->
        addedEntry = {
            path: "rower",
            method: "GET",
            response: {
                code: 200,
                body: "ROWER"
            },
            priority: 10
        }
        changedEntry = {
            path: "rower",
            method: "GET",
            response: {
                code: 201,
                body: "KWA"
            },
            priority: 10
        }

        beforeEach () ->
            tested.methodRoutesDelete()

        describe "one route", () ->
            addedId = undefined

            beforeEach () ->
                expected = {}
                addedId = tested.methodRoutesPost(addedEntry)
                expected[addedId] = addedEntry
    
                expect(tested.methodRoutesGet()).toEqual expected
                expect(tested.methodRouteGet(addedId)).toEqual addedEntry

            it "and deletes it", () ->
                tested.methodRouteDelete addedId
                expect(tested.methodRoutesGet()).toEqual {}
                expect(() ->tested.methodRouteGet(addedId)).toThrow
                expect(() ->tested.methodRouteDelete(addedId)).toThrow

            it "and throw when changing to null", () ->
                expect(() ->tested.methodRoutePost(addedId)).toThrow

            it "and changes it", () ->
                expected = {}
                expected[addedId] = changedEntry

                tested.methodRoutePost addedId, changedEntry
                expect(tested.methodRoutesGet()).toEqual expected
                expect(tested.methodRouteGet(addedId)).toEqual changedEntry

        describe "invalid entry", () ->
            it "no path", () ->
                anEntry = {method: "POST", priority: 1}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: no path or priority")

            it "method is not any of GET/POST", () ->
                anEntry = {method: "DELETE", path: "aaa", priority: 1}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: method must be POST or GET")

            it "times is not a number", () ->
                anEntry = {method: "GET", path: "aaa", priority: 1, times: "a"}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: times must be a non-negative integer")

            it "times is not a nonnegative number", () ->
                anEntry = {method: "GET", path: "aaa", priority: 1, times: 0}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: times must be a non-negative integer")

            it "no action", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: no action provided")

            it "no priority", () ->
                anEntry = {method: "POST", path: "aaa"}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: no path or priority")

            it "response: no code", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1, response: {body: "KROWA"}}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: response must have code and body")

            it "response: no body", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1, response: {code: "200"}}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: response must have code and body")

            it "forward: no host", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1, forward: {port: 8080}}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: forward must have host and port")

            it "forward: no port", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1, forward: {host: "localhost"}}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: forward must have host and port")

        describe "many routes", () ->
            expected = undefined

            beforeEach ()->
                expected = {}
                for i in [0..10]
                    i = i
                    anId = tested.methodRoutesPost(addedEntry)
                    expected[anId] = addedEntry

                expect(tested.methodRoutesGet()).toEqual expected
                for key in Object.keys(expected)
                    expect(tested.methodRouteGet(key)).toEqual addedEntry

            it "and deletes them", () ->
                callback = () -> tested.methodRouteGet(nextKey)
                while expected.length > 0
                    nextKey = Objects.key(expected)[0]
                    tested.methodRouteDelete nextKey
                    del expected[nextKey]

                    expect(tested.methodRoutesGet()).toEqual expected
                    expect(callback).toThrow

            it "and changes them", () ->
                for key in Object.keys(expected)
                    tested.methodRoutePost key, changedEntry
                    expected[key] = changedEntry
    
                expect(tested.methodRoutesGet()).toEqual expected
                for key in Object.keys(expected)
                    expect(tested.methodRouteGet(key)).toEqual changedEntry

    describe "dispatch", () ->
        request = null
        response = null
        proxy = null

        responseEntry = {
            path: "^response$",
            method: "GET",
            response: {
                code: 200,
                body: "ROWER"
            },
            priority: 99
        }
        responseTimesEntry = {
            path: "^response/times$",
            method: "GET",
            response: {
                code: 200,
                body: "ROWER"
            },
            priority: 10,
            times: 2
        }
        forwardEntry = {
            path: "^forward$",
            method: "GET",
            forward: {
                host: "example.ru"
                port: 1
            },
            priority: 1099
        }

        beforeEach () ->
            tested.methodRoutesDelete()
            tested.methodRoutesPost(responseEntry)
            tested.methodRoutesPost(responseTimesEntry)
            tested.methodRoutesPost(forwardEntry)

            request = jasmine.createSpyObj("request", ["anything", "on"])
            request.on.and.callFake (event, callback) ->
                if event == "end"
                    callback()

            request.url = "/invalid"
            request.method = "GET"
    
            response = jasmine.createSpyObj("response", ["end", "write"])
            proxy = jasmine.createSpyObj("proxy", ["web"])

        it "404s when cannot route", () ->
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual 404
            expect(response.statusMessage).toEqual "Not found"
            expect(response.write).toHaveBeenCalledWith("Not found")
            expect(response.end).toHaveBeenCalledWith

        it "responses for response route", () ->
            request.url = "/response"
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseEntry.response.body)
            expect(response.end).toHaveBeenCalledWith

        it "proxies for forward route", () ->
            request.url = "/forward"
            tested.dispatch(request, response, proxy)
            expect(mockProxyServer.web).toHaveBeenCalledWith(request, response, {target: "http://#{forwardEntry.forward.host}:#{forwardEntry.forward.port}"})

        it "decrements times", () ->
            request.url = "/response/times"

            # 2 -> 1
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseTimesEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseTimesEntry.response.body)
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(tested.methodRoutesGet()).length).toEqual(3)

            # 1 -> 0
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseTimesEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseTimesEntry.response.body)
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(tested.methodRoutesGet()).length).toEqual(2)

            # Already deleted
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual 404
            expect(response.statusMessage).toEqual "Not found"
            expect(response.write).toHaveBeenCalledWith("Not found")
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(tested.methodRoutesGet()).length).toEqual(2)
