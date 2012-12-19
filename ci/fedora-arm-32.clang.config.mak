# This is a configuration for Travis test runs.

export FLECT_ARCH       ?= arm
export FLECT_OS         ?= linux
export FLECT_ABI        ?= arm-hardfp

export FLECT_CC         ?= clang
export FLECT_CC_TYPE    ?= gcc
export FLECT_CC_ARGS    ?=
export FLECT_LD         ?= ld
export FLECT_LD_TYPE    ?= ld
export FLECT_LD_ARGS    ?=

export FLECT_PREFIX     ?= /usr/local
export FLECT_BIN_DIR    ?= /usr/local/bin
export FLECT_LIB_DIR    ?= /usr/local/lib
export FLECT_ST_LIB_DIR ?= /usr/local/lib/static
export FLECT_SH_LIB_DIR ?= /usr/local/lib/shared
