FROM nimlang/nim:alpine as nim
MAINTAINER setenforce@protonmail.com
EXPOSE 8080
ARG HOSTNAME
ENV HOSTNAME ${HOSTNAME:-nitter.net}

COPY . /src/nitter
WORKDIR /src/nitter

RUN apk update \
    && apk add libsass-dev libffi-dev openssl-dev \
    && nimble build -y -d:release -d:hostname=${HOSTNAME} \
    && nimble scss

FROM alpine
WORKDIR /src/
COPY --from=nim /src/nitter .
RUN apk add pcre-dev sqlite-dev
CMD ./nitter
