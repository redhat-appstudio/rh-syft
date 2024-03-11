#!/bin/bash
set -o errexit -o nounset -o pipefail

usage() {
    cat << EOF
Usage: $0 -v version_to_release [-f] [-m midstream_branch] [-d downstream_branch] [-b base_release_branch]

Generate the downstream branch based on the specified upstream version.
The downstream branch is named redhat-wip-\$version_to_release.

-v: specify the upstream version to use as base for the downstream branch
-m: specify the branch from which to apply the midstream modifications
    default: current branch
-b: specify the base release branch (from which to copy the .tekton/ folder)
    default: redhat-latest
-f: force-generate the downstream branch even if it already exists locally
EOF
}

warn() {
    echo "WARNING: $1" >&2
}

VERSION_TO_RELEASE=''
MIDSTREAM_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DOWNSTREAM_BRANCH=''
BASE_RELEASE_BRANCH=redhat-latest
FORCE='false'

CUSTOM_FILES=(
    Dockerfile
    build-syft-binary.sh
)

while getopts v:m:d:b:fh opt; do
    case "$opt" in
        v) VERSION_TO_RELEASE=$OPTARG ;;
        m) MIDSTREAM_BRANCH=$OPTARG ;;
        d) DOWNSTREAM_BRANCH=$OPTARG ;;
        b) BASE_RELEASE_BRANCH=$OPTARG ;;
        f) FORCE='true' ;;
        h) usage; exit 0 ;;
        *) exit 1 ;;
    esac
done

if [[ -z "$VERSION_TO_RELEASE" ]]; then
    usage
    exit 1
fi

if [[ -z "$DOWNSTREAM_BRANCH" ]]; then
    DOWNSTREAM_BRANCH=downstream/$VERSION_TO_RELEASE
fi

if [[ "$FORCE" = 'true' ]]; then
    git checkout -B "$DOWNSTREAM_BRANCH" "$VERSION_TO_RELEASE"
else
    if ! git checkout -b "$DOWNSTREAM_BRANCH" "$VERSION_TO_RELEASE"; then
        echo "----------------------------------------------------------"
        echo "If the $DOWNSTREAM_BRANCH branch already exists, you can:"
        echo "- use '$0 -f ...' to overwrite it (discarding your changes)"
        echo "- rename it ('git branch -m $DOWNSTREAM_BRANCH <backup_name>')"
        exit 1
    fi
fi
trap 'git checkout - >/dev/null' EXIT

git rm -r .github/
git commit -s -m "Remove unwanted CI setup"

git checkout "$MIDSTREAM_BRANCH" -- "${CUSTOM_FILES[@]}"
git add "${CUSTOM_FILES[@]}"
git commit -s -m "Apply Red Hat specific modifications"

if ! git fetch origin "$BASE_RELEASE_BRANCH"; then
    warn "Could not fetch $BASE_RELEASE_BRANCH from origin. Will continue anyway."
fi

if git checkout "origin/$BASE_RELEASE_BRANCH" -- .tekton; then
    git add .tekton
    git commit -s -m "Copy Tekton pipelines from '$BASE_RELEASE_BRANCH' branch"
else
    warn "Could not copy Tekton pipelines from origin/$BASE_RELEASE_BRANCH."
fi

cat << EOF
--------------------------------------------------------------------------------
Generated downstream branch: $DOWNSTREAM_BRANCH
--------------------------------------------------------------------------------
EOF
