FROM debian:stable-slim

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    python3 \
    clang \
    clang-tidy \
    libclang-rt-dev \
    && rm -rf /var/lib/apt/lists/*

USER 1001:1001
