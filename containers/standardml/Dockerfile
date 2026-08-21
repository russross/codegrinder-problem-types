FROM debian:bookworm

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student

RUN apt update

RUN apt install -y --no-install-recommends \
    make \
    python3
RUN apt install -y --no-install-recommends \
    build-essential \
    gdb
RUN apt install -y --no-install-recommends \
    polyml \
    rlwrap

RUN ln -rsf /usr/lib/aarch64-linux-gnu/libpolyml.so.9.0.0 /usr/lib/aarch64-linux-gnu/libpolyml.so

USER 1001:1001
