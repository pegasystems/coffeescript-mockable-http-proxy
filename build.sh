#!/bin/bash
set -x

cat << EOF > build2.sh
npm install || exit 1
gulp || exit 1
EOF

docker run -v $(pwd):/home -w /home --rm bb2513e72695 bash /home/build2.sh