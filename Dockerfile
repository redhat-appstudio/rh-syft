FROM brew.registry.redhat.io/rh-osbs/openshift-golang-builder:v1.21 AS build

WORKDIR /src/syft

# openshift-golang-builder sets GOFLAGS=-mod=vendor, unset it (we don't vendor dependencies)
ENV GOFLAGS=""

COPY go.mod go.sum .
RUN go mod download

COPY . .
RUN ./build-syft-binary.sh

FROM registry.access.redhat.com/ubi9/ubi-micro:9.4-6.1716471860@sha256:1c8483e0fda0e990175eb9855a5f15e0910d2038dd397d9e2b357630f0321e6d

ENV SYFT_CHECK_FOR_APP_UPDATE=false

# create the /tmp dir, which is needed for image content cache
WORKDIR /tmp

COPY --from=build /src/syft/dist/syft /usr/local/bin/syft

LABEL org.opencontainers.image.title="syft"
LABEL org.opencontainers.image.description="CLI tool and library for generating a Software Bill of Materials from container images and filesystems"
LABEL org.opencontainers.image.vendor="Red Hat, Inc."
LABEL org.opencontainers.image.licenses="Apache-2.0"

# required per https://github.com/release-engineering/rhtap-ec-policy/blob/main/data/rule_data.yml
# TODO: set up in Bugzilla
LABEL com.redhat.component="syft"
LABEL version="1.5.0"
# TODO: document the need to bump this on every re-release of the same version
LABEL release="1"
LABEL name="syft"
LABEL io.k8s.display-name="syft"
LABEL summary="syft"
LABEL description="CLI tool and library for generating a Software Bill of Materials from container images and filesystems"
LABEL io.k8s.description="CLI tool and library for generating a Software Bill of Materials from container images and filesystems"
LABEL vendor="Red Hat, Inc."
LABEL url="https://github.com/redhat-appstudio/rh-syft"
LABEL distribution-scope="public"

ENTRYPOINT ["/usr/local/bin/syft"]
