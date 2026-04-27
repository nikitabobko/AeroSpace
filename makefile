# makefile is used to make :make command in vim work out of the box
.PHONY: build release install test format swift-test

build:
	./build-debug.sh

release:
	./generate.sh --ignore-xcodeproj --ignore-cmd-help --ignore-shell-parser
	swift build -c release --arch arm64 --product aerospace
	xcodebuild clean build -scheme AeroSpace -destination "generic/platform=macOS" -configuration Release -derivedDataPath .xcode-build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual
	rm -rf .release && mkdir .release
	cp -r ".xcode-build/Build/Products/Release/AeroSpace.app" .release
	cp -r .build/arm64-apple-macosx/release/aerospace .release

install: release
	osascript -e 'tell application "AeroSpace" to quit' 2>/dev/null || true
	pkill -f AeroSpace 2>/dev/null || true
	sleep 1
	rm -rf /Applications/AeroSpace.app
	cp -r .release/AeroSpace.app /Applications/AeroSpace.app
	cp .release/aerospace /opt/homebrew/bin/aerospace
	open /Applications/AeroSpace.app

test:
	./run-tests.sh

swift-test:
	./run-swift-test.sh

format:
	./format.sh

lint:
	./lint.sh
