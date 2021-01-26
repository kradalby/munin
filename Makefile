install: build-release
	cp ./.build/release/munin ~/bin/.

publish: build
	scp ./.build/release/munin root@storage.terra.fap.no:/storage/nfs/k8s/builds/munin/.

generate:
	sourcery
	swift test --generate-linuxmain
	make fmt

build:
	swift build -c debug --sanitize=thread

build-release:
	swift build --configuration release

test:
	swift test

dev:
	swift package generate-xcodeproj

upgrade:
	echo "Not implemented"

clean:
	rm -rf .build

reinstall:
	echo "Not implemented"

lint:
	swiftlint
	# swiftformat --lint Sources

fmt:
	swiftlint autocorrect
	swift-format --recursive --in-place Sources/ Package.swift

run: build
	./.build/x86_64-apple-macosx/debug/munin

reset-lsp:
	swift package reset
	swift package update
	killall sourcekit-lsp

