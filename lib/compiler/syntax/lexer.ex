defmodule Flect.Compiler.Syntax.Lexer do
    @spec lex(String.t(), String.t()) :: [Flect.Compiler.Syntax.Token.t()]
    def lex(text, file) do
        Enum.reverse(do_lex(text, [], Flect.Compiler.Syntax.Location[file: file]))
    end

    @spec do_lex(String.t(), [Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t()) :: [Flect.Compiler.Syntax.Token.t()]
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
                            "." -> :period
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
                            "\"" -> lex_string("", rest, loc, loc)
                            "'" -> lex_character(rest, loc, loc)
                            cp ->
                                cond do
                                    # Handle identifiers (starting with a letter or an underscore).
                                    is_identifier_start_char(cp) ->
                                        tup = {_, value, rest, oloc, loc} = lex_identifier(cp, rest, loc, loc)

                                        # If the identifier is actually a keyword, treat it as such.
                                        if is_keyword(value) do
                                            {binary_to_atom(value), value, rest, oloc, loc}
                                        else
                                            tup
                                        end
                                    # Handle numbers (starting with a digit).
                                    is_decimal_digit(cp) ->
                                        # Zero is a special case because it can mean the number is
                                        # binary, octal, or hexadecimal.
                                        if cp == "0" do
                                            case next_code_point(rest, loc) do
                                                {"b", rest, iloc} -> lex_number("0b", rest, loc, iloc, 2, false, true)
                                                {"o", rest, iloc} -> lex_number("0o", rest, loc, iloc, 8, false, true)
                                                {"x", rest, iloc} -> lex_number("0x", rest, loc, iloc, 16, false, true)
                                                {_, _, _} -> lex_number(cp, rest, loc, loc, 10, true, true)
                                                :eof -> raise_error(loc, "Encountered incomplete number literal")
                                            end
                                        else
                                            lex_number(cp, rest, loc, loc, 10, true, true)
                                        end
                                    # Otherwise, we don't know what we're dealing with, so bail.
                                    true -> raise_error(loc, "Encountered unknown code point: #{cp}")
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

    @spec next_code_point(String.t(), Flect.Compiler.Syntax.Location.t()) :: {String.codepoint(), String.t(),
                                                                              Flect.Compiler.Syntax.Location.t()} | :eof
    defp next_code_point(text, loc) do
        case String.next_codepoint(text) do
            :no_codepoint -> :eof
            :invalid_codepoint -> raise_error(loc, "Encountered invalid UTF-8 code point")
            {cp, rest} ->
                {line, column} = if cp == "\n", do: {loc.line() + 1, 0}, else: {loc.line(), loc.column() + 1}
                {cp, rest, loc.line(line).column(column)}
        end
    end

    @spec next_code_points(String.t(), Flect.Compiler.Syntax.Location.t(), pos_integer(),
                           String.t(), non_neg_integer()) :: {String.t(), String.t(), Flect.Compiler.Syntax.Location.t()} |
                                                             {:eof, String.t(), String.t(), Flect.Compiler.Syntax.Location.t()}
    defp next_code_points(text, loc, num, acc, num_acc) do
        if num_acc < num do
            case next_code_point(text, loc) do
                {cp, rest, loc} -> next_code_points(rest, loc, num, acc <> cp, num_acc + 1)
                :eof -> {:eof, acc, text, loc}
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
                "align",
                "struct",
                "union",
                "enum",
                "type",
                "fn",
                "ext",
                "ref",
                "glob",
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
                "test",
                "macro",
                "quote",
                "unquote",
                # These keywords aren't used today but may be used for something in the future.
                "yield",
                "fixed",
                "pragma",
                "scope",
                "tls",
                "move"], fn(x) ->
        defp :is_keyword, [x], [], do: true
    end)

    defp is_keyword(_), do: false

    Enum.each(?0 .. ?1, fn(x) ->
        defp :is_binary_digit, [<<x>>], [], do: true
    end)

    defp is_binary_digit(_), do: false

    Enum.each(?0 .. ?7, fn(x) ->
        defp :is_octal_digit, [<<x>>], [], do: true
    end)

    defp is_octal_digit(_), do: false

    Enum.each(?0 .. ?9, fn(x) ->
        defp :is_decimal_digit, [<<x>>], [], do: true
    end)

    defp is_decimal_digit(_), do: false

    Enum.each([?0 .. ?9, ?a .. ?f, ?A .. ?F], fn(xs) ->
        Enum.each(xs, fn(x) ->
            defp :is_hexadecimal_digit, [<<x>>], [], do: true
        end)
    end)

    defp is_hexadecimal_digit(_), do: false

    Enum.each([?a .. ?z, ?A .. ?Z, [?_]], fn(xs) ->
        Enum.each(xs, fn(x) ->
            defp :is_identifier_start_char, [<<x>>], [], do: true
        end)
    end)

    defp is_identifier_start_char(_), do: false

    Enum.each([?a .. ?z, ?A .. ?Z, ?0 .. ?9, [?_]], fn(xs) ->
        Enum.each(xs, fn(x) ->
            defp :is_identifier_char, [<<x>>], [], do: true
        end)
    end)

    defp is_identifier_char(_), do: false

    @spec lex_comment(atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t(), String.codepoint(),
                      boolean()) :: {atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t()}
    defp lex_comment(type, acc, text, oloc, loc, ecp, eol) do
        case next_code_point(text, loc) do
            {^ecp, rest, loc} -> {type, acc <> ecp, rest, oloc, loc}
            {cp, rest, loc} -> lex_comment(type, acc <> cp, rest, oloc, loc, ecp, eol)
            :eof when eol -> {type, acc, text, oloc, loc}
            :eof -> raise_error(loc, "Unexpected end of input in comment")
        end
    end

    @spec lex_identifier(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                         Flect.Compiler.Syntax.Location.t()) :: {:identifier, String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                                                                 Flect.Compiler.Syntax.Location.t()}
    defp lex_identifier(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, irest, iloc} ->
                if is_identifier_char(cp) do
                    lex_identifier(acc <> cp, irest, oloc, iloc)
                else
                    {:identifier, acc, text, oloc, loc}
                end
            :eof -> {:identifier, acc, text, oloc, loc}
        end
    end

    @spec lex_character(String.t(), Flect.Compiler.Syntax.Location.t(),
                        Flect.Compiler.Syntax.Location.t()) :: {:character, String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                                                                Flect.Compiler.Syntax.Location.t()}
    defp lex_character(text, oloc, loc) do
        {cp, rest, loc} = case next_code_point(text, loc) do
            {"\\", rest, loc} ->
                {cp, rest, loc} = case next_code_point(rest, loc) do
                    {cp, rest, loc} when cp in ["'", "\\", "0", "a", "b", "f", "n", "r", "t", "v"] -> {"\\" <> cp, rest, loc}
                    {cp, _, _} -> raise_error(loc, "Unknown escape sequence code point: #{cp}")
                end
            {cp, rest, loc} when cp != "'" -> {cp, rest, loc}
            _ -> raise_error(loc, "Expected UTF-8 code point for character literal")
        end

        case next_code_point(rest, loc) do
            {"'", rest, loc} -> {:character, cp, rest, oloc, loc}
            _ -> raise_error(loc, "Expected terminating single quote for character literal")
        end
    end

    @spec lex_string(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                     Flect.Compiler.Syntax.Location.t()) :: {:string, String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                                                             Flect.Compiler.Syntax.Location.t()}
    defp lex_string(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {"\"", rest, loc} -> {:string, acc, rest, oloc, loc}
            {"\\", rest, loc} ->
                {cp, rest, loc} = case next_code_point(rest, loc) do
                    {cp, rest, loc} when cp in ["\"", "\\", "0", "a", "b", "f", "n", "r", "t", "v"] -> {"\\" <> cp, rest, loc}
                    {cp, _, _} -> raise_error(loc, "Unknown escape sequence code point: #{cp}")
                end

                lex_string(acc <> cp, rest, oloc, loc)
            {cp, rest, loc} -> lex_string(acc <> cp, rest, oloc, loc)
            :eof -> raise_error(loc, "Expected UTF-8 code point(s) for string literal")
        end
    end

    @spec lex_number(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t(), 2 | 8 | 10 | 16, boolean(),
                     boolean()) :: {atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t()}
    defp lex_number(acc, text, oloc, loc, base, float, spec) do
        case next_code_point(text, loc) do
            {".", rest, loc} when float -> lex_float(acc <> ".", rest, oloc, loc)
            {cp, irest, iloc} ->
                is_digit = case base do
                    2 -> is_binary_digit(cp)
                    8 -> is_octal_digit(cp)
                    10 -> is_decimal_digit(cp)
                    16 -> is_hexadecimal_digit(cp)
                end

                if is_digit do
                    lex_number(acc <> cp, irest, oloc, iloc, base, float, spec)
                else
                    if base != 10 && String.length(acc) == 2 do
                        raise_error(iloc, "Expected base-#{base} integer literal")
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
                    raise_error(loc, "Expected base-#{base} integer literal")
                end

                if spec do
                    {type, rest, loc} = lex_literal_type(text, loc, false)
                    {type, acc, rest, oloc, loc}
                else
                    {nil, acc, text, oloc, loc}
                end
        end
    end

    @spec lex_float(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                    Flect.Compiler.Syntax.Location.t()) :: {atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                                                            Flect.Compiler.Syntax.Location.t()}
    defp lex_float(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, rest, loc} ->
                if !is_decimal_digit(cp) do
                    raise_error(loc, "Expected decimal part of floating point literal")
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
                                if !is_decimal_digit(cp) do
                                    raise_error(iloc, "Expected exponent part of floating point literal")
                                end

                                {nil, dec, irest, _, iloc} = lex_number(cp, irest, oloc, iloc, 10, true, false)
                                {type, irest, iloc} = lex_literal_type(irest, iloc, true)
                                {type, acc <> dec, irest, oloc, iloc}
                            :eof -> raise_error(iloc, "Expected exponent part of floating point literal")
                        end
                    _ ->
                        {type, rest, loc} = lex_literal_type(rest, loc, true)
                        {type, acc, rest, oloc, loc}
                end
            :eof -> raise_error(loc, "Expected decimal part of floating point literal")
        end
    end

    @spec lex_literal_type(String.t(), Flect.Compiler.Syntax.Location.t(), boolean()) :: {atom(), String.t(), Flect.Compiler.Syntax.Location.t()}
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
                _ -> nil
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

    @spec raise_error(Flect.Compiler.Syntax.Location.t(), String.t()) :: no_return()
    defp raise_error(loc, msg) do
        raise(Flect.Compiler.Syntax.SyntaxError[error: msg, location: loc])
    end
end
