# This is a configuration for ci.lycus.org test runs.

export FLECT_ARCH       ?= mips
export FLECT_OS         ?= linux
export FLECT_ABI        ?= mips-n32
export FLECT_FPABI      ?= mips-hardfp
export FLECT_ENDIAN     ?= little
export FLECT_CROSS      ?= false

export FLECT_CC         ?= gcc
export FLECT_CC_TYPE    ?= gcc
export FLECT_CC_ARGS    ?= -mabi=n32
export FLECT_LD         ?= ld
export FLECT_LD_TYPE    ?= ld
export FLECT_LD_ARGS    ?=

export FLECT_PREFIX     ?= /usr/local
export FLECT_BIN_DIR    ?= /usr/local/bin
export FLECT_LIB_DIR    ?= /usr/local/lib/flect
export FLECT_ST_LIB_DIR ?= /usr/local/lib/flect/static
export FLECT_SH_LIB_DIR ?= /usr/local/lib/flect/shared
