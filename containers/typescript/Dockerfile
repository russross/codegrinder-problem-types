FROM alpine:edge

RUN mkdir /home/student && chown 1001:1001 /home/student && chmod 0755 /home/student
ENV HOME=/home/student
WORKDIR /home/student

RUN apk add --no-cache \
    icdiff \
    make \
    nodejs \
    npm

RUN npm install @types/jest jest jest-junit ts-jest ts-node typescript --prefix /home

# Clean up npm cache to reduce image size
RUN npm cache clean --force

USER 1001:1001
