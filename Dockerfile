FROM debian:jessie
RUN apt-get update
RUN apt-get install -y curl sudo
RUN curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -
RUN apt-get install -y nodejs
RUN npm install -g gulp
