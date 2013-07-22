IO.puts("This is the Flect configuration script.")
IO.puts("Some variables will have default values that are based on guesstimations about the current system.")
IO.puts("Simply leave a variable blank to use the default value or specify a different value if needed.")
IO.puts("Note that if the guesstimation leaves a variable blank, it must be filled out manually.")
IO.puts("Some variables (such as FLECT_CC_ARGS and FLECT_LD_ARGS) can be left empty.")
IO.puts("")

IO.puts("Press Enter to start configuring Flect.")
IO.read(:stdio, :line)

target = :unicode.characters_to_binary(:erlang.system_info(:system_architecture))

IO.puts("Guesstimated target triple is: #{target}")
IO.puts("")

re = fn(re) -> Regex.match?(re, target) end

{arch, os, abi, fpabi, endian} = cond do
    re.(%r/^arm-\w*-linux-gnueabi$/) -> {"arm", "linux", "arm-aapcs", "arm-soft", "little"}
    re.(%r/^arm-\w*-linux-gnueabihf$/) -> {"arm", "linux", "arm-aapcs", "arm-hardfp", "little"}
    re.(%r/^armv\dh\w-\w*-linux-gnu$/) -> {"arm", "linux", "arm-aapcs", "arm-hardfp", "little"}

    re.(%r/^powerpc-\w*-linux-gnu$/) -> {"ppc", "linux", "ppc-ppc64", "ppc-hardfp", "big"}

    re.(%r/^i\d86-\w*-linux-gnu$/) -> {"x86", "linux", "x86-sysv32", "x86-x87", "little"}
    re.(%r/^x86_64-\w*-linux-gnu$/) -> {"x86", "linux", "x86-sysv64", "x86-sse", "little"}

    re.(%r/^i\d86-\w*-darwin/) -> {"x86", "darwin", "x86-sysv32", "x86-x87", "little"}
    re.(%r/^x86_64-\w*-darwin/) -> {"x86", "darwin", "x86-sysv64", "x86-sse", "little"}

    true -> {"", "", "", "", ""}
end

IO.puts("Guesstimated values:")
IO.puts("")
IO.puts("    FLECT_ARCH       = #{arch}")
IO.puts("    FLECT_OS         = #{os}")
IO.puts("    FLECT_ABI        = #{abi}")
IO.puts("    FLECT_FPABI      = #{fpabi}")
IO.puts("    FLECT_ENDIAN     = #{endian}")
IO.puts("")

IO.puts("Guesstimation complete. Proceeding to compiler configuration.")
IO.puts("")

get = fn(var, def, empty) ->
    cond do
        (s = String.strip(IO.gets("Please enter a value for #{var} [#{def}]: "))) != "" -> s
        def != "" -> def
        empty -> ""
        true ->
            IO.puts("Error: No value for #{var} given.")
            System.halt(1)
    end
end

get_bool = fn(var, def) ->
    s = get.(var, def, false)

    if s in ["true", "false"] do
        s
    else
        IO.puts("Error: Value must be true or false.")
        System.halt(1)
    end
end

arch = get.("FLECT_ARCH", arch, false)
os = get.("FLECT_OS", os, false)
abi = get.("FLECT_ABI", abi, false)
fpabi = get.("FLECT_FPABI", fpabi, false)
endian = get.("FLECT_ENDIAN", endian, false)

unless os in ["none", "aix", "android", "darwin", "dragonflybsd", "freebsd", "haiku", "hpux", "hurd", "ios", "linux", "openbsd", "solaris", "windows"] do
    IO.puts("Error: Invalid operating system #{os} (FLECT_OS)")
    System.halt(1)
end

arch_valid = case os do
    "none" -> arch in ["arm", "ia64", "mips", "ppc", "x86"]
    "aix" -> arch in ["ppc"]
    "android" -> arch in ["arm", "mips", "x86"]
    "darwin" -> arch in ["ppc", "x86"]
    "dragonflybsd" -> arch in ["x86"]
    "freebsd" -> arch in ["arm", "ia64", "mips", "ppc", "x86"]
    "haiku" -> arch in ["x86"]
    "hpux" -> arch in ["ia64"]
    "hurd" -> arch in ["x86"]
    "ios" -> arch in ["arm"]
    "linux" -> arch in ["arm", "ia64", "mips", "ppc", "x86"]
    "openbsd" -> arch in ["arm", "mips", "ppc", "x86"]
    "solaris" -> arch in ["x86"]
    "windows" -> arch in ["ia64", "x86"]
end

unless arch_valid do
    IO.puts("Error: Invalid architecture #{arch} for operating system #{os} (FLECT_ARCH)")
    System.halt(1)
end

abi_valid = case arch do
    "arm" -> abi in ["arm-thumb", "arm-thumb2", "arm-aapcs", "arm-aarch64"]
    "ia64" -> abi in ["ia64-ilp32", "ia64-lp64"]
    "mips" -> abi in ["mips-o32", "mips-n32", "mips-o64", "mips-n64", "mips-eabi32", "mips-eabi64"]
    "ppc" -> abi in ["ppc-ppc32", "ppc-ppc64"]
    "x86" -> abi in ["x86-ms32", "x86-sysv32", "x86-ms64", "x86-sysv64", "x86-x32"]
end

unless abi_valid do
    IO.puts("Error: Invalid ABI #{abi} for architecture #{arch} (FLECT_ABI)")
    System.halt(1)
end

fpabi_valid = case arch do
    "arm" -> fpabi in ["arm-soft", "arm-softfp", "arm-hardfp"]
    "ia64" -> fpabi in ["ia64-hardfp"]
    "mips" -> fpabi in ["mips-softfp", "mips-hardfp"]
    "ppc" -> fpabi in ["ppc-softfp", "ppc-hardfp"]
    "x86" -> fpabi in ["x86-softfp", "x86-x87", "x86-sse"]
end

unless fpabi_valid do
    IO.puts("Error: Invalid floating point ABI #{fpabi} for architecture #{arch} (FLECT_FPABI)")
    System.halt(1)
end

endian_valid = case arch do
    "arm" -> endian in ["big", "little"]
    "ia64" -> endian in ["big", "little"]
    "mips" -> endian in ["big", "little"]
    "ppc" -> endian in ["big", "little"]
    "x86" -> endian in ["little"]
end

unless endian_valid do
    IO.puts("Error: Invalid endianness #{endian} for architecture #{arch} (FLECT_ENDIAN)")
    System.halt(1)
end

cross = get_bool.("FLECT_CROSS", "false")

IO.puts("")
IO.puts("Compiler configuration complete. Proceeding to external tool configuration.")
IO.puts("")

cc = get.("FLECT_CC", "clang", false)
cc_type = get.("FLECT_CC_TYPE", "gcc", false)

unless cc_type in ["gcc"] do
    IO.puts("Error: Invalid C99 compiler type #{cc_type} (FLECT_CC_TYPE)")
    System.halt(1)
end

cc_args = get.("FLECT_CC_ARGS", "", true)
ld = get.("FLECT_LD", "ld", false)
ld_type = get.("FLECT_LD_TYPE", "ld", false)

unless ld_type in ["ld"] do
    IO.puts("Error: Invalid linker type #{ld_type} (FLECT_LD_TYPE)")
    System.halt(1)
end

ld_args = get.("FLECT_LD_ARGS", "", true)

IO.puts("")
IO.puts("External tool configuration complete. Proceeding to directory hierarchy configuration.")
IO.puts("")

prefix = get.("FLECT_PREFIX", "/usr/local", false)
bin_dir = get.("FLECT_BIN_DIR", Path.join(prefix, "bin"), false)
lib_dir = get.("FLECT_LIB_DIR", Path.join([prefix, "lib", "flect"]), false)
st_lib_dir = get.("FLECT_ST_LIB_DIR", Path.join(lib_dir, "static"), false)
sh_lib_dir = get.("FLECT_SH_LIB_DIR", Path.join(lib_dir, "shared"), false)

IO.puts("")
IO.puts("Directory hierarchy configuration complete.")
IO.puts("")

IO.puts("Configuration:")
IO.puts("")
IO.puts("    FLECT_ARCH       = #{arch}")
IO.puts("    FLECT_OS         = #{os}")
IO.puts("    FLECT_ABI        = #{abi}")
IO.puts("    FLECT_FPABI      = #{fpabi}")
IO.puts("    FLECT_ENDIAN     = #{endian}")
IO.puts("    FLECT_CROSS      = #{cross}")
IO.puts("")
IO.puts("    FLECT_CC         = #{cc}")
IO.puts("    FLECT_CC_TYPE    = #{cc_type}")
IO.puts("    FLECT_CC_ARGS    = #{cc_args}")
IO.puts("    FLECT_LD         = #{ld}")
IO.puts("    FLECT_LD_TYPE    = #{ld_type}")
IO.puts("    FLECT_LD_ARGS    = #{ld_args}")
IO.puts("")
IO.puts("    FLECT_PREFIX     = #{prefix}")
IO.puts("    FLECT_BIN_DIR    = #{bin_dir}")
IO.puts("    FLECT_LIB_DIR    = #{lib_dir}")
IO.puts("    FLECT_ST_LIB_DIR = #{st_lib_dir}")
IO.puts("    FLECT_SH_LIB_DIR = #{sh_lib_dir}")
IO.puts("")

IO.puts("Press Enter to write the configuration.")
IO.read(:stdio, :line)

cfg = "# Generated by config.exs on #{inspect(:erlang.localtime())}.

export FLECT_ARCH       ?= #{arch}
export FLECT_OS         ?= #{os}
export FLECT_ABI        ?= #{abi}
export FLECT_FPABI      ?= #{fpabi}
export FLECT_ENDIAN     ?= #{endian}
export FLECT_CROSS      ?= #{cross}

export FLECT_CC         ?= #{cc}
export FLECT_CC_TYPE    ?= #{cc_type}
export FLECT_CC_ARGS    ?= #{cc_args}
export FLECT_LD         ?= #{ld}
export FLECT_LD_TYPE    ?= #{ld_type}
export FLECT_LD_ARGS    ?= #{ld_args}

export FLECT_PREFIX     ?= #{prefix}
export FLECT_BIN_DIR    ?= #{bin_dir}
export FLECT_LIB_DIR    ?= #{lib_dir}
export FLECT_ST_LIB_DIR ?= #{st_lib_dir}
export FLECT_SH_LIB_DIR ?= #{sh_lib_dir}"

File.write!("config.mak", cfg)

IO.puts("Done.")
System.halt(0)
