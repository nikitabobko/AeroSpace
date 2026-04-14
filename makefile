# makefile is used to make :make command in vim work out of the box
.PHONY: \
	build-debug.sh \
	test.sh \
	swift-test.sh \
	format.sh \
	lint.sh

build-debug.sh:
	./build-debug.sh

test.sh:
	./test.sh

swift-test.sh:
	./swift-test.sh

format.sh:
	./format.sh

lint.sh:
	./lint.sh
