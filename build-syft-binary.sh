#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail

# Roughly replicate goreleaser templating: https://goreleaser.com/customization/templates/.
# Needed for passing version information to the Syft build (see the upstream .goreleaser.yaml).

get_version() {
    local version
    version=$(git describe --tags --abbrev=0)
    # TODO: should we indicate the Red Hat patches in the version?
    # TODO: how to version re-releases of past versions?
    echo "${version#v}"  # strip the 'v' prefix
}

version=$(get_version)
full_commit=$(git rev-parse HEAD)
date="$(date --utc --iso-8601=seconds | cut -d '+' -f 1)Z"  # yyyy-mm-ddThh:mm:ssZ
summary=$(git describe --dirty --always --tags)

# command based on .goreleaser.yaml configuration
CGO_ENABLED=0 go build -ldflags "
  -w
  -s
  -extldflags '-static'
  -X main.version=$version
  -X main.gitCommit=$full_commit
  -X main.buildDate=$date
  -X main.gitDescription=$summary
" -o dist/syft ./cmd/syft

echo "--- output path: dist/syft ---"
dist/syft version
