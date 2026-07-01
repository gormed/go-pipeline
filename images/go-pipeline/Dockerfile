FROM golang:1.26-alpine3.23

ENV GOPATH=/go
ENV PATH=${GOPATH}/bin:${PATH}
ENV GOCACHE=/go/build-cache

RUN apk add --no-cache \
		bash \
		ca-certificates \
		gcc \
		git \
		linux-headers \
		make \
		musl-dev \
		openssh-client \
		shellcheck \
		tzdata \
	&& update-ca-certificates \
	&& mkdir -p /go/build-cache

RUN go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.12.2 \
	&& go install github.com/onsi/ginkgo/v2/ginkgo@v2.32.0 \
	&& go install mvdan.cc/sh/v3/cmd/shfmt@v3.13.1
