FROM nimlang/nim:alpine as nim
LABEL maintainer="setenforce@protonmail.com"
EXPOSE 8080

RUN apk --no-cache add libsass-dev libffi-dev openssl-dev redis openssh-client

COPY . /src/nitter
WORKDIR /src/nitter

RUN nimble build -y -d:release --passC:"-flto" --passL:"-flto" \
    && strip -s nitter \
    && nimble scss

FROM alpine:latest
WORKDIR /src/
RUN apk --no-cache add pcre sqlite
COPY --from=nim /src/nitter/nitter /src/nitter/nitter.example.conf ./nitter.conf
COPY --from=nim /src/nitter/public ./public
CMD ./nitter
