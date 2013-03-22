defmodule Flect.Compiler.Syntax.Lexer do
    @moduledoc """
    Contains the lexical analyzer (lexer) for Flect source code documents.
    """

    @typep location() :: Flect.Compiler.Syntax.Location.t()
    @typep token() :: Flect.Compiler.Syntax.Token.t()
    @typep return(t()) :: {t, String.t(), String.t(), location(), location()}

    @doc """
    Lexically analyzes the given source code. Returns a list of tokens
    on success (which can be empty if the file only contains white space)
    or raises a `Flect.Compiler.Syntax.SyntaxError` if the source code is
    malformed.

    The `text` argument must be a binary containing the source code. It
    is expected to be encoded in UTF-8. The `file` argument must be a
    binary containing the file name (used to report syntax errors).
    """
    @spec lex(String.t(), String.t()) :: [Flect.Compiler.Syntax.Token.t()]
    def lex(text, file) do
        Enum.reverse(do_lex(text, [], Flect.Compiler.Syntax.Location[file: file]))
    end

    @spec do_lex(String.t(), [token()], location()) :: [token()]
    defp do_lex(text, tokens, loc) do
        case next_code_point(text, loc) do
            :eof -> tokens
            {cp, rest, loc} ->
                cond do
                    # If the stripped code point is empty, it's white space.
                    String.strip(cp) == "" -> do_lex(rest, tokens, loc)
                    true ->
                        token = case cp do
                            # Handle line comments and block comments.
                            "#" -> lex_comment(:line_comment, cp, rest, loc, loc, "\n", true)
                            "$" -> lex_comment(:block_comment, cp, rest, loc, loc, "$", false)
                            # Handle operators and separators.
                            "+" -> :plus
                            "-" ->
                                case next_code_point(rest, loc) do
                                    {">", rest, iloc} -> {:minus_angle_close, "->", rest, loc, iloc}
                                    _ -> :minus
                                end
                            "*" -> :star
                            "/" -> :slash
                            "%" -> :percent
                            "&" ->
                                case next_code_point(rest, loc) do
                                    {"&", rest, iloc} -> {:ampersand_ampersand, "&&", rest, loc, iloc}
                                    _ -> :ampersand
                                end
                            "|" ->
                                case next_code_point(rest, loc) do
                                    {"|", rest, iloc} -> {:pipe_pipe, "||", rest, loc, iloc}
                                    {">", rest, iloc} -> {:pipe_angle_close, "|>", rest, loc, iloc}
                                    _ -> :pipe
                                end
                            "^" -> :caret
                            "~" -> :tilde
                            "!" ->
                                case next_code_point(rest, loc) do
                                    {"=", rest, iloc} ->
                                        case next_code_point(rest, iloc) do
                                            {"=", rest, jloc} -> {:exclamation_assign_assign, "!==", rest, loc, jloc}
                                            _ -> {:exclamation_assign, "!=", rest, loc, iloc}
                                        end
                                    _ -> :exclamation
                                end
                            "(" -> :paren_open
                            ")" -> :paren_close
                            "{" -> :brace_open
                            "}" -> :brace_close
                            "[" -> :bracket_open
                            "]" -> :bracket_close
                            "," -> :comma
                            "." ->
                                case next_code_point(rest, loc) do
                                    {".", rest, iloc} -> {:period_period, "..", rest, loc, iloc}
                                    _ -> :period
                                end
                            "@" -> :at
                            ":" ->
                                case next_code_point(rest, loc) do
                                    {":", rest, iloc} -> {:colon_colon, "::", rest, loc, iloc}
                                    _ -> :colon
                                end
                            ";" -> :semicolon
                            "=" ->
                                case next_code_point(rest, loc) do
                                    {"=", rest, iloc} ->
                                        case next_code_point(rest, loc) do
                                            {"=", rest, jloc} -> {:assign_assign_assign, "===", rest, loc, jloc}
                                            _ -> {:assign_assign, "==", rest, loc, iloc}
                                        end
                                    _ -> :assign
                                end
                            "<" ->
                                case next_code_point(rest, loc) do
                                    {"<", rest, iloc} -> {:angle_open_angle_open, "<<", rest, loc, iloc}
                                    {"=", rest, iloc} -> {:angle_open_assign, "<=", rest, loc, iloc}
                                    {"|", rest, iloc} -> {:angle_open_pipe, "<|", rest, loc, iloc}
                                    _ -> :angle_open
                                end
                            ">" ->
                                case next_code_point(rest, loc) do
                                    {">", rest, iloc} -> {:angle_close_angle_close, ">>", rest, loc, iloc}
                                    {"=", rest, iloc} -> {:angle_close_assign, ">=", rest, loc, iloc}
                                    _ -> :angle_close
                                end
                            # Handle string and character literals.
                            "\"" -> lex_string(cp, rest, loc, loc)
                            "'" -> lex_character(cp, rest, loc, loc)
                            # Handle preprocessor directives.
                            "\\" -> lex_directive(cp, rest, loc, loc)
                            cp ->
                                cond do
                                    # Handle identifiers (starting with a letter or an underscore).
                                    identifier_start_char?(cp) ->
                                        tup = {_, value, rest, oloc, loc} = lex_identifier(cp, rest, loc, loc)

                                        # If the identifier is actually a keyword, treat it as such.
                                        if keyword?(value) do
                                            {binary_to_atom(value), value, rest, oloc, loc}
                                        else
                                            tup
                                        end
                                    # Handle numbers (starting with a digit).
                                    decimal_digit?(cp) ->
                                        # Zero is a special case because it can mean the number is
                                        # binary, octal, or hexadecimal.
                                        if cp == "0" do
                                            case next_code_point(rest, loc) do
                                                {"b", rest, iloc} -> lex_number("0b", rest, loc, iloc, 2, false, true)
                                                {"o", rest, iloc} -> lex_number("0o", rest, loc, iloc, 8, false, true)
                                                {"x", rest, iloc} -> lex_number("0x", rest, loc, iloc, 16, false, true)
                                                _ -> lex_number(cp, rest, loc, loc, 10, true, true)
                                            end
                                        else
                                            lex_number(cp, rest, loc, loc, 10, true, true)
                                        end
                                    # Otherwise, we don't know what we're dealing with, so bail.
                                    true -> raise_error(loc, "Encountered unknown code point#{if String.printable?(cp), do: ": " <> cp, else: ""}")
                                end
                        end

                        {type, value, rest, oloc, loc} = case token do
                            # Complex token with extra info.
                            {type, value, rest, oloc, loc} ->
                                {type, value, rest, oloc, loc}
                            # Plain, single-code point token.
                            type ->
                                {type, cp, rest, loc, loc}
                        end

                        token = Flect.Compiler.Syntax.Token[type: type,
                                                            value: value,
                                                            location: oloc]
                        do_lex(rest, [token | tokens], loc)
                end
        end
    end

    @spec next_code_point(String.t(), location()) :: {String.codepoint(), String.t(), location()} | :eof
    defp next_code_point(text, loc) do
        case String.next_codepoint(text) do
            :no_codepoint -> :eof
            {cp, rest} ->
                if !String.valid_codepoint?(cp) do
                    raise_error(loc, "Encountered invalid UTF-8 code point")
                end

                {line, column} = if cp == "\n", do: {loc.line() + 1, 0}, else: {loc.line(), loc.column() + 1}
                {cp, rest, loc.line(line).column(column)}
        end
    end

    @spec next_code_points(String.t(), location(), pos_integer(), String.t(), non_neg_integer()) :: {String.t(), String.t(), location()} | :eof
    defp next_code_points(text, loc, num, acc, num_acc) do
        if num_acc < num do
            case next_code_point(text, loc) do
                {cp, rest, loc} -> next_code_points(rest, loc, num, acc <> cp, num_acc + 1)
                :eof -> :eof
            end
        else
            {acc, text, loc}
        end
    end

    Enum.each(["mod",
               "use",
               "pub",
               "priv",
               "trait",
               "impl",
               "struct",
               "union",
               "enum",
               "type",
               "fn",
               "ext",
               "ref",
               "glob",
               "tls",
               "const",
               "mut",
               "imm",
               "let",
               "as",
               "if",
               "else",
               "cond",
               "match",
               "loop",
               "while",
               "for",
               "break",
               "goto",
               "tail",
               "return",
               "unsafe",
               "asm",
               "true",
               "false",
               "null",
               "assert",
               "in",
               "is",
               "meta",
               "test",
               "macro",
               "quote",
               "unquote",
               # These keywords aren't used today but may be used for something in the future.
               "yield",
               "fixed",
               "pragma",
               "scope",
               "move"], fn(x) ->
        def :keyword?, [x], [], do: true
    end)

    @doc """
    Returns a Boolean indicating whether the given string (expected to be
    a binary) is a keyword in Flect.
    """
    @spec keyword?(String.t()) :: boolean()
    def keyword?(_), do: false

    Enum.each(?0 .. ?1, fn(x) ->
        def :binary_digit?, [<<x>>], [], do: true
    end)

    @doc """
    Returns a Boolean indicating whether the given code point (expected to
    be a binary) is a binary digit in Flect.
    """
    @spec binary_digit?(String.codepoint()) :: boolean()
    def binary_digit?(_), do: false

    Enum.each(?0 .. ?7, fn(x) ->
        def :octal_digit?, [<<x>>], [], do: true
    end)

    @doc """
    Returns a Boolean indicating whether the given code point (expected to
    be a binary) is an octal digit in Flect.
    """
    @spec octal_digit?(String.codepoint()) :: boolean()
    def octal_digit?(_), do: false

    Enum.each(?0 .. ?9, fn(x) ->
        def :decimal_digit?, [<<x>>], [], do: true
    end)

    @doc """
    Returns a Boolean indicating whether the given code point (expected to
    be a binary) is a decimal digit in Flect.
    """
    @spec decimal_digit?(String.codepoint()) :: boolean()
    def decimal_digit?(_), do: false

    Enum.each([?0 .. ?9, ?a .. ?f, ?A .. ?F], fn(xs) ->
        Enum.each(xs, fn(x) ->
            def :hexadecimal_digit?, [<<x>>], [], do: true
        end)
    end)

    @doc """
    Returns a Boolean indicating whether the given code point (expected to
    be a binary) is a hexadecimal digit in Flect.
    """
    @spec hexadecimal_digit?(String.codepoint()) :: boolean()
    def hexadecimal_digit?(_), do: false

    Enum.each([?a .. ?z, ?A .. ?Z, [?_]], fn(xs) ->
        Enum.each(xs, fn(x) ->
            def :identifier_start_char?, [<<x>>], [], do: true
        end)
    end)

    @doc """
    Returns a Boolean indicating whether the given code point (expected to
    be a binary) can start an identifier in Flect.
    """
    @spec identifier_start_char?(String.codepoint()) :: boolean()
    def identifier_start_char?(_), do: false

    Enum.each([?a .. ?z, ?A .. ?Z, ?0 .. ?9, [?_]], fn(xs) ->
        Enum.each(xs, fn(x) ->
            def :identifier_char?, [<<x>>], [], do: true
        end)
    end)

    @doc """
    Returns a Boolean indicating whether the given code point (expected to
    be a binary) can be part of an identifier in Flect.
    """
    @spec identifier_char?(String.codepoint()) :: boolean()
    def identifier_char?(_), do: false

    @spec lex_comment(:line_comment | :block_comment, String.t(), String.t(), location(), location(), String.codepoint(),
                      boolean()) :: return(:line_comment | :block_comment)
    defp lex_comment(type, acc, text, oloc, loc, ecp, eol) do
        case next_code_point(text, loc) do
            {^ecp, rest, loc} -> {type, acc <> ecp, rest, oloc, loc}
            {cp, rest, loc} -> lex_comment(type, acc <> cp, rest, oloc, loc, ecp, eol)
            :eof when eol -> {type, acc, text, oloc, loc}
            :eof -> raise_error(oloc, "Unexpected end of input in comment")
        end
    end

    @spec lex_identifier(String.t(), String.t(), location(), location()) :: return(:identifier)
    defp lex_identifier(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, irest, iloc} ->
                if identifier_char?(cp) do
                    lex_identifier(acc <> cp, irest, oloc, iloc)
                else
                    {:identifier, acc, text, oloc, loc}
                end
            :eof -> {:identifier, acc, text, oloc, loc}
        end
    end

    @spec lex_directive(String.t(), String.t(), location(), location()) :: return(:directive)
    defp lex_directive(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, irest, iloc} ->
                if identifier_char?(cp) do
                    lex_directive(acc <> cp, irest, oloc, iloc)
                else
                    {:directive, acc, text, oloc, loc}
                end
            :eof -> {:directive, acc, text, oloc, loc}
        end
    end

    @spec lex_character(String.t(), String.t(), location(), location()) :: return(:character)
    defp lex_character(acc, text, oloc, loc) do
        {cp, rest, loc} = case next_code_point(text, loc) do
            {"\\", rest, loc} ->
                case next_code_point(rest, loc) do
                    {cp, rest, loc} when cp in ["'", "\\", "0", "a", "b", "f", "n", "r", "t", "v"] -> {"\\" <> cp, rest, loc}
                    {cp, _, loc} -> raise_error(loc, "Unknown escape sequence code point#{if String.printable?(cp), do: ": " <> cp, else: ""}")
                end
            {cp, rest, loc} when cp != "'" -> {cp, rest, loc}
            {_, _, loc} -> raise_error(loc, "Terminating single quote encountered with no previous character literal code point")
            :eof -> raise_error(oloc, "Unexpected end of input in character literal")
        end

        case next_code_point(rest, loc) do
            {icp, rest, loc} when icp == "'" -> {:character, acc <> cp <> icp, rest, oloc, loc}
            _ -> raise_error(oloc, "Missing terminating single quote for character literal")
        end
    end

    @spec lex_string(String.t(), String.t(), location(), location()) :: return(:string)
    defp lex_string(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, rest, loc} when cp == "\"" -> {:string, acc <> cp, rest, oloc, loc}
            {"\\", rest, loc} ->
                {esc, rest, loc} = case next_code_point(rest, loc) do
                    {cp, rest, loc} when cp in ["\"", "\\", "0", "a", "b", "f", "n", "r", "t", "v"] -> {"\\" <> cp, rest, loc}
                    {cp, _, loc} -> raise_error(loc, "Unknown escape sequence code point#{if String.printable?(cp), do: ": " <> cp, else: ""}")
                end

                lex_string(acc <> esc, rest, oloc, loc)
            {cp, rest, loc} -> lex_string(acc <> cp, rest, oloc, loc)
            :eof -> raise_error(oloc, "Unexpected end of input in string literal")
        end
    end

    @spec lex_number(String.t(), String.t(), location(), location(), 2 | 8 | 10 | 16, boolean(),
                     boolean()) :: return(:integer | :float | :i | :u | :i8 | :u8 | :i16 | :u16 | :i32 | :u32 | :i64 | :u64 | :f32 | :f64)
    defp lex_number(acc, text, oloc, loc, base, float, spec) do
        case next_code_point(text, loc) do
            {".", rest, loc} when float -> lex_float(acc <> ".", rest, oloc, loc)
            {cp, irest, iloc} ->
                is_digit = case base do
                    2 -> binary_digit?(cp)
                    8 -> octal_digit?(cp)
                    10 -> decimal_digit?(cp)
                    16 -> hexadecimal_digit?(cp)
                end

                if is_digit do
                    lex_number(acc <> cp, irest, oloc, iloc, base, float, spec)
                else
                    if base != 10 && String.length(acc) == 2 do
                        raise_error(oloc, "Missing base-#{base} integer literal digits")
                    end

                    if spec do
                        {type, rest, loc} = lex_literal_type(text, loc, false)
                        {type, acc, rest, oloc, loc}
                    else
                        {nil, acc, text, oloc, loc}
                    end
                end
            :eof ->
                if base != 10 && String.length(acc) == 2 do
                    raise_error(oloc, "Missing base-#{base} integer literal digits")
                end

                {(if spec, do: :integer, else: nil), acc, text, oloc, loc}
        end
    end

    @spec lex_float(String.t(), String.t(), location(), location()) :: return(:float | :f32 | :f64)
    defp lex_float(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, rest, loc} ->
                if !decimal_digit?(cp) do
                    raise_error(oloc, "Missing fractional part of floating point literal")
                end

                {nil, dec, rest, _, loc} = lex_number(cp, rest, oloc, loc, 10, true, false)
                acc = acc <> dec

                case next_code_point(rest, loc) do
                    {cp, irest, iloc} when cp in ["e", "E"] ->
                        acc = acc <> cp

                        {acc, irest, iloc} = case next_code_point(irest, iloc) do
                            {cp, irest, iloc} when cp in ["+", "-"] -> {acc <> cp, irest, iloc}
                            _ -> {acc, irest, iloc}
                        end

                        case next_code_point(irest, iloc) do
                            {cp, irest, iloc} ->
                                if !decimal_digit?(cp) do
                                    raise_error(oloc, "Missing exponent part of floating point literal")
                                end

                                {nil, dec, irest, _, iloc} = lex_number(cp, irest, oloc, iloc, 10, true, false)
                                {type, irest, iloc} = lex_literal_type(irest, iloc, true)
                                {type, acc <> dec, irest, oloc, iloc}
                            :eof -> raise_error(oloc, "Missing exponent part of floating point literal")
                        end
                    _ ->
                        {type, rest, loc} = lex_literal_type(rest, loc, true)
                        {type, acc, rest, oloc, loc}
                end
            :eof -> raise_error(oloc, "Missing fractional part of floating point literal")
        end
    end

    @spec lex_literal_type(String.t(), location(),
                           boolean()) :: {:integer | :float | :i | :u | :i8 | :u8 | :i16 | :u16 | :i32 | :u32 | :i64 | :u64 | :f32 | :f64,
                                          String.t(), location()}
    defp lex_literal_type(text, loc, float) do
        if float do
            case next_code_points(text, loc, 4, "", 0) do
                {val, rest, loc} when val in [":f32", ":f64"] -> {binary_to_atom(String.lstrip(val, ?:)), rest, loc}
                _ -> {:float, text, loc}
            end
        else
            spec = case next_code_points(text, loc, 3, "", 0) do
                {val, rest, loc} when val in [":i8", ":u8"] -> {binary_to_atom(String.lstrip(val, ?:)), rest, loc}
                {_, _, _} ->
                    case next_code_points(text, loc, 4, "", 0) do
                        {val, rest, loc} when val in [":i16", ":u16", ":i32", ":u32", ":i64", ":u64"] ->
                            {binary_to_atom(String.lstrip(val, ?:)), rest, loc}
                        _ -> nil
                    end
                :eof -> nil
            end

            case spec do
                {type, rest, loc} -> {type, rest, loc}
                nil ->
                    case next_code_points(text, loc, 2, "", 0) do
                        {val, rest, loc} when val in [":i", ":u"] -> {binary_to_atom(String.lstrip(val, ?:)), rest, loc}
                        _ -> {:integer, text, loc}
                    end
            end
        end
    end

    @spec raise_error(location(), String.t()) :: no_return()
    defp raise_error(loc, msg) do
        raise(Flect.Compiler.Syntax.SyntaxError[error: msg, location: loc])
    end
end
