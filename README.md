# go-pipeline

GitLab CI image for Go projects.

Included base/runtime:

- Go 1.26 (Alpine)
- git, make, gcc, musl-dev
- bash, openssh-client, ca-certificates, tzdata

Preinstalled Go tools:

- staticcheck
- ginkgo

## Publish Workflow

Build and push the image as multi-arch so both amd64 and arm64 runners can use it.

One-time builder setup:

```sh
docker buildx create --name multiarch-builder --driver docker-container --use
docker buildx inspect --bootstrap
```

Build and push:

```sh
docker buildx build \
	--builder multiarch-builder \
	--platform linux/amd64,linux/arm64 \
	-t voidptrorg/go-pipeline:latest \
	--push \
	.
```

Verify published platforms:

```sh
docker buildx imagetools inspect voidptrorg/go-pipeline:latest
```

Expected platforms include:

- linux/amd64
- linux/arm64

If only one platform is present, Docker executor jobs on the other architecture can fail with an exec format error.
