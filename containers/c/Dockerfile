FROM alpine:latest

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student
RUN apk add --no-cache \
    make \
    python3
RUN apk add --no-cache \
    clang22 \
    clang22-extra-tools \
    compiler-rt \
    gcc

COPY --chmod=755 stepper /usr/local/bin/stepper

USER 1001:1001
