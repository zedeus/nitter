FROM nimlang/nim:alpine as nim

COPY . /src/nitter
WORKDIR /src/nitter

RUN apk update \
    && apk add libsass-dev libffi-dev openssl-dev \
    && nimble build -y -d:release --passC:"-flto" --passL:"-flto" \
    && strip -s nitter \
    && nimble scss

FROM alpine:latest
MAINTAINER setenforce@protonmail.com

EXPOSE 8080

ADD  ./entrypoint.sh /entrypoint.sh

RUN mkdir -p /build \
&&  apk --no-cache add tini pcre-dev sqlite-dev \
&&  rm -rf /var/cache/apk/*

COPY --from=nim /src/nitter/nitter /usr/local/bin
COPY --from=nim /src/nitter/nitter.conf /build
COPY --from=nim /src/nitter/public /build/public

WORKDIR /data
VOLUME  /data

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
CMD ["nitter"]