# SATYSFI_BIN := satysfi
SATYSFI_BIN := ../fork/SATySFi/result/bin/satysfi

.PHONY: all
all: build

# Build slide PDF.
.PHONY: build
build: slides.pdf

slides.pdf: slides.saty slydifi/my-theme.satyh
	$(SATYSFI_BIN) slides.saty

# Enter Docker shell.
.PHONY: shell
shell:
	docker run \
		-it \
		--rm \
		--name satysfi \
		satysfi \
		sh

# Build Docker container.
.PHONY: docker
docker:
	docker build --tag satysfi .

# Install dependencies.
.PHONY: deps
deps:
	rm -rf .satysfi
	docker create --name satysfi-tmp satysfi
	docker cp -L satysfi-tmp:/root/.satysfi .satysfi
	docker rm satysfi-tmp

# Clean all artifacts.
.PHONY: clean
clean:
	rm -f *.pdf *.satysfi-aux
