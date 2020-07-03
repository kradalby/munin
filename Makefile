install: build
	cp ./.build/x86_64-apple-macosx/debug/munin ~/bin/.

publish: build
	scp ./.build/x86_64-apple-macosx/debug/munin root@storage.terra.fap.no:/storage/nfs/k8s/builds/munin/.

generate:
	sourcery

build:
	swift build

build-cross:
	swift build -Xswiftc '-DCROSSPLATFORM'

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

run-cross: build-cross
	./.build/x86_64-apple-macosx/debug/munin
