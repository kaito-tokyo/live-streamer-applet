CONFIGURATION ?= Release

TARGET_XCARCHIVES := build/LiveStreamerAppletYT.xcarchive

.PHONY: all
all: $(TARGET_XCARCHIVES)

build/%.xcarchive:
	xcodebuild archive -scheme "$*" -configuration $(CONFIGURATION) -archivePath "$@"

.PHONY: install
install: $(TARGET_XCARCHIVES)
	mkdir -p ~/Applications
	rm -rf ~/Applications/LiveStreamerAppletYT.app
	cp -R build/*.xcarchive/Products/Applications/*.app ~/Applications/
