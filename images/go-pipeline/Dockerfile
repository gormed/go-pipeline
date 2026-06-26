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
		tzdata \
	&& update-ca-certificates \
	&& mkdir -p /go/build-cache

RUN go install honnef.co/go/tools/cmd/staticcheck@latest \
	&& go install github.com/onsi/ginkgo/v2/ginkgo@latest
