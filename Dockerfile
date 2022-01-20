# Base image:
FROM golang:1.16-alpine3.14

# Install golint
ENV GOPATH /go
ENV PATH ${GOPATH}/bin:$PATH
RUN go get -u golang.org/x/lint

RUN apk add --no-cache gcc musl-dev
