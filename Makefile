RM ?= rm
MIX ?= mix
DIALYZER ?= dialyzer

export FLECT_CC ?= clang
export FLECT_CC_TYPE ?= gcc
export FLECT_OS ?= linux
export FLECT_ENV ?= none
export FLECT_ARCH ?= x86
export FLECT_BITS ?= 64
export FLECT_ABI ?= amd64

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
