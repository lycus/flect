IO.puts("This is the Flect configuration script.")
IO.puts("Some variables will have default values that are based on guesstimations about the current system.")
IO.puts("Simply leave a variable blank to use the default value or specify a different value if needed.")
IO.puts("Note that if the guesstimation leaves a variable blank, it must be filled out manually.")
IO.puts("Some variables (such as FLECT_CC_ARGS and FLECT_LD_ARGS) can be left empty.")
IO.puts("")

IO.puts("Press Enter to start configuring Flect.")
IO.readline()

target = list_to_binary(:erlang.system_info(:system_architecture))

IO.puts("Guesstimated target triple is: #{target}")
IO.puts("")

re = fn(re) -> Regex.match?(re, target) end

{arch, os, abi, endian} = cond do
    re.(%r/^i\d86-\w*-linux-gnu$/) -> {"x86", "linux", "x86-sysv32", "little"}
    re.(%r/^x86_64-\w*-linux-gnu$/) -> {"x86", "linux", "x86-sysv64", "little"}
    re.(%r/^i\d86-\w*-darwin/) -> {"x86", "darwin", "x86-sysv32", "little"}
    re.(%r/^x86_64-\w*-darwin/) -> {"x86", "darwin", "x86-sysv64", "little"}

    re.(%r/^arm-\w*-linux-gnueabi$/) -> {"arm", "linux", "arm-softfp", "little")
    re.(%r/^armv\dh\w-\w*-linux-gnu$/) -> {"arm", "linux", "arm-hardfp", "little"}

    true -> {"", "", "", "little"}
end

IO.puts("Guesstimated values:")
IO.puts("")
IO.puts("    FLECT_ARCH       = #{arch}")
IO.puts("    FLECT_OS         = #{os}")
IO.puts("    FLECT_ABI        = #{abi}")
IO.puts("    FLECT_ENDIAN     = #{endian}")
IO.puts("")

IO.puts("Guesstimation complete. Proceeding to compiler configuration.")
IO.puts("")

get = fn(var, def, empty) ->
    cond do
        (s = String.strip(list_to_binary(IO.gets("Please enter a value for #{var} [#{def}]: ")))) != "" -> s
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
endian = get.("FLECT_ENDIAN", endian, false)

unless os in ["none", "aix", "android", "darwin", "dragonflybsd", "freebsd", "hurd", "haiku", "ios", "linux", "openbsd", "solaris", "windows"] do
    IO.puts("Error: Invalid operating system #{os} (FLECT_OS)")
    System.halt(1)
end

arch_valid = case os do
    "none" -> arch in ["arm", "ia64", "mips", "hppa", "ppc", "x86"]
    "aix" -> arch in ["ppc"]
    "android" -> arch in ["arm", "mips", "x86"]
    "dragonflybsd" -> arch in ["x86"]
    "freebsd" -> arch in ["arm", "ia64", "mips", "ppc", "x86"]
    "hurd" -> arch in ["x86"]
    "haiku" -> arch in ["x86"]
    "ios" -> arch in ["arm"]
    "linux" -> arch in ["arm", "ia64", "mips", "hppa", "ppc", "x86"]
    "darwin" -> arch in ["ppc", "x86"]
    "openbsd" -> arch in ["arm", "mips", "hppa", "ppc", "x86"]
    "solaris" -> arch in ["x86"]
    "windows" -> arch in ["ia64", "x86"]
end

unless arch_valid do
    IO.puts("Error: Invalid architecture #{arch} for operating system #{os} (FLECT_ARCH)")
    System.halt(1)
end

abi_valid = case arch do
    "arm" -> abi in ["arm-thumb", "arm-soft", "arm-softfp", "arm-hardfp", "arm-aarch64"]
    "ia64" -> abi in ["ia64-psabi"]
    "mips" -> abi in ["mips-o32", "mips-n32", "mips-o64", "mips-n64", "mips-eabi32", "mips-eabi64"]
    "hppa" -> abi in ["hppa-pa32", "hppa-pa64"]
    "ppc" -> abi in ["ppc-softfp", "ppc-hardfp", "ppc-ppc64"]
    "x86" -> abi in ["x86-ms32", "x86-sysv32", "x86-ms64", "x86-sysv64", "x86-x32"]
end

unless abi_valid do
    IO.puts("Error: Invalid ABI #{abi} for architecture #{arch} (FLECT_ABI)")
    System.halt(1)
end

endian_valid = case arch do
    "arm" -> endian in ["big", "little"]
    "ia64" -> endian in ["big", "little"]
    "mips" -> endian in ["big", "little"]
    "hppa" -> endian in ["big"]
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
IO.readline()

cfg = "# Generated by config.exs on #{inspect(:erlang.localtime())}.

export FLECT_ARCH       ?= #{arch}
export FLECT_OS         ?= #{os}
export FLECT_ABI        ?= #{abi}
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
