#!/bin/bash
set -o errexit -o nounset -o pipefail

SCRIPTDIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
source "$SCRIPTDIR/lib.sh"

# Given a PR against the midstream branch (main), automatically generate a PR
# against the downstream branch (redhat-latest).
#
# If the midstream PR updates the Syft version, generate the downstream branch
# using hack/generate-downstream.sh. Otherwise, just generate the downstream
# branch by applying midstream changes (if any). Then, automatically push the
# downstream branch to the remote repo and open a PR.
#
# Run this script from a branch that currently has a PR open against main,
# or override the PR branch with PR_BRANCH=$branch hack/sync-pr-downstream.sh

# --- Overridable settings -----------------------------------------------------

PR_BRANCH=${PR_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}
PR_NUMBER=${PR_NUMBER:-$(gh pr view "$PR_BRANCH" --json number --jq .number)}
PR_TITLE=${PR_TITLE:-$(gh pr view "$PR_BRANCH" --json title --jq .title)}

SYNC_PR_AUTHOR=${SYNC_PR_AUTHOR:-$(git config --get user.email)}

# --- Main ---------------------------------------------------------------------

current_release=$(get_current_release)
last_release=$(get_last_release)

if [[ -z "$last_release" ]]; then
    error 'The redhat-latest branch is missing downstream changes; cannot determine the last released version.' \
          'Is the process of updating to a new upstream release in progress? Please finish the process first.'
    exit 1
fi

pr_commit=$(git rev-parse HEAD)
downstream_branch=downstream/${PR_BRANCH#midstream/}

if [[ "$current_release" != "$last_release" ]]; then
    # update the syft version
    base_ref=$current_release
    "$SCRIPTDIR/generate-downstream.sh" \
        -f \
        -v "$base_ref" \
        -m "$pr_commit" \
        -d "$downstream_branch"
else
    # apply new changes to the same syft version
    base_ref=origin/redhat-latest
    git checkout -B "$downstream_branch" "$base_ref"
    trap 'git checkout - >/dev/null' EXIT
    apply_midstream_changes "$pr_commit"
    if ! git commit -m "sync: $PR_TITLE"; then
        info 'No changes to synchronize'
        exit 0
    fi
fi

function should_push_branch() {
    local branch=$1
    local base_ref=$2

    # delete the local copy of the remote branch
    git branch --remote -d "origin/$branch" 2>/dev/null || true

    if git fetch origin "$branch" && [[ -z "$(git diff "$branch" "origin/$branch")" ]]; then
        info 'Downstream branch already up to date'
        return 1  # shouldn't push branch
    elif git rev-parse --verify "origin/$branch" 2>/dev/null; then
        commit_authors=$(git log --format='%ae' "$base_ref..origin/$branch")
        if grep --invert-match -qF "$SYNC_PR_AUTHOR" <<< "$commit_authors"; then
            error "The downstream branch was edited by someone other than $SYNC_PR_AUTHOR! Refusing to overwrite changes."
            git shortlog --summary --email "$base_ref..origin/$branch"
            exit 1  # should abort mission
        fi
    fi

    return 0  # should push branch
}

if should_push_branch "$downstream_branch" "$base_ref"; then
    git push --force origin "$downstream_branch"
fi

pr_body="Synced from #$PR_NUMBER"
if [[ "$current_release" != "$last_release" ]]; then
    pr_body+="

This PR updates the Syft version and likely isn't directly merge-able.
To merge it, please follow https://github.com/redhat-appstudio/rh-syft#finish-the-update."
fi

sync_pr_number=$(
    gh pr list --base redhat-latest --head "$downstream_branch" --json number --jq '.[].number'
)
if [[ -z "$sync_pr_number" ]]; then
    gh pr create \
        --base redhat-latest \
        --head "$downstream_branch" \
        --title "sync: $PR_TITLE" \
        --body "$pr_body"
else
    gh pr edit "$sync_pr_number" \
        --title "sync: $PR_TITLE" \
        --body "$pr_body"
fi
