# golang CI pipeline

GitLab CI pipeline infrastructure for Go projects.

## CI Images

Images live under `images/<name>/` and are automatically built and pushed to Docker Hub on every push to `main` via `.github/workflows/docker.yml`.

### go-pipeline

Base image for Go projects (`voidptrorg/go-pipeline:latest`).

Included:

- Go 1.26 (Alpine)
- git, make, gcc, musl-dev, linux-headers
- bash, openssh-client, ca-certificates, tzdata

Preinstalled Go tools:

- golangci-lint v2.12.2
- ginkgo v2.32.0

### Manual publish

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

Both `linux/amd64` and `linux/arm64` must be present. If only one is listed, Docker executor jobs on the other architecture will fail with an exec format error.

## Raspberry Pi Shell Runner

Device tests (`//go:build device_tests`) require real hardware and run on a Raspberry Pi registered as a shell-executor runner tagged `rpi`.

### Prerequisites

- Raspberry Pi running Raspberry Pi OS or DietPi (32-bit or 64-bit)
- I2C enabled (`sudo raspi-config` → Interface Options → I2C)

### Install build dependencies

```sh
sudo apt-get update
sudo apt-get install -y git make gcc libc6-dev raspberrypi-kernel-headers
```

### Install Go

Install Go >= 1.21 (match the version in the project's `go.mod`):

```sh
# Check https://go.dev/dl/ for the latest ARM release
curl -LO https://go.dev/dl/go1.26.linux-arm64.tar.gz   # arm64 (64-bit Pi)
# or: go1.26.linux-armv6l.tar.gz for 32-bit Pi Zero
sudo tar -C /usr/local -xzf go1.26.linux-*.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
```

### Install and register gitlab-runner

```sh
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install -y gitlab-runner
```

Obtain `RUNNER_TOKEN` from **GitLab → Admin → Runners → Register an instance runner** (or per-project under **Settings → CI/CD → Runners**):

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

```sh
sudo usermod -aG i2c gitlab-runner
sudo systemctl restart gitlab-runner
```

### Corresponding CI job

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
