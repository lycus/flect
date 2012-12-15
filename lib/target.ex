defmodule Flect.Target do
    def :get_prefix, [], [] do
        System.get_env("FLECT_PREFIX")
    end

    def :get_bin_dir, [], [] do
        System.get_env("FLECT_BIN_DIR")
    end

    def :get_lib_dir, [], [] do
        System.get_env("FLECT_LIB_DIR")
    end

    def :get_st_lib_dir, [], [] do
        System.get_env("FLECT_ST_LIB_DIR")
    end

    def :get_sh_lib_dir, [], [] do
        System.get_env("FLECT_SH_LIB_DIR")
    end

    def :get_cc, [], [] do
        System.get_env("FLECT_CC")
    end

    def :get_cc_type, [], [] do
        System.get_env("FLECT_CC_TYPE")
    end

    def :get_ld, [], [] do
        System.get_env("FLECT_LD")
    end

    def :get_ld_type, [], [] do
        System.get_env("FLECT_LD_TYPE")
    end

    def :get_os, [], [] do
        System.get_env("FLECT_OS")
    end

    def :get_arch, [], [] do
        System.get_env("FLECT_ARCH")
    end

    def :get_abi, [], [] do
        System.get_env("FLECT_ABI")
    end

    def :get_obj_ext, [], [] do
        if System.get_env("FLECT_CC_TYPE") == "msvc", do: ".obj", else: ".o"
    end
end

unless (cc_type = Flect.Target.get_cc_type()) in ["gcc",
                                                  "msvc"] do
    raise(Flect.TargetError, [error: "Invalid C compiler type #{cc_type} (FLECT_CC_TYPE)"])
end

unless (ld_type = Flect.Target.get_ld_type()) in ["ld",
                                                  "msvc"] do
    raise(Flect.TargetError, [error: "Invalid linker type #{ld_type} (FLECT_LD_TYPE)"])
end

unless (os = Flect.Target.get_os()) in ["none",
                                        "aix",
                                        "android",
                                        "dragonflybsd",
                                        "freebsd",
                                        "hurd",
                                        "haiku",
                                        "ios",
                                        "linux",
                                        "darwin",
                                        "openbsd",
                                        "solaris",
                                        "windows"] do
    raise(Flect.TargetError, [error: "Invalid operating system #{os} (FLECT_OS)"])
end

arch = Flect.Target.get_arch()

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
    "solaris" -> arch in ["ppc", "x86"]
    "windows" -> arch in ["ia64", "x86"]
end

unless arch_valid do
    raise(Flect.TargetError, [error: "Invalid architecture #{arch} for operating system #{os} (FLECT_ARCH)"])
end

abi = Flect.Target.get_abi()

abi_valid = case arch do
    "arm" -> abi in ["arm-thumb", "arm-soft", "arm-softfp", "arm-hardfp"]
    "ia64" -> abi in ["ia64-psabi"]
    "mips" -> abi in ["mips-o32", "mips-n32", "mips-o64", "mips-n64"]
    "hppa" -> abi in ["hppa-pa32", "hppa-pa64"]
    "ppc" -> abi in ["ppc-softfp", "ppc-hardfp", "ppc-ppc64"]
    "x86" -> abi in ["x86-ms32", "x86-sysv32", "x86-ms64", "x86-sysv64", "x86-x32"]
end

unless abi_valid do
    raise(Flect.TargetError, [error: "Invalid ABI #{abi} for architecture #{arch} (FLECT_ABI)"])
end

