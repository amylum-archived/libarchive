PACKAGE = libarchive
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz
PATH_FLAGS = --prefix=$(RELEASE_DIR) --libdir=$(RELEASE_DIR)/usr/lib --includedir=$(RELEASE_DIR)/usr/include
CONF_FLAGS = --without-xml2
CFLAGS = -static -static-libgcc -Wl,-static -lc

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags | sed 's/v//')
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

.PHONY : default submodule manual container build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

build: submodule
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	patch -p0 -d $(BUILD_DIR) < patches/0001-Limit-write-requests-to-at-most-INT_MAX.patch
	patch -p0 -d $(BUILD_DIR) < patches/0001-mtree-fix-line-filename-length-calculation.patch
	patch -p0 -d $(BUILD_DIR) < patches/libarchive-3.1.2-acl.patch
	patch -p0 -d $(BUILD_DIR) < patches/libarchive-3.1.2-sparce-mtree.patch
	cd $(BUILD_DIR) && autoreconf -i
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(CFLAGS)' ./configure $(PATH_FLAGS) $(CONF_FLAGS)
	cd $(BUILD_DIR) && make install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp $(BUILD_DIR)/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	@sleep 3
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

