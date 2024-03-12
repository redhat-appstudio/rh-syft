# Known issues with the Syft image build

## Duplicates and questionable versions in the SBOM

Example from:

```bash
cosign download sbom quay.io/redhat-user-workloads/rhtap-build-tenant/rh-syft/rh-syft@sha256:d61915871c946b9d10c28b656e44d0ec6780d237ea57d141eafdf48edd6ee0c4
```

```jsonc
{
  "name": "github.com/anchore/syft",
  "version": "v0.89.0",
  "purl": "pkg:golang/github.com/anchore/syft@v0.89.0",
  "properties": [
    {
      "name": "syft:package:foundBy",
      "value": "go-module-binary-cataloger"
    }
    // ...
  ]
}
{
  "name": "github.com/anchore/syft",
  "version": "v0.89.1-0.20240117091148-157ea937edad",
  "purl": "pkg:golang/github.com/redhat-appstudio/rh-syft@v0.89.1-0.20240117091148-157ea937edad?type=module",
  "properties": [
    {
      "name": "cachi2:found_by",
      "value": "cachi2"
    }
  ]
}
```

Both Cachi2 and Syft itself report Syft in the SBOM. Cachi2 uses a more accurate
version (we apply extra commits on top of the tagged commit, so the pseudo-version
is more accurate). Cachi2 also uses a more accurate purl (the Syft code does indeed
come from `redhat-appstudio/rh-syft`, not from `anchore/syft`).

But CVE detection is more likely to pick up the component reported by Syft, since
the pseudo-version does not exist upstream.

To be resolved once we know more about the SBOM's use cases.

## False positives in the SBOM

Example SBOM from:

```bash
cosign download sbom quay.io/redhat-user-workloads/rhtap-build-tenant/rh-syft/rh-syft@sha256:d61915871c946b9d10c28b656e44d0ec6780d237ea57d141eafdf48edd6ee0c4
```

```bash
$ jq < sbom.json '.components[].purl | try match("pkg:[^/]*").string catch "<no purl>"' |
  sort | uniq -c | sort -n
      1 "pkg:ebuild"
      1 "pkg:nix"
      1 "pkg:rpm"
      2 "pkg:composer"
      5 "pkg:swift"
      7 "pkg:pub"
      8 "pkg:conan"
     10 "pkg:cargo"
     15 "pkg:nuget"
     16 "pkg:apk"
     17 "pkg:maven"
     21 "<no purl>"
     22 "pkg:hex"
     23 "pkg:cocoapods"
     27 "pkg:hackage"
     30 "pkg:pypi"
     39 "pkg:generic"
     47 "pkg:npm"
     55 "pkg:gem"
   1035 "pkg:golang"
```

Most of the non-golang packages come from test data.

TODO: we could solve it with .syft.yaml configuration, but that currently doesn't
work in the Konflux pipeline - part due to <https://github.com/anchore/syft/issues/2465>,
part because the generate-SBOM task does not set `$PWD` to the source directory.

## The `syft version` command reports dirty git status

Example:

```bash
$ podman run --rm -ti quay.io/redhat-user-workloads/rhtap-build-tenant/rh-syft/rh-syft@sha256:d61915871c946b9d10c28b656e44d0ec6780d237ea57d141eafdf48edd6ee0c4 version
Application:     syft
Version:         0.89.0
BuildDate:       2024-01-17T09:15:37Z
GitCommit:       157ea937edad6bbbcba7303a07eb69680365414c
GitDescription:  v0.89.0-6-g157ea937-dirty
Platform:        linux/amd64
GoVersion:       go1.20.10
Compiler:        gc
```

This is accurate; the Konflux pipeline makes modifications to the source directory
during the build. Rest assured, the modifications are harmless.
