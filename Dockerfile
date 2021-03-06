# Base image:
FROM golang:1.16-alpine3.14

RUN apk add --no-cache git gcc musl-dev make

# Install golint
ENV GOPATH /go
ENV PATH ${GOPATH}/bin:$PATH
RUN go install honnef.co/go/tools/cmd/staticcheck@latest
