FROM debian:jessie

RUN apt-get update
RUN apt-get install -y curl sudo
RUN curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
RUN apt-get install -y nodejs
RUN npm install -g gulp

RUN mkdir /cmhp
COPY package.json /cmhp/package.json
COPY main.coffee /cmhp/main.coffee
COPY logic.coffee /cmhp/logic.coffee

RUN apt-get install -y git
RUN cd /cmhp && npm install

EXPOSE 31337 31338
ENTRYPOINT ["/cmhp/node_modules/coffee-script/bin/coffee", "/cmhp/main.coffee"]
