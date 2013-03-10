defmodule Flect.Compiler.Syntax.Preprocessor do
    @moduledoc """
    Contains the preprocessor which is used to filter the token stream
    produced from a Flect source code document based on various Boolean
    tests.
    """

    @typep state() :: {[Flect.Compiler.Syntax.Token.t()], [String.t()], [:if | :elif | :else], nil | boolean(), Flect.Compiler.Syntax.Location.t()}
    @typep return() :: {Flect.Compiler.Syntax.Node.t(), state()}

    @doc """
    Determine the set of predefined preprocessor identifiers based
    on the values in the `Flect.Target` module. Returns a list of
    binaries containing the identifier names.

    Possible C99 compiler identifiers (all mutually exclusive):

    * `"Flect_Compiler_GCC"`: The backing C99 compiler is GCC-compatible.

    Possible object code linker identifiers (all mutually exclusive):

    * `"Flect_Linker_LD"`: The backing object code linker is GNU LD-compatible.

    Possible target operating system identifiers (all mutually exclusive):

    * `"Flect_OS_None"`: The target OS is bare metal.
    * `"Flect_OS_AIX"`: The target OS is IBM's AIX.
    * `"Flect_OS_Android"`: The target OS is Android.
    * `"Flect_OS_Darwin"`: The target OS is Mac OS X.
    * `"Flect_OS_DragonFlyBSD"`: The target OS is DragonFlyBSD.
    * `"Flect_OS_FreeBSD"`: The target OS is FreeBSD.
    * `"Flect_OS_Hurd"`: The target OS is GNU Hurd.
    * `"Flect_OS_Haiku"`: The target OS is Haiku.
    * `"Flect_OS_IOS"`: The target OS is iOS.
    * `"Flect_OS_Linux"`: The target OS is Linux.
    * `"Flect_OS_OpenBSD"`: The target OS is OpenBSD.
    * `"Flect_OS_Solaris"`: The target OS is Solaris.
    * `"Flect_OS_Windows"`: The target OS is Windows.

    Possible target CPU identifiers (all mutually exclusive):

    * `"Flect_CPU_ARM"`: The target CPU is ARM.
    * `"Flect_CPU_Itanium"`: The target CPU is Itanium.
    * `"Flect_CPU_MIPS"`: The target CPU is MIPS.
    * `"Flect_CPU_PARISC"`: The target CPU is PA-RISC.
    * `"Flect_CPU_PowerPC"`: The target CPU is PowerPC.
    * `"Flect_CPU_X86"`: The target CPU is x86.

    Possible target application binary interface identifiers (all
    mutually exclusive):

    * `"Flect_ABI_ARM_Thumb"`: The Thumb instruction set on ARM.
    * `"Flect_ABI_ARM_Soft"`: The `soft` ABI on ARM.
    * `"Flect_ABI_ARM_SoftFP"`: The `softfp` ABI on ARM.
    * `"Flect_ABI_ARM_HardFP"`: The `hardfp` ABI on ARM.
    * `"Flect_ABI_ARM_AArch64"`: The AArch64 instruction set on ARM.
    * `"Flect_ABI_Itanium_PSABI"`: The Itanium processor-specific ABI.
    * `"Flect_ABI_MIPS_O32"`: The MIPS O32 ABI.
    * `"Flect_ABI_MIPS_N32"`: The MIPS N32 ABI.
    * `"Flect_ABI_MIPS_O64"`: The MIPS O64 ABI.
    * `"Flect_ABI_MIPS_N64"`: The MIPS N64 ABI.
    * `"Flect_ABI_MIPS_EABI32"`: The 32-bit MIPS EABI.
    * `"Flect_ABI_MIPS_EABI64"`: The 64-bit MIPS EABI.
    * `"Flect_ABI_PARISC_PA32"`: The 32-bit PA-RISC architecture.
    * `"Flect_ABI_PARISC_PA64"`: The 64-bit PA-RISC architecture.
    * `"Flect_ABI_PowerPC_SoftFP"`: The `softfp` ABI on PowerPC.
    * `"Flect_ABI_PowerPC_HardFP"`: The `hardfp` ABI on PowerPC.
    * `"Flect_ABI_PowerPC_PPC64"`: The 64-bit PowerPC architecture.
    * `"Flect_ABI_X86_Microsoft32"`: The 32-bit Microsoft ABI on x86.
    * `"Flect_ABI_X86_SystemV64"`: The 64-bit System V ABI on x86.
    * `"Flect_ABI_X86_Microsoft64"`: The 64-bit Microsoft ABI on x86.
    * `"Flect_ABI_X86_SystemV64"`: The 64-bit System V ABI on x64.
    * `"Flect_ABI_X86_X32"`: The x32 ABI on x86.

    Possible endianness identifiers (all mutually exclusive):

    * `"Flect_Endianness_Big"`: Byte order is big endian.
    * `"Flect_Endianness_Little"`: Byte order is little endian.

    Possible pointer size identifiers (all mutually exclusive):

    * `"Flect_PointerSize_32"`: Pointers are 32 bits wide.
    * `"Flect_PointerSize_64"`: Pointers are 64 bits wide.

    Possible word size identifiers (all mutually exclusive):

    * `"Flect_WordSize_32"`: Words are 32 bits wide.
    * `"Flect_WordSize_64"`: Words are 64 bits wide.

    Miscellaneous identifiers:

    * `"Flect_Cross"`: The Flect compiler is a cross compiler.
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

        endian = case Flect.Target.get_endian() do
            "big" -> "Big"
            "little" -> "Little"
        end

        cross = if Flect.Target.get_cross() == "true", do: ["Flect_Cross"], else: []

        ["Flect_Compiler_" <> cc,
         "Flect_Linker_" <> ld,
         "Flect_OS_" <> os,
         "Flect_CPU_" <> arch,
         "Flect_ABI_" <> abi,
         "Flect_Endianness_" <> endian,
         "Flect_PointerSize_" <> ptr_size,
         "Flect_WordSize_" <> word_size
         | cross]
    end

    @doc """
    Preprocesses the given token stream according to the specified
    preprocessor definitions. Returns the filtered token stream or
    raises a `Flect.Compiler.Syntax.SyntaxError` if a preprocessor
    directive is malformed.

    The `tokens` argument must be a list of `Flect.Compiler.Syntax.Token`
    instances (presumably obtained from lexing). The `defs` argument must
    be a list of binaries containing predefined identifiers (such as
    those provided via the `--define` command line option). The `file`
    argument must be a binary containing the file name (used to report
    syntax errors).
    """
    @spec preprocess([Flect.Compiler.Syntax.Token.t()], [String.t()], String.t()) :: [Flect.Compiler.Syntax.Token.t()]
    def preprocess(tokens, defs, file) do
        loc = if (t = Enum.first(tokens)) != nil, do: t.location(), else: Flect.Compiler.Syntax.Location.new(file: file)
        do_preprocess({tokens, defs, [], nil, loc})
    end

    @spec do_preprocess(state(), [Flect.Compiler.Syntax.Token.t()]) :: [Flect.Compiler.Syntax.Token.t()]
    defp do_preprocess(state, tokens // []) do
        case next_token(state, true) do
            {:directive, tok, state} ->
                {state, toks} = parse_directive(state, tok)
                do_preprocess(state, toks ++ tokens)
            {_, tok, state} -> do_preprocess(state, [tok | tokens])
            :eof -> Enum.reverse(tokens)
        end
    end

    @spec parse_directive(state(), Flect.Compiler.Syntax.Token.t()) :: {state(), [Flect.Compiler.Syntax.Token.t()]}
    defp parse_directive(state = {tokens, defs, stack, eval, loc}, token) do
        case token.value() do
            "\\if" ->
                stack = [:if | stack]

                {{tokens, defs, stack, nil, loc}, []} # TODO
            "\\elif" ->
                if stack == [] || !(hd(stack) in [:if, :elif]) do
                    raise_error(loc, "Unexpected \\elif directive encountered")
                end

                stack = [:elif | stack]

                {{tokens, defs, stack, nil, loc}, []} # TODO
            "\\else" ->
                if stack == [] || !(hd(stack) in [:if, :elif]) do
                    raise_error(loc, "Unexpected \\else directive encountered")
                end

                # We only push this to the stack so that there is at least
                # one item there for the check in the \endif code below.
                stack = [:else | stack]

                # If the last evaluation was true, this \else branch is
                # dead and we should skip all tokens until we hit \endif.
                {{tokens, defs, _, eval, loc}, toks} = if eval do
                    {state, _} = grab_tokens(state) # Discard the tokens.
                    {state, []}
                else
                    grab_tokens(state)
                end

                {{tokens, defs, stack, eval, loc}, toks}
            "\\endif" ->
                if stack == [] do
                    raise_error(loc, "Unexpected \\endif directive encountered")
                end

                # We don't actually need to check the head of the stack
                # because if anything at all is on the stack (checked
                # above), then \endif is valid.
                [_ | stack] = stack

                {{tokens, defs, stack, nil, loc}, []}
            "\\define" -> {state, tokens}
                {_, tok, {tokens, defs, stack, eval, loc}} = expect_token(state, :identifier, "definition name")

                if match?(<<"Flect_", _ :: binary()>>, tok.value()) do
                    raise_error(loc, "Definition names cannot start with 'Flect_'")
                end

                if List.member?(defs, tok.value()) do
                    raise_error(loc, "'#{tok.value()}' is already defined")
                end

                {{tokens, [tok.value() | defs], stack, eval, loc}, []}
            "\\undef" -> {state, tokens}
                {_, tok, {tokens, defs, stack, eval, loc}} = expect_token(state, :identifier, "definition name")

                if match?(<<"Flect_", _ :: binary()>>, tok.value()) do
                    raise_error(loc, "Cannot undefine definition names starting with 'Flect_'")
                end

                if !List.member?(defs, tok.value()) do
                    raise_error(loc, "'#{tok.value()}' is not defined")
                end

                {{tokens, List.delete(defs, tok.value()), stack, eval, loc}, []}
            "\\error" -> {state, tokens}
                {_, tok, _} = expect_token(state, :string, "error message string")
                raise_error(loc, "\\error: #{tok.value()}")
            dir -> raise_error(loc, "Unknown preprocessor directive: #{dir}")
        end
    end

    @spec grab_tokens(state(), [Flect.Compiler.Syntax.Token.t()]) :: {state(), [Flect.Compiler.Syntax.Token.t()]}
    defp grab_tokens(state, tokens // []) do
        case next_token(state) do
            {:directive, itok, istate} ->
                # These two are special cases. Since they don't actually
                # 'interrupt' the token section (as e.g. \elif and \error
                # would do), we need to process them and continue going.
                if itok.value() in ["\\define", "\\undef"] do
                    {istate, toks} = parse_directive(istate, itok)
                    grab_tokens(istate, toks ++ tokens)
                else
                    {state, Enum.reverse(tokens)}
                end
            {_, tok, state} -> grab_tokens(state, [tok | tokens])
        end
    end

    @spec next_token(state(), boolean()) :: {atom(), Flect.Compiler.Syntax.Token.t(), state()} | :eof
    defp next_token({tokens, defs, stack, eval, loc}, eof // false) do
        case tokens do
            [h | t] -> {h.type(), h, {t, defs, stack, eval, h.location()}}
            [] when eof -> :eof
            _ -> raise_error(loc, "Unexpected end of token stream")
        end
    end

    @spec expect_token(state(), atom() | [atom(), ...], String.t(), boolean()) :: {atom(), Flect.Compiler.Syntax.Token.t(), state()} | :eof
    defp expect_token(state, type, str, eof // false) do
        case next_token(state, eof) do
            tup = {t, tok, {_, _, _, _, l}} ->
                ok = cond do
                    is_list(type) -> List.member?(type, t)
                    is_atom(type) -> t == type
                end

                if !ok do
                    raise_error(l, "Expected #{str}, but got '#{tok.value()}'")
                end

                tup
            # We only get :eof if eof is true.
            :eof -> :eof
        end
    end

    @spec raise_error(Flect.Compiler.Syntax.Location.t(), String.t()) :: no_return()
    defp raise_error(loc, msg) do
        raise(Flect.Compiler.Syntax.SyntaxError[error: msg, location: loc])
    end
end
