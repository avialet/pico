SHELL := /bin/zsh
PROJECT := Pico.xcodeproj
SCHEME := Pico
BUILD_DIR := $(CURDIR)/build
DERIVED := $(BUILD_DIR)/DerivedData
CORE := Packages/PicoCore

.PHONY: gen build run test core-test cli clean

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
	  -derivedDataPath $(DERIVED) CODE_SIGN_IDENTITY="-" build | tail -20
	rm -rf $(BUILD_DIR)/Pico.app
	cp -R $(DERIVED)/Build/Products/Debug/Pico.app $(BUILD_DIR)/Pico.app

run: build
	open $(BUILD_DIR)/Pico.app

# Tests du noyau : fonctionne avec les seuls Command Line Tools.
core-test:
	cd $(CORE) && swift run picocore-check $(FILTER)

test: core-test

cli:
	cd Tools/pico-cli && swift build -c release
	mkdir -p $(BUILD_DIR)
	cp Tools/pico-cli/.build/release/pico $(BUILD_DIR)/pico

clean:
	rm -rf $(BUILD_DIR) $(PROJECT) $(CORE)/.build Tools/pico-cli/.build
