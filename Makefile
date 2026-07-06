#!/usr/bin/env bash

# Makefile for char-rotate.nvim

.PHONY: all install check test

all: install test

install:
	@echo "Installing dependencies..."
	@luarocks install --local busted

test: install
	@echo "Running tests..."
	@busted --run unit

check: test
	@echo "All tests passed!"
