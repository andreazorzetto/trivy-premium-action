OS := $(shell uname)
SED = sed
BATS_LIB_PATH = /usr/local/lib/

ifeq ($(OS), Darwin)
SED = gsed
BATS_LIB_PATH = /opt/homebrew/lib
endif

BATS_ENV := BATS_LIB_PATH=$(BATS_LIB_PATH) \
	GITHUB_REPOSITORY_OWNER=andreazorzetto \
	SCANNER_VERSION=saas-latest

BATS_FLAGS := --recursive --timing --verbose-run .

.PHONY: test
test: init-cache
	$(BATS_ENV) bats $(BATS_FLAGS)

.PHONY: update-golden
update-golden: init-cache
	UPDATE_GOLDEN=1 $(BATS_ENV) bats $(BATS_FLAGS)

.PHONY: init-cache
init-cache:
	mkdir -p .cache
	rm -f .cache/fanal/fanal.db

.PHONY: bump-scanner
bump-scanner:
	@[ $$NEW_VERSION ] || ( echo "env 'NEW_VERSION' is not set"; exit 1 )
	@CURRENT_VERSION=$$(grep "SCANNER_VERSION:" .github/workflows/test.yaml | awk '{print $$2}');\
	echo Current version: $$CURRENT_VERSION ;\
	echo New version: $$NEW_VERSION ;\
	$(SED) -i -e "s/$$CURRENT_VERSION/$$NEW_VERSION/g" README.md action.yaml .github/workflows/test.yaml Makefile ;\
