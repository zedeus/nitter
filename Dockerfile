FROM nimlang/nim:1.2.8-alpine as nim
MAINTAINER setenforce@protonmail.com
EXPOSE 8080

COPY . /src/nitter
WORKDIR /src/nitter

RUN apk --no-cache add libsass-dev libffi-dev openssl-dev redis \
    && nimble build -y -d:release --passC:"-flto" --passL:"-flto" \
    && strip -s nitter \
    && nimble scss

FROM redis:6.0.4-alpine
WORKDIR /src/
RUN apk --no-cache add pcre-dev sqlite-dev
COPY --from=nim /src/nitter/nitter /src/nitter/start.sh /src/nitter/nitter.conf ./
COPY --from=nim /src/nitter/public ./public
CMD ./start.sh
