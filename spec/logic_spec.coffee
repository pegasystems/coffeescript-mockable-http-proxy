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
    mockProxyServer

mockRequire "http-proxy", { createProxyServer: mockCreateProxyServer }

mockableHttpServer = require "../logic"

describe "MockableHttpServer", () ->
    tested =  null
    setIntervalCallback = null
    setTimeoutCallback = null
    promiseClass = null

    beforeEach () ->
        printCallback = jasmine.createSpy("printCallback")
        setIntervalCallback = jasmine.createSpy("setIntervalCallback")
        setTimeoutCallback = jasmine.createSpy("setTimeoutCallback")
        promiseClass = jasmine.createSpy("promiseClass")

        tested = new mockableHttpServer.MockableHttpServer(printCallback,
            setIntervalCallback, setTimeoutCallback, promiseClass)
        #printCallback.and.callFake (x) ->
        #    console.info x
        null

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

    it "prints routes every 60 seconds - no routes", () ->
        expect(setIntervalCallback.calls.first().args[1]).toEqual 60000

        callback = setIntervalCallback.calls.first().args[0]
        callback()

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
        expect(() ->tested.methodRouteGet()).toThrow()
        expect(() ->tested.methodRouteGet(surelyNonexistent)).toThrow()
        expect(() ->tested.methodRoutePost()).toThrow()
        expect(() ->tested.methodRoutePost(surelyNonexistent)).toThrow()
        expect(() ->tested.methodRoutePost(null, {})).toThrow()
        expect(() ->tested.methodRoutePost(surelyNonexistent, {})).toThrow()
        expect(() ->tested.methodRouteDelete()).toThrow()
        expect(() ->tested.methodRouteDelete(surelyNonexistent)).toThrow()

    it "does not add invalid entry", () ->
        expect(() ->tested.methodRoutesPost()).toThrow()

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
                expect(() ->tested.methodRouteGet(addedId)).toThrow()
                expect(() ->tested.methodRouteDelete(addedId)).toThrow()

            it "and throw when changing to null", () ->
                expect(() ->tested.methodRoutePost(addedId)).toThrow()

            it "and changes it", () ->
                expected = {}
                expected[addedId] = changedEntry

                tested.methodRoutePost addedId, changedEntry
                expect(tested.methodRoutesGet()).toEqual expected
                expect(tested.methodRouteGet(addedId)).toEqual changedEntry

        it "prints routes every 60 seconds - ANY routes", () ->
            tested.methodRoutesPost(addedEntry)

            callback = setIntervalCallback.calls.first().args[0]
            callback()

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

            it "delay: no forward", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1, delay: 1}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: delay requires forward")

            it "delay: conflicts with log", () ->
                anEntry = {method: "POST", path: "aaa", priority: 1, forward: {}, delay: 1, log: {}}
                expect(() -> tested.methodRoutesPost(anEntry)).toThrow new Error("Invalid route data: delay conflicts with log")

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
                    expect(callback).toThrow()

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
        responsePostEntry = {
            path: "^response$",
            method: "POST",
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
        forwardDelayEntry = {
            path: "^forward/delay$",
            method: "GET",
            forward: {
                host: "example.ru"
                port: 1
            },
            priority: 1099,
            delay: 1
        }
        logEntry = {
            path: "^log$",
            method: "GET",
            priority: 999,
            log: true
        }

        beforeEach () ->
            tested.methodRoutesDelete()
            tested.methodRoutesPost(responseEntry)
            tested.methodRoutesPost(responsePostEntry)
            tested.methodRoutesPost(responseTimesEntry)
            tested.methodRoutesPost(forwardEntry)
            tested.methodRoutesPost(forwardDelayEntry)
            tested.methodRoutesPost(logEntry)

            request = jasmine.createSpyObj("request", ["anything", "on"])
            request.on.and.callFake (event, callback) ->
                if event == "end"
                    callback()

            request.url = "/invalid"
            request.method = "GET"

            response = jasmine.createSpyObj("response", ["end", "write"])
            proxy = jasmine.createSpyObj("proxy", ["web"])
            null

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

        it "404 for log route", () ->
            request.url = "/log"
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual 404

        it "proxies for forward route", () ->
            request.url = "/forward"
            tested.dispatch(request, response, proxy)
            expect(mockProxyServer.web).toHaveBeenCalledWith(request, response, {target: "http://#{forwardEntry.forward.host}:#{forwardEntry.forward.port}"})

        it "proxies for forward route with delay", (done) ->
            request.url = "/forward/delay"
            setTimeoutCallback.and.callFake (cbk, time) ->
                expect(time).toEqual(forwardDelayEntry.delay * 1000)
                cbk()

                expect(mockProxyServer.web).toHaveBeenCalledWith(request, response, {target: "http://#{forwardEntry.forward.host}:#{forwardEntry.forward.port}"})
                done()

            tested.dispatch(request, response, proxy)

        it "decrements times", () ->
            request.url = "/response/times"

            # 2 -> 1
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseTimesEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseTimesEntry.response.body)
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(tested.methodRoutesGet()).length).toEqual(6)

            # 1 -> 0
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual responseTimesEntry.response.code
            expect(response.write).toHaveBeenCalledWith(responseTimesEntry.response.body)
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(tested.methodRoutesGet()).length).toEqual(5)

            # Already deleted
            tested.dispatch(request, response, proxy)
            expect(response.statusCode).toEqual 404
            expect(response.statusMessage).toEqual "Not found"
            expect(response.write).toHaveBeenCalledWith("Not found")
            expect(response.end).toHaveBeenCalledWith
            expect(Object.keys(tested.methodRoutesGet()).length).toEqual(5)

    describe "logged requests", () ->
        beforeEach () ->
            setIntervalCallback.calls.reset()

        it "not found immediatelly", () ->
            promiseObj = jasmine.createSpy("promiseObj")
            resolve = jasmine.createSpy("resolve")
            reject = jasmine.createSpy("reject")
            promiseClass.and.returnValue promiseObj

            ret = tested.methodLogGet("anything", 0)
            expect(ret).toBe(promiseObj)

            call = promiseClass.calls.first().args[0]
            call(resolve, reject)
            expect(setIntervalCallback.calls.first().args[1]).toEqual 100

            callback = setIntervalCallback.calls.first().args[0]
            callback()
            expect(reject).toHaveBeenCalledWith "Did not get logs of anything after timeout of 0"
            expect(resolve).not.toHaveBeenCalled()

        it "not found - custom timeout", () ->
            promiseObj = jasmine.createSpy("promiseObj")
            resolve = jasmine.createSpy("resolve")
            reject = jasmine.createSpy("reject")
            promiseClass.and.returnValue promiseObj

            ret = tested.methodLogGet("anything", 0.2)
            expect(ret).toBe(promiseObj)

            call = promiseClass.calls.first().args[0]
            call(resolve, reject)
            expect(setIntervalCallback.calls.first().args[1]).toEqual 100
            callback = setIntervalCallback.calls.first().args[0]

            callback()
            expect(reject).not.toHaveBeenCalled()
            expect(resolve).not.toHaveBeenCalled()

            callback()
            expect(reject).toHaveBeenCalledWith "Did not get logs of anything after timeout of 0.2"
            expect(resolve).not.toHaveBeenCalled()

        it "not found - default timeout", () ->
            promiseObj = jasmine.createSpy("promiseObj")
            resolve = jasmine.createSpy("resolve")
            reject = jasmine.createSpy("reject")
            promiseClass.and.returnValue promiseObj

            ret = tested.methodLogGet("anything")
            expect(ret).toBe(promiseObj)

            call = promiseClass.calls.first().args[0]
            call(resolve, reject)
            expect(setIntervalCallback.calls.first().args[1]).toEqual 100
            callback = setIntervalCallback.calls.first().args[0]

            callback() for [0..601]
            expect(reject).toHaveBeenCalledWith "Did not get logs of anything after timeout of 60"
            expect(resolve).not.toHaveBeenCalled()

        describe "found", () ->
            request = null
            response = null
            proxy = null
            route = null
            expectedLog = null

            entry = {
                path: "^response$",
                method: "GET",
                response: {
                    code: 200,
                    body: "ROWER"
                },
                priority: 99,
                log: true
            }

            doRequest = () ->
                request.on.calls.reset()

                tested.dispatch(request, response, proxy)
                expect(response.statusCode).toEqual 200

                calls = request.on.calls.allArgs()
                expect(calls.length).toBe(2)
                expect(calls[0][0]).toEqual("data")
                expect(calls[1][0]).toEqual("end")

                onDataCallback = calls[0][1]
                onEndCallback = calls[1][1]

                onDataCallback("body")
                onEndCallback()

            beforeEach () ->
                tested.methodRoutesDelete()
                tested.methodRoutesPost(entry)

                request = jasmine.createSpyObj("request", ["anything", "on"])
                request.url = "/response"
                request.method = "GET"
                request.headers = {"Content-Type": "application/json"}
                response = jasmine.createSpyObj("response", ["end", "write"])
                proxy = jasmine.createSpyObj("proxy", ["web"])
                proxy.web.and.throwError "Should not be run"

                expectedLog = {
                    headers: request.headers,
                    method: request.method,
                    url: request.url,
                    body: "body"
                }

                tested.methodRoutesDelete()
                route = tested.methodRoutesPost(entry)
                null

            it "immediatelly", () ->
                doRequest()

                ret = tested.methodLogGet(route, 0)
                expect(ret.length).toBe(1)
                expect(ret[0]).toEqual(expectedLog)

                ret = tested.methodLogsGet()
                expect(ret.length).toBe(0)

            it "immediatelly - many", () ->
                doRequest()
                doRequest()
                doRequest()

                ret = tested.methodLogGet(route, 0)
                expect(ret.length).toBe(3)

            it "later", () ->
                promiseObj = jasmine.createSpy("promiseObj")
                resolve = jasmine.createSpy("resolve")
                reject = jasmine.createSpy("reject")
                promiseClass.and.returnValue promiseObj

                ret = tested.methodLogGet(route, 0.2)
                expect(ret).toBe(promiseObj)

                call = promiseClass.calls.first().args[0]
                call(resolve, reject)
                expect(setIntervalCallback.calls.first().args[1]).toEqual 100
                callback = setIntervalCallback.calls.first().args[0]

                doRequest()

                callback()
                expect(reject).not.toHaveBeenCalled()
                expect(resolve).not.toHaveBeenCalledWith(expectedLog)

                ret = tested.methodLogsGet()
                expect(ret.length).toBe(0)
