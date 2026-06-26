#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKERFILE="$ROOT/images/go-pipeline/Dockerfile"
README="$ROOT/README.md"

# BSD sed (macOS) requires an explicit empty-string argument to -i; GNU sed does not.
sedi() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

usage() {
  printf 'Usage: %s [options]\n\n' "$(basename "$0")"
  printf 'Options:\n'
  printf '  --go <tag>            Go base image tag  (e.g. 1.27-alpine3.24)\n'
  printf '  --golangci-lint <v>   golangci-lint version  (e.g. v2.13.0)\n'
  printf '  --ginkgo <v>          ginkgo version  (e.g. v2.33.0)\n'
  exit 1
}

GO_TAG=""
GOLANGCI_LINT_VER=""
GINKGO_VER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --go)            GO_TAG="$2";            shift 2 ;;
    --golangci-lint) GOLANGCI_LINT_VER="$2"; shift 2 ;;
    --ginkgo)        GINKGO_VER="$2";        shift 2 ;;
    -h|--help)       usage ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage ;;
  esac
done

[[ -z "$GO_TAG" && -z "$GOLANGCI_LINT_VER" && -z "$GINKGO_VER" ]] && usage

if [[ -n "$GO_TAG" ]]; then
  sedi "s|FROM golang:[^ ]*|FROM golang:$GO_TAG|" "$DOCKERFILE"
  printf 'Dockerfile: Go base image → golang:%s\n' "$GO_TAG"
fi

if [[ -n "$GOLANGCI_LINT_VER" ]]; then
  sedi "s|cmd/golangci-lint@v[0-9][0-9.]*|cmd/golangci-lint@$GOLANGCI_LINT_VER|" "$DOCKERFILE"
  sedi "s|golangci-lint v[0-9][0-9.]*|golangci-lint $GOLANGCI_LINT_VER|" "$README"
  printf 'Dockerfile + README: golangci-lint → %s\n' "$GOLANGCI_LINT_VER"
fi

if [[ -n "$GINKGO_VER" ]]; then
  sedi "s|ginkgo/v2/ginkgo@v[0-9][0-9.]*|ginkgo/v2/ginkgo@$GINKGO_VER|" "$DOCKERFILE"
  sedi "s|ginkgo v[0-9][0-9.]*|ginkgo $GINKGO_VER|" "$README"
  printf 'Dockerfile + README: ginkgo → %s\n' "$GINKGO_VER"
fi
