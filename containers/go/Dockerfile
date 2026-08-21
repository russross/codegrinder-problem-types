FROM alpine:latest

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student
RUN apk add --no-cache \
    make \
    python3
ENV GODEBUG=installgoroot=all
RUN apk add --no-cache \
    go
RUN mkdir /go-cache && chown 1001:1001 /go-cache && chmod 0755 /go-cache
ENV GOCACHE=/go-cache
ENV CGO_ENABLED=0
RUN umask 0000 && go install -a std

USER 1001:1001
