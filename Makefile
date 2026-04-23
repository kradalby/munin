install: build-release
	cp ./.build/release/munin ~/bin/.

publish: build
	scp ./.build/release/munin root@storage.terra.fap.no:/storage/nfs/k8s/builds/munin/.

generate:
	sourcery
	make fmt

build:
	swift build -c debug

build-release:
	swift build --configuration release

build-static:
	swift build --static-swift-stdlib --configuration release

test:
	swift test

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
