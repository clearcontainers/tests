DESTDIR :=
PREFIX := /usr/local
BINDIR := $(PREFIX)/bin
SYSCONFDIR := $(PREFIX)/etc
LOCALSTATEDIR := $(PREFIX)/var

LOCALCIDIR=localCI

PKGLIBDIR := $(LOCALSTATEDIR)/lib/$(LOCALCIDIR)


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

generated-code.go:
	$(QUIET_GENERATE)echo "$$GENERATED_CODE" >$@

$(TARGET): $(SOURCES) $(GENERATED_FILES) Makefile
	$(QUIET_BUILD)go build -i -o $@ .

check: $(GENERATED_FILES) Makefile
	$(QUIET_CHECK)go test .

install:
	$(QUIET_INST)install -D $(TARGET) $(DESTDIR)$(BINDIR)/$(TARGET)
	$(QUIET_INST)install -m 600 -D config/$(CONFIG) $(DESTDIR)$(SYSCONFDIR)/localCI/$(CONFIG)

clean:
	rm -f $(TARGET)
