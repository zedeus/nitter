FROM nimlang/nim:alpine as nim
MAINTAINER setenforce@protonmail.com
EXPOSE 8080

COPY . /src/nitter
WORKDIR /src/nitter

RUN apk update \
    && apk add libsass-dev libffi-dev openssl-dev \
    && nimble build -y -d:release --passC:"-flto" --passL:"-flto" \
    && strip -s nitter \
    && nimble scss

FROM alpine
RUN apk --no-cache add pcre-dev sqlite-dev
RUN addgroup -S -g 1000 nitter
RUN adduser -S -u 1000 -G nitter -H -h /src nitter
RUN mkdir -p /src/tmp
RUN chown -R nitter:nitter /src/
USER nitter
WORKDIR /src/
COPY --from=nim /src/nitter/nitter /src/nitter/nitter.conf ./
COPY --from=nim /src/nitter/public ./public
CMD ./nitter
