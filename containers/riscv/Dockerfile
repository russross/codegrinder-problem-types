FROM alpine:latest

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student
RUN apk add --no-cache \
    make \
    python3
ADD https://github.com/russross/risclet/releases/download/v0.4.5/risclet-x86_64-unknown-linux-musl \
    /usr/local/bin/risclet
COPY update-grind /usr/local/bin/update-grind
RUN chmod 0755 /usr/local/bin/risclet /usr/local/bin/update-grind

USER 1001:1001
