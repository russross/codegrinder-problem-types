FROM alpine:latest

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student
RUN apk add --no-cache \
    make \
    python3
RUN apk add --no-cache \
    py3-mypy \
    py3-pip \
    py3-pygame \
    py3-setuptools \
    py3-six \
    diffutils
RUN pip3 install --break-system-packages unittest-xml-reporting cisc108

USER 1001:1001
