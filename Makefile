# Makefile for building, tagging, publishing and releasing projects.
#
# Import build-time configuration.
# You can change the default config with `make env="config_special.env" build`.
# env ?= .env
# include $(env)
# export $(shell sed 's/=.*//' $(env))

# Use bash instead of sh.
SHELL := /usr/bin/env bash

# Retrieve application version from metadata file.
GIT_COMMIT_SHA1 := $(shell git rev-parse HEAD 2>/dev/null)
GIT_COMMIT_SHA1_SHORT := $(shell git rev-parse --short HEAD 2>/dev/null)
GIT_BRANCH := $(shell git symbolic-ref --short HEAD 2>/dev/null)
ifneq ($(BUILD_NUMBER),)
	VERSION = $(GIT_COMMIT_SHA1_SHORT)-$(BUILD_NUMBER)
else
	VERSION = $(GIT_COMMIT_SHA1_SHORT)
endif

IMAGE_TAG ?= latest

# Handy utilities.
DONE = echo ✓ $@ done
FAILED = echo ✘ $@ failed

# Materialized executables.
DOCKER_CMD ?= docker
DOCKER_COMPOSE_CMD ?= docker-compose

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help docker version

help: ## This halp!
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := docker

docker-all: docker docker-push ## Creates custom docker image, tags and pushes it.

docker: ## Creates custom docker image with compose.
	@echo 'Building custom docker image and tagging it.'
	GIT_COMMIT_SHA1_SHORT=$(GIT_COMMIT_SHA1_SHORT) $(DOCKER_COMPOSE_CMD) build
	@$(DONE)

docker-push: ## Pushes custom docker image to registry defined in image field of compose spec.
	@echo 'Pushing custom docker image'
	GIT_COMMIT_SHA1_SHORT=$(GIT_COMMIT_SHA1_SHORT) $(DOCKER_COMPOSE_CMD) push
	@$(DONE)

docker-up: ## Runs the custom docker image in the background.
	@echo 'Running custom docker image'
	GIT_COMMIT_SHA1_SHORT=$(GIT_COMMIT_SHA1_SHORT) $(DOCKER_COMPOSE_CMD) up --detach
	@$(DONE)

server-config-generator: ## Builds the server configuration generator tool.
	@echo 'Building server-config-generator tool'
	cd tools/server-config-generator && go build -o bin/server-config-generator main.go
	@$(DONE)

server-config-generator-docs: ## Builds the server configuration generator tool docs.
	@echo 'Building server-config-generator tool docs'
	cd tools/server-config-generator && go doc
	@$(DONE)

version: ## Output the current version.
	@echo $(VERSION)
