FROM ocaml/opam:alpine AS build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev pkgconf postgresql14-dev linux-headers npm

WORKDIR /home/opam

# Install dependencies
ADD ptb.opam ptb.opam
RUN opam install . --deps-only

# Build project
ADD . .
RUN opam exec -- dune build

#=====================================================

FROM alpine AS run

# Install system dependencies
RUN apk add --update libev openssl gmp postgresql14 npm 

RUN adduser --home /home/dream --shell /bin/sh --disabled-password dream

# Configure web application
COPY --from=build --chown=dream:dream /home/opam /usr/share/ptb

USER dream
WORKDIR /usr/share/ptb
RUN npm install -D tailwindcss
EXPOSE 8080
ENTRYPOINT /usr/share/ptb/_build/default/bin/main.exe
