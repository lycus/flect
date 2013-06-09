defmodule Flect.Compiler.Syntax.Preprocessor do
    @moduledoc """
    Contains the preprocessor which is used to filter the token stream
    produced from a Flect source code document based on various Boolean
    tests.
    """

    @typep location() :: Flect.Compiler.Syntax.Location.t()
    @typep token() :: Flect.Compiler.Syntax.Token.t()
    @typep ast_node() :: Flect.Compiler.Syntax.Node.t()
    @typep state() :: {[token()], location()}
    @typep pp_define() :: {String.t(), location() | nil}
    @typep return_n() :: {ast_node(), state()}

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
    * `"Flect_OS_Haiku"`: The target OS is Haiku.
    * `"Flect_OS_HP_UX"`: The target OS is Haiku.
    * `"Flect_OS_Hurd"`: The target OS is GNU Hurd.
    * `"Flect_OS_IOS"`: The target OS is iOS.
    * `"Flect_OS_Linux"`: The target OS is Linux.
    * `"Flect_OS_OpenBSD"`: The target OS is OpenBSD.
    * `"Flect_OS_Solaris"`: The target OS is Solaris.
    * `"Flect_OS_Windows"`: The target OS is Windows.

    Possible target CPU identifiers (all mutually exclusive):

    * `"Flect_CPU_ARM"`: The target CPU is ARM.
    * `"Flect_CPU_Itanium"`: The target CPU is Itanium.
    * `"Flect_CPU_MIPS"`: The target CPU is MIPS.
    * `"Flect_CPU_PowerPC"`: The target CPU is PowerPC.
    * `"Flect_CPU_X86"`: The target CPU is x86.

    Possible target application binary interface identifiers (all
    mutually exclusive):

    * `"Flect_ABI_ARM_Thumb"`: The Thumb instruction set on ARM.
    * `"Flect_ABI_ARM_Thumb2"`: The Thumb 2 instruction set on ARM.
    * `"Flect_ABI_ARM_AAPCS"`: The AAPCS on ARM.
    * `"Flect_ABI_ARM_AArch64"`: The AArch64 instruction set on ARM.
    * `"Flect_ABI_Itanium_ILP32"`: The Itanium 32-bit ABI.
    * `"Flect_ABI_Itanium_LP64"`: The Itanium 64-bit ABI.
    * `"Flect_ABI_MIPS_O32"`: The MIPS O32 ABI.
    * `"Flect_ABI_MIPS_N32"`: The MIPS N32 ABI.
    * `"Flect_ABI_MIPS_O64"`: The MIPS O64 ABI.
    * `"Flect_ABI_MIPS_N64"`: The MIPS N64 ABI.
    * `"Flect_ABI_MIPS_EABI32"`: The 32-bit MIPS EABI.
    * `"Flect_ABI_MIPS_EABI64"`: The 64-bit MIPS EABI.
    * `"Flect_ABI_PowerPC_PPC32"`: The 32-bit PowerPC architecture.
    * `"Flect_ABI_PowerPC_PPC64"`: The 64-bit PowerPC architecture.
    * `"Flect_ABI_X86_Microsoft32"`: The 32-bit Microsoft ABI on x86.
    * `"Flect_ABI_X86_SystemV32"`: The 32-bit System V ABI on x86.
    * `"Flect_ABI_X86_Microsoft64"`: The 64-bit Microsoft ABI on x86.
    * `"Flect_ABI_X86_SystemV64"`: The 64-bit System V ABI on x64.
    * `"Flect_ABI_X86_X32"`: The x32 ABI on x86.

    Possible target floating point application binary interface
    identifiers (all mutually exclusive):

    * `"Flect_FPABI_ARM_Soft"`: Software floating point on ARM.
    * `"Flect_FPABI_ARM_SoftFP"`: VFP with software conventions on ARM.
    * `"Flect_FPABI_ARM_HardFP"`: VFP with hardware conventions on ARM.
    * `"Flect_FPABI_Itanium_SoftFP"`: Software floating point on Itanium.
    * `"Flect_FPABI_Itanium_HardFP"`: Hardware floating point on Itanium.
    * `"Flect_FPABI_MIPS_SoftFP"`: Software floating point on MIPS.
    * `"Flect_FPABI_MIPS_HardFP"`: Hardware floating point on MIPS.
    * `"Flect_FPABI_PowerPC_SoftFP"`: Software floating point on PowerPC.
    * `"Flect_FPABI_PowerPC_HardFP"`: Hardware floating point on PowerPC.
    * `"Flect_FPABI_X86_SoftFP"`: Software floating point on x86.
    * `"Flect_FPABI_X86_X87"`: x87 FPU on x86.
    * `"Flect_FPABI_X86_SSE"`: Streaming SIMD Extensions on x86.

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
            "haiku" -> "Haiku"
            "hpux" -> "HP_UX"
            "hurd" -> "Hurd"
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
            "ppc" -> "PowerPC"
            "x86" -> "X86"
        end

        {abi, ptr_size, word_size} = case Flect.Target.get_abi() do
            "arm-thumb" -> {"ARM_Thumb", "32", "32"}
            "arm-thumb2" -> {"ARM_Thumb2", "32", "32"}
            "arm-aapcs" -> {"ARM_AAPCS", "32", "32"}
            "arm-aarch64" -> {"ARM_AArch64", "64", "64"}
            "ia64-ilp32" -> {"Itanium_ILP64", "32", "32"}
            "ia64-lp64" -> {"Itanium_LP64", "64", "64"}
            "mips-o32" -> {"MIPS_O32", "32", "32"}
            "mips-n32" -> {"MIPS_N32", "32", "64"}
            "mips-o64" -> {"MIPS_O64", "64", "32"}
            "mips-n64" -> {"MIPS_N64", "64", "64"}
            "mips-eabi32" -> {"MIPS_EABI32", "32", "32"}
            "mips-eabi64" -> {"MIPS_EABI64", "64", "64"}
            "ppc-ppc32" -> {"PowerPC_PPC32", "32", "32"}
            "ppc-ppc64" -> {"PowerPC_PPC64", "64", "64"}
            "x86-ms32" -> {"X86_Microsoft32", "32", "32"}
            "x86-sysv32" -> {"X86_SystemV32", "32", "32"}
            "x86-ms64" -> {"X86_Microsoft64", "64", "64"}
            "x86-sysv64" -> {"X86_SystemV64", "64", "64"}
            "x86-x32" -> {"X86_X32", "32", "64"}
        end

        fpabi = case Flect.Target.get_fpabi() do
            "arm-soft" -> "ARM_Soft"
            "arm-softfp" -> "ARM_SoftFP"
            "arm-hardfp" -> "ARM_HardFP"
            "ia64-softfp" -> "Itanium_SoftFP"
            "ia64-hardfp" -> "Itanium_HardFP"
            "mips-softfp" -> "MIPS_SoftFP"
            "mips-hardfp" -> "MIPS_HardFP"
            "ppc-softfp" -> "PowerPC_SoftFP"
            "ppc-hardfp" -> "PowerPC_HardFP"
            "x86-softfp" -> "X86_SoftFP"
            "x86-x87" -> "X86_X87"
            "x86-sse" -> "X86_SSE"
        end

        endian = case Flect.Target.get_endian() do
            "big" -> "Big"
            "little" -> "Little"
        end

        cross = if Flect.Target.get_cross() == "true", do: ["Flect_Cross"], else: []

        ["Flect_Compiler_#{cc}",
         "Flect_Linker_#{ld}",
         "Flect_OS_#{os}",
         "Flect_CPU_#{arch}",
         "Flect_ABI_#{abi}",
         "Flect_FPABI_#{fpabi}",
         "Flect_Endianness_#{endian}",
         "Flect_PointerSize_#{ptr_size}",
         "Flect_WordSize_#{word_size}"
         | cross]
    end

    @doc """
    Preprocesses the given token stream according to the specified
    preprocessor definitions. Returns the filtered token stream.
    Raises a `Flect.Compiler.Syntax.SyntaxError` if a preprocessor
    directive is malformed, or a `Flect.Compiler.Syntax.PreprocessorError`
    if a preprocessor directive is semantically invalid.

    The `tokens` argument must be a list of `Flect.Compiler.Syntax.Token`
    instances (presumably obtained from lexing). The `defs` argument must
    be a list of binaries containing predefined identifiers (such as
    those provided via the `--define` command line option). The `file`
    argument must be a binary containing the file name (used to report
    syntax errors).
    """
    @spec preprocess([Flect.Compiler.Syntax.Token.t()], [String.t()], String.t()) :: [Flect.Compiler.Syntax.Token.t()]
    def preprocess(tokens, defs, file) do
        loc = if t = Enum.first(tokens), do: t.location(), else: Flect.Compiler.Syntax.Location[file: file]
        {section, _} = parse_section_stmt({tokens, loc})

        {nodes, _} = evaluate_section(section, lc defn inlist defs, do: {defn, nil})
        lc node inlist nodes, do: node.tokens()[:token]
    end

    @spec evaluate_section(ast_node(), [pp_define()]) :: {[token()], [pp_define()]}
    defp evaluate_section(section, defs) do
        {toks, defs} = Enum.map_reduce(section.children(), defs, fn({type, child}, defs) ->
            if type in [:if, :define, :undef, :error] do
                evaluate_directive(child, defs)
            else
                {child, defs}
            end
        end)

        {List.flatten(toks), defs}
    end

    @spec evaluate_directive(ast_node(), [pp_define()]) :: {[token()], [pp_define()]}
    defp evaluate_directive(directive, defs) do
        case directive.type() do
            :if_stmt ->
                if evaluate_expr(directive.children()[:expression], defs) do
                    evaluate_section(directive.children()[:section], defs)
                else
                    elif_stmt = directive.children() |>
                                Enum.filter(fn({type, _}) -> type == :elif end) |>
                                Enum.map(fn({_, child}) -> child end) |>
                                Enum.find(fn(child) -> evaluate_expr(child.children()[:expression], defs) end)

                    cond do
                        elif_stmt != nil -> evaluate_section(elif_stmt.children()[:section], defs)
                        (else_stmt = directive.children()[:else]) != nil -> evaluate_section(else_stmt.children()[:section], defs)
                        true -> {[], defs}
                    end
                end
            :define_stmt ->
                ident = directive.tokens()[:identifier]

                case Enum.find(defs, fn({defn, _}) -> defn == ident.value() end) do
                    nil -> {[], [{ident.value(), ident.location()} | defs]}
                    {_, loc} ->
                        note = if loc, do: [{"Previously defined here", loc}], else: []

                        raise_sema_error(ident.location(), "'#{ident.value()}' is already defined", note)
                end
            :undef_stmt ->
                ident = directive.tokens()[:identifier]

                case Enum.find(defs, fn({defn, _}) -> defn == ident.value() end) do
                    nil -> raise_sema_error(ident.location(), "'#{ident.value()}' is not defined", [])
                    tup -> {[], List.delete(defs, tup)}
                end
            :error_stmt ->
                str = Flect.String.expand_escapes(Flect.String.strip_quotes(directive.tokens()[:string].value()), :string)
                raise_sema_error(directive.location(), "\\error: #{if String.printable?(str), do: str, else: "<non-printable string>"}", [])
        end
    end

    @spec evaluate_expr(ast_node(), [pp_define()]) :: boolean()
    defp evaluate_expr(expr, defs) do
        case expr.type() do
            :parenthesized_expr -> evaluate_expr(expr.children()[:expression], defs)
            :identifier_expr -> Enum.any?(defs, fn({defn, _}) -> defn == expr.tokens()[:identifier].value() end)
            :false_expr -> false
            :true_expr -> true
            :unary_expr -> !evaluate_expr(expr.children()[:expression], defs)
            :and_and_expr -> evaluate_expr(expr.children()[:left_expression], defs) && evaluate_expr(expr.children()[:right_expression], defs)
            :or_or_expr -> evaluate_expr(expr.children()[:left_expression], defs) || evaluate_expr(expr.children()[:right_expression], defs)
        end
    end

    @spec parse_section_stmt(state(), [String.t()], [{atom(), ast_node()}]) :: return_n()
    defp parse_section_stmt(state = {_, loc}, terms // [], nodes // []) do
        case next_token(state, terms == []) do
            {:directive, t, _} ->
                case t.value() do
                    "\\if" ->
                        {node, state} = parse_if_stmt(state)
                        parse_section_stmt(state, terms, [{:if, node} | nodes])
                    "\\define" ->
                        {node, state} = parse_define_stmt(state)
                        parse_section_stmt(state, terms, [{:define, node} | nodes])
                    "\\undef" ->
                        {node, state} = parse_undef_stmt(state)
                        parse_section_stmt(state, terms, [{:undef, node} | nodes])
                    "\\error" ->
                        {node, state} = parse_error_stmt(state)
                        parse_section_stmt(state, terms, [{:error, node} | nodes])
                    v ->
                        cond do
                            Enum.member?(terms, v) -> {new_node(:section_stmt, loc, [], Enum.reverse(nodes)), state}
                            v in ["\\else", "\\elif", "\\endif"] -> raise_error(t.location(), "Unexpected #{v} directive")
                            true -> raise_error(t.location(), "Unknown preprocessor directive: '#{v}'")
                        end
                end
            {_, _, _} ->
                {node, state} = parse_token_stmt(state)
                parse_section_stmt(state, terms, [{:token, node} | nodes])
            :eof -> {new_node(:section_stmt, loc, [], Enum.reverse(nodes)), state}
        end
    end

    @spec parse_token_stmt(state()) :: return_n()
    defp parse_token_stmt(state) do
        {_, tok, state} = expect_token(state, nil, "any token")
        {new_node(:token_stmt, tok.location(), [token: tok]), state}
    end

    @spec parse_if_stmt(state()) :: return_n()
    defp parse_if_stmt(state) do
        {_, tok_if, state} = expect_token(state, :directive, "\\if directive")
        {expr, state} = parse_expr(state)
        {section, state} = parse_section_stmt(state, ["\\elif", "\\else", "\\endif"])
        {alts, state} = parse_elif_else_stmts(state)
        {_, tok_endif, state} = expect_token(state, :directive, "\\endif directive")

        {new_node(:if_stmt, tok_if.location(), [if: tok_if, endif: tok_endif], [expression: expr, section: section] ++ alts), state}
    end

    @spec parse_elif_else_stmts(state(), [{atom(), ast_node()}]) :: {[{atom(), ast_node()}], state()}
    defp parse_elif_else_stmts(state, nodes // []) do
        case expect_token(state, :directive, "\\else, \\elif, or \\endif directive") do
            {_, tok, _} ->
                case tok.value() do
                    "\\elif" ->
                        {node, state} = parse_elif_stmt(state)
                        parse_elif_else_stmts(state, [{:elif, node} | nodes])
                    "\\else" ->
                        {node, state} = parse_else_stmt(state)
                        parse_elif_else_stmts(state, [{:else, node} | nodes])
                    "\\endif" -> {Enum.reverse(nodes), state}
                end
        end
    end

    @spec parse_elif_stmt(state()) :: return_n()
    defp parse_elif_stmt(state) do
        {_, tok_elif, state} = expect_token(state, :directive, "\\elif directive")
        {expr, state} = parse_expr(state)
        {section, state} = parse_section_stmt(state, ["\\elif", "\\else", "\\endif"])

        {new_node(:elif_stmt, tok_elif.location(), [elif: tok_elif], [expression: expr, section: section]), state}
    end

    @spec parse_else_stmt(state()) :: return_n()
    defp parse_else_stmt(state) do
        {_, tok_else, state} = expect_token(state, :directive, "\\else directive")
        {section, state} = parse_section_stmt(state, ["\\endif"])

        {new_node(:else_stmt, tok_else.location(), [else: tok_else], [section: section]), state}
    end

    @spec parse_define_stmt(state()) :: return_n()
    defp parse_define_stmt(state) do
        {_, tok_define, state} = expect_token(state, :directive, "\\define directive")
        {_, tok_ident, state} = expect_token(state, :identifier, "definition identifier")

        if match?(<<"Flect_", _ :: binary()>>, tok_ident.value()) do
            raise_error(tok_ident.location(), "Definition identifiers cannot start with 'Flect_'")
        end

        {new_node(:define_stmt, tok_define.location(), [define: tok_define, identifier: tok_ident]), state}
    end

    @spec parse_undef_stmt(state()) :: return_n()
    defp parse_undef_stmt(state) do
        {_, tok_undef, state} = expect_token(state, :directive, "\\undef directive")
        {_, tok_ident, state} = expect_token(state, :identifier, "definition identifier")

        if match?(<<"Flect_", _ :: binary()>>, tok_ident.value()) do
            raise_error(tok_ident.location(), "Definition identifiers cannot start with 'Flect_'")
        end

        {new_node(:undef_stmt, tok_undef.location(), [undef: tok_undef, identifier: tok_ident]), state}
    end

    @spec parse_error_stmt(state()) :: return_n()
    defp parse_error_stmt(state) do
        {_, tok_error, state} = expect_token(state, :directive, "\\error directive")
        {_, tok_str, state} = expect_token(state, :string, "error string")

        {new_node(:error_stmt, tok_error.location(), [error: tok_error, string: tok_str]), state}
    end

    @spec parse_expr(state()) :: return_n()
    defp parse_expr(state) do
        parse_or_or_expr(state)
    end

    @spec parse_or_or_expr(state()) :: return_n()
    defp parse_or_or_expr(state) do
        tup = {and_and_expr, state} = parse_and_and_expr(state)

        case next_token(state) do
            {:pipe_pipe, tok, state} ->
                {expr, state} = parse_and_and_expr(state)
                {new_node(:or_or_expr, tok.location(), [logical_or: tok], [left_expression: and_and_expr, right_expression: expr]), state}
            _ -> tup
        end
    end

    @spec parse_and_and_expr(state()) :: return_n()
    defp parse_and_and_expr(state) do
        tup = {unary_expr, state} = parse_unary_expr(state)

        case next_token(state) do
            {:ampersand_ampersand, tok, state} ->
                {expr, state} = parse_unary_expr(state)
                {new_node(:and_and_expr, tok.location(), [logical_and: tok], [left_expression: unary_expr, right_expression: expr]), state}
            _ -> tup
        end
    end

    @spec parse_unary_expr(state()) :: return_n()
    defp parse_unary_expr(state) do
        case next_token(state) do
            {:exclamation, tok, state} ->
                {expr, state} = parse_unary_expr(state)
                {new_node(:unary_expr, tok.location(), [logical_not: tok], [expression: expr]), state}
            _ -> parse_primary_expr(state)
        end
    end

    @spec parse_primary_expr(state()) :: return_n()
    defp parse_primary_expr(state) do
        case next_token(state) do
            {:true, tok, state} -> {new_node(:true_expr, tok.location(), [value: tok]), state}
            {:false, tok, state} -> {new_node(:false_expr, tok.location(), [value: tok]), state}
            {:identifier, tok, state} -> {new_node(:identifier_expr, tok.location(), [identifier: tok]), state}
            {:paren_open, _, _} -> parse_parenthesized_expr(state)
            {_, tok, _} -> raise_error(tok.location(), "Expected primary preprocessor expression")
        end
    end

    @spec parse_parenthesized_expr(state()) :: return_n()
    defp parse_parenthesized_expr(state) do
        {_, tok_open, state} = expect_token(state, :paren_open, "opening parenthesis")
        {expr, state} = parse_expr(state)
        {_, tok_close, state} = expect_token(state, :paren_close, "closing parenthesis")
        {new_node(:parenthesized_expr, tok_open.location(), [open_paren: tok_open, close_paren: tok_close], [expression: expr]), state}
    end

    @spec next_token(state(), boolean()) :: {atom(), token(), state()} | :eof
    defp next_token({tokens, loc}, eof // false) do
        case tokens do
            [h | t] -> {h.type(), h, {t, h.location()}}
            [] when eof -> :eof
            _ -> raise_error(loc, "Unexpected end of token stream")
        end
    end

    @spec expect_token(state(), atom(), String.t(), boolean()) :: {atom(), token(), state()} | :eof
    defp expect_token(state, type, str, eof // false) do
        case next_token(state, eof) do
            tup = {t, tok, _} ->
                if type != nil do
                    if t != type, do: raise_error(tok.location(), "Expected #{str}, but got '#{tok.value()}'")
                end

                tup
            # We only get :eof if eof is true.
            :eof -> :eof
        end
    end

    @spec new_node(atom(), location(), [{atom(), token()}], [{atom(), ast_node()}]) :: ast_node()
    defp new_node(type, loc, tokens, children // []) do
        Flect.Compiler.Syntax.Node[type: type, location: loc, tokens: tokens, children: children]
    end

    @spec raise_error(location(), String.t()) :: no_return()
    defp raise_error(loc, msg) do
        raise(Flect.Compiler.Syntax.SyntaxError[error: msg, location: loc])
    end

    @spec raise_sema_error(location(), String.t(), [{String.t(), Flect.Compiler.Syntax.Location.t()}]) :: no_return()
    defp raise_sema_error(loc, msg, notes) do
        raise(Flect.Compiler.Syntax.PreprocessorError[error: msg, location: loc, notes: notes])
    end
end
