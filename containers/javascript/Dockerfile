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
    jest@30.4.2 \
    jest-junit@17.0.0 \
    acorn@8.17.0 \
    && \
    npm cache clean --force

USER 1001:1001
