install: build
	cp ./.build/x86_64-apple-macosx/debug/munin ~/bin/.

build:
	sourcery
	swift build

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
	swiftformat --lint Sources

fmt:
	swiftlint autocorrect
	swiftformat Sources
