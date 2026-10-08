# HebFix developer tasks. Tools can be overridden, for example: make test BUSTED=/path/to/busted
LUACHECK ?= luacheck
BUSTED ?= busted
STYLUA ?= stylua
SHELLCHECK ?= shellcheck
ZIP ?= zip

SPOON := HebFix.spoon
DIST := dist
FMT_DIRS := $(wildcard $(SPOON) tests)
LUA_FILES := $(wildcard $(SPOON)/*.lua tests/*.lua tests/*/*.lua)
SPEC_FILES := $(wildcard tests/*_spec.lua)
SCRIPT_FILES := $(wildcard scripts/*.sh tests/scripts_test.sh)

.PHONY: all check lint fmt-check fmt test test-scripts package clean

all: check

check: lint fmt-check test

lint:
ifeq ($(strip $(LUA_FILES)),)
	@echo "lint: no Lua files, skipping"
else
	$(LUACHECK) .
endif

fmt-check:
ifeq ($(strip $(LUA_FILES)),)
	@echo "fmt-check: no Lua files, skipping"
else
	$(STYLUA) --check $(FMT_DIRS)
endif

fmt:
ifeq ($(strip $(LUA_FILES)),)
	@echo "fmt: no Lua files, skipping"
else
	$(STYLUA) $(FMT_DIRS)
endif

test:
ifeq ($(strip $(SPEC_FILES)),)
	@echo "test: no tests/*_spec.lua files, skipping"
else
	$(BUSTED)
endif

test-scripts:
ifeq ($(strip $(SCRIPT_FILES)),)
	@echo "test-scripts: no shell scripts, skipping"
else
	$(SHELLCHECK) $(SCRIPT_FILES)
	@if [ -f tests/scripts_test.sh ]; then bash tests/scripts_test.sh; \
	else echo "test-scripts: tests/scripts_test.sh missing, skipping run"; fi
endif

package:
	@test -d $(SPOON) || { echo "package: $(SPOON) not found" >&2; exit 1; }
	rm -rf $(DIST)
	mkdir -p $(DIST)
	$(ZIP) -r -X $(DIST)/$(SPOON).zip $(SPOON) -x '*.DS_Store'

clean:
	rm -rf $(DIST)
