#!/bin/bash
set -x

docker build -t tsieprawskipega/coffeescript-mockable-http-proxy .
docker run -p 31338:31338 -p 31337:31337 tsieprawskipega/coffeescript-mockable-http-proxy -- npm test
