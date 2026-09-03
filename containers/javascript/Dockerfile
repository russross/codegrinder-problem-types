FROM alpine:latest

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student
RUN apk add --no-cache \
    make \
    python3
RUN apk add --no-cache \
    nodejs \
    npm

RUN npm install -g --no-audit --no-fund \
    jest \
    jest-junit \
    acorn \
    && \
    npm cache clean --force

USER 1001:1001
