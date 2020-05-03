FROM nimlang/nim:alpine as nim
MAINTAINER setenforce@protonmail.com

COPY . /src/nitter
WORKDIR /src/nitter

RUN apk update \
    && apk add libsass-dev libffi-dev openssl-dev \
    && nimble build -y -d:release --passC:"-flto" --passL:"-flto" \
    && strip -s nitter \
    && nimble scss

FROM alpine
EXPOSE 8080
WORKDIR /src/
RUN apk --no-cache add pcre-dev sqlite-dev
COPY --from=nim /src/nitter/nitter /src/nitter/nitter.conf ./
COPY --from=nim /src/nitter/public ./public
CMD ./nitter
