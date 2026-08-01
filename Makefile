install: build-release
	cp ./.build/release/munin ~/bin/.

# build-release, not build: this copies from .build/release, and SwiftPM points
# that symlink at the *last triple built*. After `make build-static` it is
# aarch64-swift-linux-musl, so depending on the debug `build` target would
# happily upload an arm64 binary from an x86_64 box.
publish: build-release
	scp ./.build/release/munin root@storage.terra.fap.no:/storage/nfs/k8s/builds/munin/.

build:
	swift build -c debug

build-release:
	swift build --configuration release

# --- fully static Linux binaries (musl) --------------------------------------
#
# Produces a `munin` with no PT_INTERP and no DT_NEEDED: it runs on any Linux
# of the right architecture with nothing installed. Both arches cross-compile
# from one x86_64 container -- no Alpine, no arm64 runner, no qemu in the build
# path.
#
# Plain `swift build` on Linux stays dynamic, deliberately: SwiftPM has no
# config file, environment variable or Package.swift setting that can default
# `--swift-sdk`, and `swift test` needs the dynamic toolchain regardless (the
# Static SDK ships no test framework -- see scripts/smoke-static.sh).
#
# Never run these inside `nix develop`: SwiftPM's own .pc parser reads HOST
# pkg-config directories during a --swift-sdk build.
MUSL_IMAGE ?= munin-musl
MUSL_WORK  ?= $(CURDIR)/.build/musl-sysroot
DOCKER     ?= docker

build-musl-image:
	$(DOCKER) build -t $(MUSL_IMAGE) build/musl-sysroot

MUSL_RUN = $(DOCKER) run --rm \
	  -v "$(CURDIR)/build/musl-sysroot:/recipe:ro" \
	  -v "$(MUSL_WORK):/work" $(MUSL_IMAGE)

# ~15 min cold, seconds when the per-stage stamps are already there.
#
# verify.sh runs per arch immediately after that arch is built: it is the only
# check that the C closure is *complete* (every archive present, right ELF
# machine, flat vips.pc, a static C probe round-tripping all four formats).
# Nothing downstream can tell a narrower closure from a correct one until a
# format fails at a user's runtime, and CI bakes this prefix into an image
# tagged by recipe hash and trusted from then on -- so it has to fail here.
build-musl-sysroot: build-musl-image
	mkdir -p "$(MUSL_WORK)"
	$(MUSL_RUN) bash /recipe/build.sh x86_64
	$(MUSL_RUN) bash /recipe/verify.sh x86_64
	$(MUSL_RUN) bash /recipe/build.sh aarch64
	$(MUSL_RUN) bash /recipe/verify.sh aarch64

# CONFIG=debug builds unstripped binaries with debug info, ~3x the size.
# That is what CI attaches to every run; tags ship CONFIG=release.
CONFIG ?= release

build-static-amd64:
	./scripts/build-static.sh amd64 $(CONFIG)

build-static-arm64:
	./scripts/build-static.sh arm64 $(CONFIG)

build-static: build-static-amd64 build-static-arm64

# End-to-end acceptance test for the static artifacts. Stands in for
# `swift test`, which cannot run against the Static SDK at all.
smoke-static-amd64:
	./scripts/smoke-static.sh .build/x86_64-swift-linux-musl/$(CONFIG)/munin --arch amd64

smoke-static-arm64:
	./scripts/smoke-static.sh .build/aarch64-swift-linux-musl/$(CONFIG)/munin --arch arm64

test:
	swift test

upgrade:
	echo "Not implemented"

# Note this also drops $(MUSL_WORK), i.e. the whole cross-built C closure --
# roughly 15 minutes to rebuild. `rm -rf .build/*-swift-linux-musl` is usually
# what you actually want.
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
