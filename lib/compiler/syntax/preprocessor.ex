defmodule Flect.Compiler.Syntax.Preprocessor do
    @doc """
    Determine the set of predefined preprocessor identifiers based
    on the values in the `Flect.Target` module.
    """
    @spec target_defines() :: [String.t()]
    def :target_defines, [], [] do
        cc = case Flect.Target.get_cc_type() do
            "gcc" -> "GCC"
        end

        ld = case Flect.Target.get_ld_type() do
            "ld" -> "LD"
        end

        os = case Flect.Target.get_os() do
            "none" -> "None"
            "aix" -> "AIX"
            "android" -> "Android"
            "darwin" -> "Darwin"
            "dragonflybsd" -> "DragonFlyBSD"
            "freebsd" -> "FreeBSD"
            "hurd" -> "Hurd"
            "haiku" -> "Haiku"
            "ios" -> "IOS"
            "linux" -> "Linux"
            "openbsd" -> "OpenBSD"
            "solaris" -> "Solaris"
            "windows" -> "Windows"
        end

        arch = case Flect.Target.get_arch() do
            "arm" -> "ARM"
            "ia64" -> "Itanium"
            "mips" -> "MIPS"
            "hppa" -> "PARISC"
            "ppc" -> "PowerPC"
            "x86" -> "X86"
        end

        {abi, ptr_size, word_size} = case Flect.Target.get_abi() do
            "arm-thumb" -> {"ARM_Thumb", "32", "32"}
            "arm-soft" -> {"ARM_Soft", "32", "32"}
            "arm-softfp" -> {"ARM_SoftFP", "32", "32"}
            "arm-hardfp" -> {"ARM_HardFP", "32", "32"}
            "arm-aarch64" -> {"ARM_AArch64", "64", "64"}
            "ia64-psabi" -> {"Itanium_PSABI", "64", "64"}
            "mips-o32" -> {"MIPS_O32", "32", "32"}
            "mips-n32" -> {"MIPS_N32", "32", "64"}
            "mips-o64" -> {"MIPS_O64", "64", "32"}
            "mips-n64" -> {"MIPS_N64", "64", "64"}
            "mips-eabi32" -> {"MIPS_EABI32", "32", "32"}
            "mips-eabi64" -> {"MIPS_EABI64", "64", "64"}
            "ppc-softfp" -> {"PowerPC_SoftFP", "32", "32"}
            "ppc-hardfp" -> {"PowerPC_HardFP", "32", "32"}
            "ppc-ppc64" -> {"PowerPC_PPC64", "64", "64"}
            "x86-ms32" -> {"X86_Microsoft32", "32", "32"}
            "x86-sysv32" -> {"X86_SystemV32", "32", "32"}
            "x86-ms64" -> {"X86_Microsoft64", "64", "64"}
            "x86-sysv64" -> {"X86_SystemV64", "64", "64"}
            "x86-x32" -> {"X86_X32", "32", "64"}
        end

        cross = if Flect.Target.get_cross() == "true", do: ["Flect_Cross"], else: []

        ["Flect_Compiler_" <> cc,
         "Flect_Linker_" <> ld,
         "Flect_OS_" <> os,
         "Flect_CPU_" <> arch,
         "Flect_ABI_" <> abi,
         "Flect_PointerSize_" <> ptr_size,
         "Flect_WordSize_" <> word_size
         | cross]
    end

    @spec preprocess([Flect.Compiler.Syntax.Token.t()], [String.t()], String.t()) :: {[Flect.Compiler.Syntax.Token.t()], [String.t()]}
    def preprocess(tokens, defs, file) do
        {tokens, defs}
    end
end
