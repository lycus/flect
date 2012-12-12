RM ?= rm
MIX ?= mix
DIALYZER ?= dialyzer

export FLECT_PREFIX ?= /usr/local
export FLECT_BIN_DIR ?= $(FLECT_PREFIX)/bin
export FLECT_INC_DIR ?= $(FLECT_PREFIX)/include/flect
export FLECT_LIB_DIR ?= $(FLECT_PREFIX)/lib/flect
export FLECT_ST_LIB_DIR ?= $(FLECT_LIB_DIR)/static
export FLECT_SH_LIB_DIR ?= $(FLECT_LIB_DIR)/shared

export FLECT_CC ?= clang
export FLECT_CC_TYPE ?= gcc
export FLECT_LD ?= ld
export FLECT_LD_TYPE ?= ld
export FLECT_OS ?= linux
export FLECT_ARCH ?= x86
export FLECT_ABI ?= x86-sysv64

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
