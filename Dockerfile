FROM nimlang/nim:1.0.0-ubuntu-onbuild as build

ARG NITTER_HOSTNAME

ENV NITTER_HOSTNAME nitter.net

WORKDIR /build

COPY . /build

RUN apt-get update && apt-get install -y libsass-dev

RUN nimble build -d:release -d:hostname="$NITTER_HOSTNAME" --accept
RUN nimble scss


FROM nimlang/nim:1.0.0-ubuntu

RUN useradd --system nitter

RUN mkdir -p /nitter/tmp
RUN chown nitter:nitter -R /nitter

USER nitter

WORKDIR /nitter

COPY --from=build /build/nitter /nitter/

COPY --chown=nitter:nitter nitter.conf /nitter/
COPY public /nitter/public/

# to show commit info on /about page:
COPY .git /nitter/.git

EXPOSE 8080

CMD ./nitter
