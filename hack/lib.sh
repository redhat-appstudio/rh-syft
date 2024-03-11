#!/bin/bash

function _get_release() {
    local dockerfile_path=${1:-'-'}
    local version
    version=$(sed -nE 's;^LABEL version="([^"]*)";\1;p' "$dockerfile_path")
    if [[ -n "$version" ]]; then
        echo "v${version}"
    fi
}

function get_current_release() {
    _get_release Dockerfile
}

function get_last_release() {
    git show origin/redhat-latest:Dockerfile | _get_release
}
