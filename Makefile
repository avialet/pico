SHELL := /bin/zsh
PROJECT := Pico.xcodeproj
SCHEME := Pico
BUILD_DIR := $(CURDIR)/build
DERIVED := $(BUILD_DIR)/DerivedData
CORE := Packages/PicoCore
HAS_XCODE := $(shell xcodebuild -version >/dev/null 2>&1 && echo yes || echo no)

.PHONY: gen build xcode-build spm-build run test core-test cli clean

gen:
	xcodegen generate

# Avec Xcode : build via xcodebuild. Sans : SwiftPM + assemblage du bundle.
build:
ifeq ($(HAS_XCODE),yes)
	$(MAKE) xcode-build
else
	$(MAKE) spm-build
endif

xcode-build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
	  -derivedDataPath $(DERIVED) CODE_SIGN_IDENTITY="-" build | tail -20
	rm -rf $(BUILD_DIR)/Pico.app
	cp -R $(DERIVED)/Build/Products/Debug/Pico.app $(BUILD_DIR)/Pico.app

spm-build:
	swift build --product Pico 2>&1 | grep -E "error|warning: var|Build" || true
	scripts/bundle.sh debug

run: build
	pkill -x Pico || true
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
	rm -rf $(BUILD_DIR) $(PROJECT) .build $(CORE)/.build Tools/pico-cli/.build
