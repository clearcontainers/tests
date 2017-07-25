DESTDIR :=
PREFIX := /usr/local
BINDIR := $(PREFIX)/bin
SYSCONFDIR := $(PREFIX)/etc
LOCALSTATEDIR := $(PREFIX)/var

LOCALCIDIR=localCI

PKGLIBDIR := $(LOCALSTATEDIR)/lib/$(LOCALCIDIR)
PKGRUNDIR := $(LOCALSTATEDIR)/run/$(LOCALCIDIR)
PKGSYSCONFDIR := $(PREFIX)/etc/$(LOCALCIDIR)

SOURCES := $(shell find . 2>&1 | grep -E '.*\.(c|h|go)$$')
VERSION := ${shell cat ./VERSION}
COMMIT_NO := $(shell git rev-parse HEAD 2> /dev/null || true)
COMMIT := $(if $(shell git status --porcelain --untracked-files=no),${COMMIT_NO}-dirty,${COMMIT_NO})

TARGET = localCI
CONFIG = configuration.toml

V              = @
Q              = $(V:1=)
QUIET_INST     = $(Q:@=@echo    '     INSTALL  '$@;)
QUIET_GENERATE = $(Q:@=@echo    '     GENERATE '$@;)
QUIET_BUILD    = $(Q:@=@echo    '     BUILD    '$@;)
QUIET_CHECK    = $(Q:@=@echo    '     CHECK    '$@;)

default: $(TARGET)
.DEFAULT: $(TARGET)

#
# systemd files
#

HAVE_SYSTEMD := $(shell pkg-config --exists systemd 2>/dev/null && echo 'yes')

ifeq ($(HAVE_SYSTEMD),yes)
UNIT_DIR := $(shell pkg-config --variable=systemdsystemunitdir systemd)
UNIT_FILES = data/localCI.service
endif

$(UNIT_FILES): %: %.in
	$(QUIET_GENERATE)sed \
		-e 's|[@]bindir[@]|$(BINDIR)|g' \
		-e 's|[@]pkgsysconfdir[@]|$(PKGSYSCONFDIR)|g' \
		-e 's|[@]pkgrundir[@]|$(PKGRUNDIR)|g' \
		"$<" > "$@"

#
# Generated files
#

define GENERATED_CODE
// WARNING: This file is auto-generated - DO NOT EDIT!
package main

// commit is the git commit the localCI is compiled from.
const commit = "$(COMMIT)"

// version is the localCI version.
const version = "$(VERSION)"

// pkgLibDir is the localCI lib directory.
var pkgLibDir = "$(PKGLIBDIR)"
endef

export GENERATED_CODE

GENERATED_FILES += generated-code.go

#
# Install
#

define INSTALL_FILE
	$(QUIET_INST)install -D -m $3 $1 $(DESTDIR)$2/$1 || exit 1;

endef

install: $(TARGET) $(UNIT_FILES)
	$(call INSTALL_FILE,$(TARGET),$(DESTDIR)$(BINDIR),755)
	$(call INSTALL_FILE,data/$(CONFIG),$(SYSCONFDIR)/localCI,600)
	$(foreach f,$(UNIT_FILES),$(call INSTALL_FILE,$f,$(UNIT_DIR),644))


generated-code.go:
	$(QUIET_GENERATE)echo "$$GENERATED_CODE" >$@

$(TARGET): $(SOURCES) $(GENERATED_FILES) Makefile
	$(QUIET_BUILD)go build -i -o $@ .

check: $(GENERATED_FILES) Makefile
	$(QUIET_CHECK)go test .

clean:
	rm -f $(TARGET) $(UNIT_FILES) $(GENERATED_FILES)
