ARG appname="fsocaml"

#=------------------------------------------------------------------
# BUILD STAGE
# We use the official `ocaml/opam` image to build the OCaml project.
#-------------------------------------------------------------------

FROM ocaml/opam:alpine AS build

# Install system dependencies
RUN sudo apk add --update libev-dev openssl-dev gmp-dev pkgconf postgresql14-dev linux-headers npm

RUN mkdir /home/opam/${appname}
WORKDIR /home/opam/${appname}


# Install project dependencies
ADD ${appname}.opam ${appname}.opam
RUN opam install . --deps-only

# Build project
ADD . .
RUN opam exec -- dune build

#=------------------------------------------------------------------
# CREATE RUNTIME IMAGE
# We create a minimal Alpine image with just the necessary libraries
# to support the runtime application.
#-------------------------------------------------------------------

FROM alpine AS run

# Install system dependencies
RUN apk add --update libev openssl gmp postgresql14 npm 

RUN adduser --home /home/dream --shell /bin/sh --disabled-password dream

# Configure web application
COPY --from=build --chown=dream:dream /home/opam/${appname} /usr/share/${appname}

USER dream
WORKDIR /usr/share/${appname}
RUN npm install -D tailwindcss
EXPOSE 8080
ENTRYPOINT /usr/share/${appname}/_build/default/bin/main.exe
