FROM nimlang/nim:1.6.2-alpine-regular as nim
LABEL maintainer="setenforce@protonmail.com"
EXPOSE 8080

RUN apk --no-cache add libsass-dev pcre

WORKDIR /src/nitter

COPY nitter.nimble .
RUN nimble install -y --depsOnly

COPY . .
RUN nimble build -d:danger -d:lto -d:strip \
    && nimble scss \
    && nimble md

FROM alpine:latest
WORKDIR /src/
RUN apk --no-cache add pcre
COPY --from=nim /src/nitter/nitter ./
COPY --from=nim /src/nitter/nitter.example.conf ./nitter.conf
COPY --from=nim /src/nitter/public ./public
CMD ./nitter
