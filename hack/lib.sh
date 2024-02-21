#!/bin/bash
# --- Logging ------------------------------------------------------------------

if [[ "${GITHUB_ACTIONS:-false}" == true ]]; then
    _info="::notice::"
    _warn="::warning::"
    _error="::error::"
else
    # stderr is a terminal
    if [[ -t 2 ]]; then
        _red=$'\033[31m'
        _yellow=$'\033[33m'
        _blue=$'\033[34m'
        _reset=$'\033[0m'
    else
        _red=''
        _yellow=''
        _blue=''
        _reset=''
    fi
    _info="${_blue}notice:${_reset} "
    _warn="${_yellow}warning:${_reset} "
    _error="${_red}error:${_reset} "
fi

function _log_with_prefix() {
    local prefix=$1
    shift
    local msg
    for msg in "$@"; do
        printf "%s%s\n" "$prefix" "$msg" >&2
    done
}

function info() {
    _log_with_prefix "$_info" "$@"
}

function warn() {
    _log_with_prefix "$_warn" "$@"
}

function error() {
    _log_with_prefix "$_error" "$@"
}

# --- Utils --------------------------------------------------------------------

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

function apply_midstream_changes() {
    local midstream_ref=$1
    local custom_files=(Dockerfile build-syft-binary.sh .syft/)
    git checkout "$midstream_ref" -- "${custom_files[@]}"
    git add "${custom_files[@]}"
}
