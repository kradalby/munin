# Munin builds three things:
#
#   Linux static (musl)  `make static`        -> nix, see nix/README.md
#   Linux dynamic        `make build` `test`  -> host Swift, or the container
#   Darwin dynamic       `make build` `test`  -> host Swift
#
# `build` and `test` are the fast dev loop and stay dynamic; `static` is what
# ships. On a host that cannot exec a Swift.org toolchain -- NixOS above all --
# use the `docker-` targets, or `nix develop .#swift`.

DOCKER ?= docker
SWIFT_VERSION := $(shell cat .swift-version)

.PHONY: install publish build build-release static smoke-static-amd64 \
        smoke-static-arm64 test docker-image docker-build docker-test \
        upgrade clean reinstall lint fmt run reset-lsp

install: build-release
	cp ./.build/release/munin ~/bin/.

publish: build-release
	scp ./.build/release/munin root@storage.terra.fap.no:/storage/nfs/k8s/builds/munin/.

build:
	swift build -c debug

build-release:
	swift build --configuration release

test:
	swift test

# --- fully static Linux binaries (musl) --------------------------------------
#
# One file that needs no dynamic loader and no shared libraries, so it runs on
# any Linux of the right arch with nothing installed. Both cross from x86_64.
#
# `swift build` stays dynamic: SwiftPM has no way to default --swift-sdk, and
# `swift test` needs the dynamic toolchain anyway.
static:
	nix build .#munin-static-amd64 .#munin-static-arm64

# `nix flake check` runs these in the sandbox; these targets run them under
# busybox instead, which is a second opinion rather than the same assertion.
smoke-static-amd64:
	./scripts/smoke-static.sh \
	  "$$(nix build --no-link --print-out-paths .#munin-static-amd64)/bin/munin" \
	  --arch amd64

smoke-static-arm64:
	./scripts/smoke-static.sh \
	  "$$(nix build --no-link --print-out-paths .#munin-static-arm64)/bin/munin" \
	  --arch arm64

# --- the container, for hosts without a usable system toolchain --------------
#
# A named volume for scratch, and /src read-only, so the container leaves no
# root-owned files in the tree and does not fight a host-side `swift build`.
DOCKER_SWIFT_IMAGE ?= munin-linux:$(SWIFT_VERSION)

docker-image:
	$(DOCKER) build --build-arg SWIFT_VERSION=$(SWIFT_VERSION) \
	  -t $(DOCKER_SWIFT_IMAGE) build/linux

define docker-swift
	$(DOCKER) run --rm -v "$(CURDIR):/src:ro" -v munin-swift-build:/build -w /src \
		$(DOCKER_SWIFT_IMAGE) $(1) --scratch-path /build
endef

docker-build: docker-image
	$(call docker-swift,swift build)

docker-test: docker-image
	$(call docker-swift,swift test)

upgrade:
	echo "Not implemented"

clean:
	rm -rf .build

reinstall:
	echo "Not implemented"

lint:
	swiftlint

fmt:
	swiftlint autocorrect
	swift-format --recursive --in-place Sources/ Tests/ Package.swift

run: build
	./.build/debug/munin

reset-lsp:
	swift package reset
	swift package update
	killall sourcekit-lsp || true
