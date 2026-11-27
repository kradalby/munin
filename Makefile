# Run inside `nix develop`: it supplies Swift and the C libraries, the same
# ones the flake builds with, on Linux and macOS alike.
#
# `build` and `test` are the fast dev loop and stay dynamic; `static` is what
# ships (see nix/README.md). `check` is everything CI runs.

.PHONY: install publish build build-release static check regen-example \
        test upgrade clean reinstall lint fmt run reset-lsp

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

# One file per arch that needs no dynamic loader and no shared libraries.
static:
	nix build .#munin-static-amd64 .#munin-static-arm64

check:
	nix flake check

# After a change that moves generated output on purpose (a libvips bump).
regen-example:
	nix run .#regen-example-content

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
