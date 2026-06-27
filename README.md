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
if [ "$(uname -m)" = "aarch64" ]; then
  GO_TGZ="go1.26.0.linux-arm64.tar.gz"      # 64-bit Pi OS / DietPi
else
  GO_TGZ="go1.26.0.linux-armv6l.tar.gz"     # 32-bit Pi OS / DietPi (Pi Zero, Pi 3, Pi 4 on armv7l)
fi
curl -fL -o "$GO_TGZ" "https://go.dev/dl/$GO_TGZ"
sudo tar -C /usr/local -xzf "$GO_TGZ"
echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/go.sh
sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
/usr/local/go/bin/go version
```

### Install and register gitlab-runner

Check CPU architecture first:

```sh
uname -m
```

- `armv6l` (Pi Zero / Pi Zero W): the current `gitlab-runner` Debian package can fail with `Illegal instruction` during post-install.
- `armv7l` / `aarch64` (Pi Zero 2 / Pi 3 / Pi 4 / Pi 5): use the package install below.

```sh
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install -y gitlab-runner
```

If you already hit `Illegal instruction` on `armv6l`, clean up the broken package state:

```sh
sudo sh -c 'printf "#!/bin/sh\nexit 0\n" > /var/lib/dpkg/info/gitlab-runner.prerm'
sudo sh -c 'printf "#!/bin/sh\nexit 0\n" > /var/lib/dpkg/info/gitlab-runner.postrm'
sudo sh -c 'printf "#!/bin/sh\nexit 0\n" > /var/lib/dpkg/info/gitlab-runner.postinst'
sudo chmod +x /var/lib/dpkg/info/gitlab-runner.prerm /var/lib/dpkg/info/gitlab-runner.postrm /var/lib/dpkg/info/gitlab-runner.postinst
sudo dpkg --remove --force-remove-reinstreq --force-all gitlab-runner || true
sudo dpkg --purge --force-all gitlab-runner || true
sudo apt-get remove --purge -y gitlab-runner-helper-images || true
sudo dpkg --configure -a
sudo apt-get -f install
```

For Pi Zero / Pi Zero W (`armv6l`), use a custom armv6 runner binary instead of the Debian package:

```sh
# Build on macOS or Linux with Go installed, then copy to the Pi.
git clone https://gitlab.com/gitlab-org/gitlab-runner.git
cd gitlab-runner
GOOS=linux GOARCH=arm GOARM=6 CGO_ENABLED=0 go build -o gitlab-runner .
scp -O gitlab-runner dietpi@pi-zero-01:/tmp/gitlab-runner

# On the Pi:
sudo install -m 0755 /tmp/gitlab-runner /usr/local/bin/gitlab-runner
id -u gitlab-runner >/dev/null 2>&1 || sudo useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash
sudo gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
sudo gitlab-runner start
```

Obtain a registration token from **GitLab → Admin → Runners → Register an instance runner** (or per-project under **Settings → CI/CD → Runners**) and export it as `RUNNER_REGISTRATION_TOKEN`:

```sh
export RUNNER_REGISTRATION_TOKEN="<paste-token-here>"
```

```sh
sudo gitlab-runner register \
  --non-interactive \
  --url "https://gitlab.void-ptr.org/" \
  --registration-token "$RUNNER_REGISTRATION_TOKEN" \
  --executor shell \
  --description "rpi-device-runner" \
  --tag-list "rpi" \
  --run-untagged=false
```

### Allow runner access to I2C

```sh
sudo usermod -aG i2c gitlab-runner
sudo systemctl restart gitlab-runner
```

### Troubleshoot

Verify Go is available for the runner user:

```sh
sudo -u gitlab-runner bash -lc 'command -v go && go version'
```

Optional fallback (only if `go` is still not found in runner jobs):

```sh
sudo mkdir -p /etc/systemd/system/gitlab-runner.service.d
sudo tee /etc/systemd/system/gitlab-runner.service.d/path.conf >/dev/null <<'EOF'
[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/go/bin"
EOF
sudo systemctl daemon-reload
sudo systemctl restart gitlab-runner
sudo -u gitlab-runner bash -lc 'command -v go && go version'
```

### Uninstall runner

Unregister all configured runners on the host:

```sh
sudo gitlab-runner unregister --all-runners || true
```

Stop and uninstall the local service (works for custom binary installs):

```sh
sudo gitlab-runner stop || true
sudo gitlab-runner uninstall || true
```

Remove runner packages if this host used the apt install path:

```sh
sudo apt-get remove --purge -y gitlab-runner gitlab-runner-helper-images || true
sudo apt-get -f install
```

Cleanup local state, custom binary, and runner user:

```sh
sudo rm -f /usr/local/bin/gitlab-runner
sudo rm -rf /etc/gitlab-runner /home/gitlab-runner
sudo userdel --remove gitlab-runner || true
```

### Corresponding CI job

```yaml
device_tests:
  tags:
    - rpi
  stage: test
  variables:
    GOCACHE: "$CI_PROJECT_DIR/.cache/go-build"
    GOMODCACHE: "$CI_PROJECT_DIR/.cache/go-mod"
  before_script:
    - mkdir -p "$GOCACHE" "$GOMODCACHE"
  script:
    - make deps
    - make tools
    - make test-device-ginkgo
  when: manual
```

The shell executor ignores the top-level `image:` key, so no Docker image is required.
