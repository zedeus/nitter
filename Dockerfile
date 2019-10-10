FROM nimlang/nim:alpine as nim
MAINTAINER setenforce@protonmail.com
EXPOSE 8080
ENV HOSTNAME nitter.net

COPY . /src/nitter
WORKDIR /src/nitter

RUN apk update \
    && apk add python3 python3-dev bash libsass libsass-dev chromium chromium-chromedriver libffi libffi-dev openssl-dev \
    && pip3 install --upgrade pip && pip3 install -U seleniumbase pytest \
    && nimble build -y -d:release -d:hostname=${HOSTNAME} \
    && nimble scss \
    && mkdir -p ./tmp \
    && bash -c "./nitter & cd tests && pytest --headless -n 8 --reruns 5 --reruns-delay 1 && kill %1"

FROM alpine
WORKDIR /src/
COPY --from=nim /src/nitter .
RUN apk add pcre-dev sqlite-dev
CMD ./nitter
