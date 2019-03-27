FROM ubuntu:16.04

RUN apt-get update && apt-get install -y wget
RUN wget -O - https://repo.saltstack.com/py3/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub | apt-key add -
RUN echo deb http://repo.saltstack.com/py3/ubuntu/16.04/amd64/latest xenial main > /etc/apt/sources.list.d/saltstack.list
RUN apt-get update && apt-get install -y salt-master salt-minion

COPY bootstrap /bootstrap

ENTRYPOINT ["/bootstrap"]
