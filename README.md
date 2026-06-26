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
  ./images/go-pipeline/
```

Verify published platforms:

```sh
docker buildx imagetools inspect voidptrorg/go-pipeline:latest
```

Expected platforms include:

- linux/amd64
- linux/arm64

If only one platform is present, Docker executor jobs on the other architecture can fail with an exec format error.

## Raspberry Pi Shell Runner

Device tests (`//go:build device_tests`) require real hardware and run on a dedicated Raspberry Pi registered as a shell-executor runner tagged `rpi`.

### Prerequisites

- Raspberry Pi running Raspberry Pi OS or DietPi (32-bit or 64-bit)
- I2C enabled (`sudo raspi-config` → Interface Options → I2C)

### Install build dependencies

```sh
sudo apt-get update
sudo apt-get install -y git make gcc libc-dev linux-headers-$(uname -r)
```

### Install Go

Install Go >= 1.21 (match the version in the project's `go.mod`):

```sh
# Check https://go.dev/dl/ for the latest ARM release
curl -LO https://go.dev/dl/go1.26.linux-arm64.tar.gz   # arm64
# or: go1.26.linux-armv6l.tar.gz for 32-bit Pi
sudo tar -C /usr/local -xzf go1.26.linux-*.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
```

### Install and register gitlab-runner

```sh
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install -y gitlab-runner
```

Register the runner (obtain `RUNNER_TOKEN` from **GitLab → Settings → CI/CD → Runners**):

```sh
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.void-ptr.org/" \
  --token "$RUNNER_TOKEN" \
  --executor shell \
  --description "rpi-device-runner" \
  --tag-list "rpi" \
  --run-untagged false
```

### Allow runner access to I2C

The `gitlab-runner` OS user needs to be in the `i2c` group so device tests can open the bus:

```sh
sudo usermod -aG i2c gitlab-runner
# Restart the runner to pick up the new group
sudo systemctl restart gitlab-runner
```

### Corresponding CI job

To target this runner from a project, add a job tagged `rpi`. Example for lateralus:

```yaml
device_tests:
  tags:
    - rpi
  stage: test
  script:
    - make deps
    - make test-device-ginkgo
  when: manual
```

The shell executor ignores the top-level `image:` key, so no Docker image is required.
