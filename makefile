# makefile is used to make :make command in vim work out of the box
.PHONY: build test format swift-test

build:
	./build-debug.sh

test:
	./run-tests.sh

swift-test:
	./run-swift-test.sh

format:
	./format.sh
