LAST_RELEASE = $(shell git describe --tags --abbrev=0 origin/redhat-latest)
# either already released or a work in progress
CURRENT_RELEASE = v0.105.0

.PHONY: update-local
update-local:
	git fetch --tags origin redhat-latest
	git fetch --tags upstream main

.PHONY: list-upstream-versions
list-upstream-versions:
	# last 20 versions
	@git tag | sort --version-sort | tail -n 20

.PHONY: check-release
check-release:
	# latest upstream release
	@git describe --tags --abbrev=0 upstream/main
	# current version (either already released or a work in progress)
	@echo $(CURRENT_RELEASE)
	# last released downstream version
	@echo $(LAST_RELEASE)

.PHONY: check-build-changes
check-build-changes:
	git log --patch $(LAST_RELEASE)..$(CURRENT_RELEASE) -- Dockerfile .goreleaser.yaml

.PHONY: generate-downstream
generate-downstream:
	hack/generate-downstream.sh -v $(CURRENT_RELEASE)

.PHONY: backup-release-branch
backup-release-branch:
	git branch -f "redhat-$(LAST_RELEASE)" origin/redhat-latest
	git push origin "redhat-$(LAST_RELEASE)"

.PHONY: force-push-release-branch
force-push-release-branch:
	git branch -f redhat-latest $(CURRENT_RELEASE)
	git push -f --tags origin redhat-latest
