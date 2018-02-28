#!/bin/bash
# Requires:
# - npm
# - jq
# - wget

set -x

# Dependencies

npm install -g http-server || exit 1

# 0. Start servers

pkill -f main.coffee
pkill -f http-server

../node_modules/.bin/coffee ../main.coffee &
wget -q -O /dev/null --retry-connrefused http://localhost:31338/ || exit 1

http-server -p 31339 &
wget -q -O /dev/null --retry-connrefused http://localhost:31339/ || exit 1

# 1. Forward all requests

cat << EOF > postdata.txt
{"path":"","priority":10,"forward":{"host":"127.0.0.1","port":31339}}
EOF
wget -q -O - http://127.0.0.1:31338/routes --header 'Content-Type: application/json' --post-file=postdata.txt | jq . || exit 1
wget -q -O - http://127.0.0.1:31338/routes | jq . || exit 1

wget -q -O post http://127.0.0.1:31337/ || exit 1
diff index.html post || exit 1
rm post

# 2. One-time rewrite

cat << EOF > postdata.txt
{"path":"","priority":999,"log": true,"times":1,"response":{"code":"200","body": "krowa"}}
EOF
wget -q -O - http://127.0.0.1:31338/routes --header 'Content-Type: application/json' --post-file=postdata.txt | jq . || exit 1
wget -q -O - http://127.0.0.1:31338/routes | jq . || exit 1
wget -q -O - http://127.0.0.1:31338/logs | jq . || exit 1

# 2.1. Get logged request

wget -q -O post http://127.0.0.1:31337/fifteen || exit 1
echo -n krowa > pre
diff -u pre post || exit 1
rm pre post

wget -O - http://127.0.0.1:31338/logs > post || exit 1
echo -n '[]' > pre
diff -u pre post && exit 1
LOGID=$(jq -r '.[0]' post)
wget -O - "http://127.0.0.1:31338/log/${LOGID}" | jq . || exit 1
rm pre post

# 2.2. Second request is not rewrited

wget -q -O pre http://127.0.0.1:31339/ || exit 1
wget -q -O post http://127.0.0.1:31337/ || exit 1
diff index.html post || exit 1
rm post

wget -O - http://127.0.0.1:31338/logs > post || exit 1
echo -n '[]' > pre
diff -u pre post || exit 1

pkill -f main.coffee
pkill -f http-server
sleep 3

pkill -9 -f main.coffee
pkill -9 -f http-server
