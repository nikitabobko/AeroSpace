# makefile is used to make :make command in vim work out of the box
.PHONY: build test

build:
	./build-debug.sh

test:
	./run-tests.sh
