# Maintainer: Chris Molozian <chris@cmoz.me>

require 'formula'

class Flect < Formula
  homepage 'https://github.com/lycus/flect'
  head 'https://github.com/lycus/flect.git', :revision => 'HEAD'

  depends_on 'elixir' => :build
  depends_on 'erlang'

  def install
    pwd    = Dir.getwd
    abi    = 'x86-sysv32'
    fpabi  = 'x86-x87'
    ccargs = '-m32'

    if MacOS.prefer_64_bit?
      abi    = 'x86-sysv64'
      fpabi  = 'x86-sse'
      ccargs = ''
    end

    ohai 'Configuring the build...'
    (pwd + 'config.mak').write <<-EOF.undent
      export FLECT_ARCH       ?= x86
      export FLECT_OS         ?= darwin
      export FLECT_ABI        ?= #{abi}
      export FLECT_FPABI      ?= #{fpabi}
      export FLECT_CROSS      ?= false

      export FLECT_CC         ?= clang
      export FLECT_CC_TYPE    ?= gcc
      export FLECT_CC_ARGS    ?= #{ccargs}
      export FLECT_LD         ?= ld
      export FLECT_LD_TYPE    ?= ld
      export FLECT_LD_ARGS    ?=

      export FLECT_PREFIX     ?= #{prefix}
      export FLECT_BIN_DIR    ?= #{bin}
      export FLECT_LIB_DIR    ?= #{lib}/flect
      export FLECT_ST_LIB_DIR ?= #{lib}/flect/static
      export FLECT_SH_LIB_DIR ?= #{lib}/flect/shared
    EOF

    ohai 'Building and installing...'
    system "make", "install"
  end

  test do
    ohai 'Running test suite...'
    system "make", "test", "-j", "1"
  end
end
