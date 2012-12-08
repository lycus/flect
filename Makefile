RM ?= rm
MIX ?= mix
DIALYZER ?= dialyzer

FLECT_CC ?= clang
FLECT_CC_TYPE ?= gcc
FLECT_OS ?= linux
FLECT_ENV ?= none
FLECT_ARCH ?= x86
FLECT_BITS ?= 64
FLECT_ABI ?= amd64

.PHONY: all escript ebin deps update clean test dialyze

all: escript

escript: ebin
	$(MIX) escriptize

ebin: deps
	$(MIX) do deps.compile, compile

deps:
	$(MIX) deps.get

update: deps
	$(MIX) deps.update

clean:
	$(MIX) clean --all
	$(RM) -f flect
	$(RM) -f *.dump

test: ebin
	$(MIX) test

dialyze: ebin
	$(DIALYZER) --no_check_plt -r ebin \
		-Wunmatched_returns \
		-Werror_handling \
		-Wrace_conditions
