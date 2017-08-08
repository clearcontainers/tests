# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

TARGET     := emailreport
PREFIX     := /usr
BINDIR     := $(PREFIX)/bin
SYSCONFDIR := /etc
DESTTARGET := $(BINDIR)/$(TARGET)
CONFFILE   := $(TARGET).toml
CONF       := conf/$(CONFFILE)
DESTCONF   := $(SYSCONFDIR)/$(TARGET)/$(CONFFILE)

all:
	go build -ldflags "-X main.sysConfFile=$(DESTCONF)" -o $(TARGET)

install:
	install -D $(TARGET) $(DESTTARGET)
	install -D $(CONF) $(DESTCONF)

clean:
	rm -f $(DESTTARGET)
	rm -rf $(SYSCONFDIR)/$(TARGET)

.PHONY: install clean
