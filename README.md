# Red Hat Syft

The Red Hat fork of [anchore/syft][upstream-syft] with modifications needed only
for Red Hat.

## Repository layout

* `main`
  * the "midstream," contains modifications for the upstream repository
* `redhat-latest`
  * tracks upstream releases, generated from upstream by applying midstream changes
  * includes `.tekton/` pipelines generated by [Konflux][konflux-docs]
* `redhat-vx.y.z`
  * branched from redhat-latest before updating to a newer upstream version
  * in case of need to [re-release an older version](#re-releasing-versions)

:warning: Set up your git remotes so that `origin` points to this repo and `upstream`
points to anchore/syft. Otherwise, the scripts and instructions in this repo won't
work. If you fork this repo, you will have to use a different name for your origin.

```text
my-origin -> git@github.com:USER/rh-syft.git
origin    -> git@github.com:redhat-appstudio/rh-syft.git
upstream  -> https://github.com/anchore/syft.git
```

### Branch lifecycle

Brief example:

```text
Before updating to 0.90.0:

 0.89.0      0.90.0
---o---o---o---o---···························---o upstream/main
    \
     a1---a2---b1---b2 redhat-latest

After updating to 0.90.0:

 0.89.0      0.90.0
---o---o---o---o---···························---o upstream/main
    \           \
     \           a1'---a2'---c1 redhat-latest (new)
      \
       a1---a2---b1---b2 redhat-v0.89.0

upstream/main | the upstream development branch, no relation to our midstream main
o             | upstream commits
a*            | commits generated by applying midstream changes
b*            | manual changes, commits made by the Konflux bot etc.
c1            | commit generated by copying Konflux pipelines from prev. redhat-latest
```

The `redhat-latest` branch is active, receives new commits regularly both from
the Konflux bot and from developers.

The `redhat-vx.y.z` branches are generally expected to be inactive, but may receive
new commits if necessary.

Notice that updating to a new release:

* Applies changes from the midstream (i.e. the `main` branch)
* Copies the Konflux pipelines (the `.tekton/` directory) as a whole
* But **discards other manual changes!**

Please follow the [patching guidelines](#patching-guidelines) when making manual
changes on `redhat-latest` to avoid losing them. When applicable, make the changes
in `main` first and then port them over to `redhat-latest`.

## Updating to a new release

### Update your local repo

```bash
git checkout main
git pull origin main
make update-local
```

### Bump the to-be-released version

Check if there is a new upstream version to update to:

```bash
make check-release
```

If the downstream is behind upstream, it's time to update. First step:

* Bump the `CURRENT_RELEASE` in the Makefile
* Bump the `version` label in the Dockerfile
* Commit the changes (best done on a new branch dedicated to the
  [midstream update](#updating-the-midstream))

<!-- TODO: Do we need to update one by one? Can we skip versions?
     Probably don't jump more than one minor release at a time. -->

### Determine if the build process needs changes

Do the upstream changes require corresponding changes to the downstream build process?

```bash
make check-build-changes
```

If you find that changes are indeed required, prepare to [update the midstream](#updating-the-midstream).
Otherwise, you can go ahead and generate the downstream branch.

### Generate the downstream branch

```bash
make generate-downstream
```

Open a pull request from the new branch to `redhat-latest`. The pull request will
not be merge-able due to conflicts, but the CI should run fine.

```bash
git push origin redhat-wip-${version_to_release}
# open a PR in github
```

If the build fails, make the necessary fixes. Apply them either in the midstream
or directly in the WIP release branch (see the [patching guidelines](#patching-guidelines)).

Once the CI is green, continue to the next step.

### Backup redhat-latest

:warning: Before finishing the release, make sure to backup the previous release
branch. Updating to a new release involves force-pushing to the release branch.

```bash
make backup-release-branch
```

### Finish the release

Make sure you have fulfilled the following:

* The CI in the pull request is passing
* Your midstream changes have made it to `main` (via a PR)
* **You have backed up the release branch**

Reset the `redhat-latest` branch to the to-be-released version and force-push it
(including tags):

```bash
make force-push-release-branch
```

This should resolve the merge conflict between `redhat-wip-${version_to_release}`
and `redhat-latest`, your PR should become merge-able. Finish the release by merging.

<!-- TODO: There might more Konflux stuff to deal with after this -->

## Patching guidelines

Is your patch "permanent" (i.e. will likely apply to every release going forward)?
Does it apply only to the CI and/or build process? Make the changes in the midstream
(see the [`hack/generate-downstream.sh`](hack/generate-downstream.sh) script).

Otherwise - if the patch is specific to a certain version - make the changes directly
in `redhat-latest` (or in the `redhat-vx.y.z` backup branch, if you're re-releasing
an older version). For example, backports or dependency updates are typically
version-specific.

If your patch concerns the `.tekton/` pipelines, apply it directly to the downstream
branch. These pipelines do not exist in the midstream.

In any case, please make the changes via a pull request.

### Updating the midstream

Test your midstream changes by generating a downstream branch from a specific upstream
release. Typically, you will want to do this while updating to a new release.

Create a new branch for your changes, e.g.:

```bash
git checkout -b midstream-${version_to_release} main
```

Generate and test the downstream branch as described [here](#generate-the-downstream-branch).
Make the necessary changes, move them over to the midstream branch if relevant
and repeat.

## Re-releasing versions

TODO:

* how to set up all the Konflux-isms
* how to do versioning

[upstream-syft]: https://github.com/anchore/syft
[konflux-docs]: https://redhat-appstudio.github.io/appstudio.docs.ui.io/
