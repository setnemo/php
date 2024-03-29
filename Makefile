SHELL := $(shell which bash)
.SHELLFLAGS = -c

ARGS = $(filter-out $@,$(MAKECMDGOALS))

.SILENT: ;               # no need for @
.ONESHELL: ;             # recipes execute in same shell
.NOTPARALLEL: ;          # wait for this target to finish
.EXPORT_ALL_VARIABLES: ; # send all vars to shell
Makefile: ;              # skip prerequisite discovery
.DEFAULT_GOAL := default

.PHONY: build-and-push
build-and-push:
	docker build . --no-cache --cpuset-cpus="0-3" -t=ghcr.io/setnemo/php:latest && docker push ghcr.io/setnemo/php:latest

.PHONY: default
default: build-and-push

%:
	@:
