# This is a configuration for ci.lycus.org test runs.

export FLECT_ARCH       ?= ppc
export FLECT_OS         ?= linux
export FLECT_ABI        ?= ppc-ppc32
export FLECT_FPABI      ?= ppc-hardfp
export FLECT_ENDIAN     ?= big
export FLECT_CROSS      ?= false

export FLECT_CC         ?= clang
export FLECT_CC_TYPE    ?= gcc
export FLECT_CC_ARGS    ?=
export FLECT_LD         ?= ld
export FLECT_LD_TYPE    ?= ld
export FLECT_LD_ARGS    ?=

export FLECT_PREFIX     ?= /usr/local
export FLECT_BIN_DIR    ?= /usr/local/bin
export FLECT_LIB_DIR    ?= /usr/local/lib/flect
export FLECT_ST_LIB_DIR ?= /usr/local/lib/flect/static
export FLECT_SH_LIB_DIR ?= /usr/local/lib/flect/shared
