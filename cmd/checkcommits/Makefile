TARGET = checkcommits
SOURCES = $(shell find . 2>&1 | grep -E '.*\.go$$')

VERSION := ${shell cat ./VERSION}
COMMIT_NO := $(shell git rev-parse HEAD 2> /dev/null || true)
COMMIT := $(if $(shell git status --porcelain --untracked-files=no),"${COMMIT_NO}-dirty","${COMMIT_NO}")

default: $(TARGET)

$(TARGET): $(SOURCES)
	go install -ldflags "-X main.appCommit=${COMMIT} -X main.appVersion=${VERSION}" .
	go test

clean:
	rm -f $(TARGET)
