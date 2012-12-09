defmodule Flect.Compiler.Syntax.Lexer do
    @spec lex(String.t()) :: [Flect.Compiler.Syntax.Token.t()]
    def lex(text) do
        Enum.reverse(do_lex(text, [], Flect.Compiler.Syntax.Location.new()))
    end

    @spec do_lex(String.t(), [Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t()) :: [Flect.Compiler.Syntax.Token.t()]
    defp do_lex(text, tokens, loc) do
        case next_code_point(text, loc) do
            :eof -> tokens
            {cp, rest, loc} ->
                cond do
                    # If the stripped code point is empty, it's white space.
                    String.strip(cp) == "" -> do_lex(rest, tokens, loc)
                    # Strip comments. TODO: We'll want to parse these into the token stream and attach
                    # them to AST nodes for use in the formatter at some point.
                    cp == "#" ->
                        {rest, loc} = strip_comment(rest, loc)
                        do_lex(rest, tokens, loc)
                    true ->
                        token = case cp do
                            # Handle operators and separators.
                            "+" -> :plus
                            "-" ->
                                case next_code_point(rest, loc) do
                                    {">", rest, loc} -> {:minus_angle_close, "->", rest, loc}
                                    _ -> :minus
                                end
                            "*" -> :star
                            "/" -> :slash
                            "%" -> :percent
                            "&" ->
                                case next_code_point(rest, loc) do
                                    {"&", rest, loc} -> {:ampersand_ampersand, "&&", rest, loc}
                                    _ -> :ampersand
                                end
                            "|" ->
                                case next_code_point(rest, loc) do
                                    {"|", rest, loc} -> {:pipe_pipe, "||", rest, loc}
                                    {">", rest, loc} -> {:pipe_angle_close, "|>", rest, loc}
                                    _ -> :pipe
                                end
                            "^" -> :caret
                            "~" -> :tilde
                            "!" ->
                                case next_code_point(rest, loc) do
                                    {"=", rest, loc} ->
                                        case next_code_point(rest, loc) do
                                            {"=", rest, loc} -> {:exclamation_assign_assign, "!==", rest, loc}
                                            _ -> {:exclamation_assign, "!=", rest, loc}
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
                                    {":", rest, loc} -> {:colon_colon, "::", rest, loc}
                                    _ -> :colon
                                end
                            ";" -> :semicolon
                            "$" -> :dollar
                            "=" ->
                                case next_code_point(rest, loc) do
                                    {"=", rest, loc} ->
                                        case next_code_point(rest, loc) do
                                            {"=", rest, loc} -> {:assign_assign_assign, "===", rest, loc}
                                            _ -> {:assign_assign, "==", rest, loc}
                                        end
                                    _ -> :assign
                                end
                            "<" ->
                                case next_code_point(rest, loc) do
                                    {"=", rest, loc} -> {:angle_open_assign, "<=", rest, loc}
                                    {"<", rest, loc} -> {:angle_open_angle_open, "<<", rest, loc}
                                    _ -> :angle_open
                                end
                            ">" ->
                                case next_code_point(rest, loc) do
                                    {"=", rest, loc} -> {:angle_close_assign, ">=", rest, loc}
                                    {">", rest, loc} -> {:angle_close_angle_close, ">>", rest, loc}
                                    _ -> :angle_close
                                end
                            # Handle string and character literals.
                            "\"" -> lex_string("", rest, loc)
                            "'" -> lex_character(rest, loc)
                            cp ->
                                cond do
                                    # Handle identifiers (starting with a letter or an underscore).
                                    Enum.find_index(identifier_start_chars(), fn(x) -> x == cp end) != nil ->
                                        tup = {_, value, rest, loc} = lex_identifier(cp, rest, loc)

                                        # If the identifier is actually a keyword, treat it as such.
                                        if Enum.find_index(keywords(), fn(x) -> x == value end) != nil do
                                            {binary_to_atom(value), value, rest, loc}
                                        else
                                            tup
                                        end
                                    # Handle numbers (starting with a digit).
                                    Enum.find_index(decimal_number_chars(), fn(x) -> x == cp end) != nil ->
                                        # Zero is a special case because it can mean the number is
                                        # binary, octal, or hexadecimal.
                                        if cp == "0" do
                                            case next_code_point(rest, loc) do
                                                :eof -> {:integer, cp, rest, loc}
                                                {"b", rest, loc} -> lex_number("0b", rest, loc, 2, false)
                                                {"o", rest, loc} -> lex_number("0o", rest, loc, 8, false)
                                                {"x", rest, loc} -> lex_number("0x", rest, loc, 16, false)
                                                _ -> lex_number(cp, rest, loc, 10, true)
                                            end
                                        else
                                            lex_number(cp, rest, loc, 10, true)
                                        end
                                    # Otherwise, we don't know what we're dealing with, so bail.
                                    true -> raise(Flect.Compiler.Syntax.SyntaxError, [message: "Encountered unknown code point: #{cp}"])
                                end
                        end

                        {type, value, rest, loc} = case token do
                            # Complex token with extra info.
                            {type, value, rest, loc} ->
                                {type, value, rest, loc}
                            # Plain, single-code point token.
                            type ->
                                {type, cp, rest, loc}
                        end

                        token = Flect.Compiler.Syntax.Token.new(type: type,
                                                                value: value,
                                                                location: loc)
                        do_lex(rest, [token | tokens], loc)
                end
        end
    end

    @spec next_code_point(String.t(), Flect.Compiler.Syntax.Location.t()) :: {String.codepoint(), String.t(),
                                                                              Flect.Compiler.Syntax.Location.t()} | :eof
    defp next_code_point(text, loc) do
        case String.next_codepoint(text) do
            :no_codepoint -> :eof
            {cp, rest} ->
                {line, column} = if cp == "\n", do: {loc.line() + 1, 0}, else: {loc.line(), loc.column() + 1}
                {cp, rest, loc.update(line: line,
                                      column: column)}
        end
    end

    @spec strip_comment(String.t(), Flect.Compiler.Syntax.Location.t()) :: {String.t(), Flect.Compiler.Syntax.Location.t()}
    defp strip_comment(text, loc) do
        case next_code_point(text, loc) do
            {"\n", rest, loc} -> {text, loc}
            {cp, rest, loc} -> strip_comment(rest, loc)
            :eof -> {"", loc}
        end
    end

    @spec keywords() :: [String.t()]
    defp :keywords, [], [] do
        # TODO: Who needs keywords anyway?
        []
    end

    @spec binary_number_chars() :: [String.t()]
    defp :binary_number_chars, [], [] do
        Enum.map(?0 .. ?1, fn(x) -> <<x>> end)
    end

    @spec octal_number_chars() :: [String.t()]
    defp :octal_number_chars, [], [] do
        Enum.map(?0 .. ?7, fn(x) -> <<x>> end)
    end

    @spec decimal_number_chars() :: [String.t()]
    defp :decimal_number_chars, [], [] do
        Enum.map(?0 .. ?9, fn(x) -> <<x>> end)
    end

    @spec hexadecimal_number_chars() :: [String.t()]
    defp :hexadecimal_number_chars, [], [] do
        List.flatten(lc xs inlist [?0 .. ?9, ?a .. ?f, ?A .. ?F], do: Enum.map(xs, fn(x) -> <<x>> end))
    end

    @spec identifier_start_chars() :: [String.t()]
    defp :identifier_start_chars, [], [] do
        List.flatten(lc xs inlist [?a .. ?z, ?A .. ?Z], do: Enum.map(xs, fn(x) -> <<x>> end)) ++ ["_"]
    end

    @spec identifier_chars() :: [String.t()]
    defp :identifier_chars, [], [] do
        List.flatten(lc xs inlist [?a .. ?z, ?A .. ?Z, ?0 .. ?9], do: Enum.map(xs, fn(x) -> <<x>> end)) ++ ["_"]
    end

    @spec lex_identifier(String.t(), String.t(), Flect.Compiler.Syntax.Location.t()) :: {:identifier, String.t(), String.t(),
                                                                                         Flect.Compiler.Syntax.Location.t()}
    defp lex_identifier(acc, text, loc) do
        case next_code_point(text, loc) do
            {cp, rest, loc} ->
                if Enum.find_index(identifier_chars(), fn(x) -> x == cp end) != nil do
                    lex_identifier(acc <> cp, rest, loc)
                else
                    {:identifier, acc, rest, loc}
                end
            :eof -> {:identifier, acc, text, loc}
        end
    end

    @spec lex_character(String.t(), Flect.Compiler.Syntax.Location.t()) :: {:character, String.t(), String.t(), Flect.Compiler.Syntax.Location.t()}
    defp lex_character(text, loc) do
        case next_code_point(text, loc) do
            {cp, rest, loc} ->
                case next_code_point(rest, loc) do
                    {qcp, rest, loc} when qcp == "'" -> {:character, cp, rest, loc}
                    _ -> raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected terminating single quote for character literal"])
                end
            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected UTF-8 code point for character literal"])
        end
    end

    @spec lex_string(String.t(), String.t(), Flect.Compiler.Syntax.Location.t()) :: {:string, String.t(), String.t(),
                                                                                     Flect.Compiler.Syntax.Location.t()}
    defp lex_string(acc, text, loc) do
        case next_code_point(text, loc) do
            {"\"", rest, loc} -> {:string, acc, rest, loc}
            {cp, rest, loc} -> lex_string(acc <> cp, rest, loc)
            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected UTF-8 code point(s) for string literal"])
        end
    end

    @spec lex_number(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), 2 | 8 | 10 | 16, boolean()) :: {:number, String.t(), String.t(),
                                                                                                                 Flect.Compiler.Syntax.Location.t()}
    defp lex_number(acc, text, loc, base, float) do
        chars = case base do
            2 -> binary_number_chars()
            8 -> octal_number_chars()
            10 -> decimal_number_chars()
            16 -> hexadecimal_number_chars()
        end

        case next_code_point(text, loc) do
            {".", rest, loc} when float -> lex_float(acc <> ".", rest, loc)
            {cp, irest, iloc} ->
                if Enum.find_index(chars, fn(x) -> x == cp end) != nil do
                    lex_number(acc <> cp, irest, iloc, base, float)
                else
                    if base != 10 && String.length(acc) == 2 do
                        raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected base-#{base} integer literal"])
                    end

                    {:number, acc, text, loc}
                end
            :eof ->
                if base != 10 && String.length(acc) == 2 do
                    raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected base-#{base} integer literal"])
                end

                {:number, acc, text, loc}
        end
    end

    @spec lex_float(String.t(), String.t(), Flect.Compiler.Syntax.Location.t()) :: {:number, String.t(), String.t(),
                                                                                    Flect.Compiler.Syntax.Location.t()}
    defp lex_float(acc, text, loc) do
        case next_code_point(text, loc) do
            {cp, rest, loc} ->
                if Enum.find_index(decimal_number_chars(), fn(x) -> x == cp end) != nil do
                    {:number, dec, rest, loc} = lex_number(cp, rest, loc, 10, true)
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
                                    if Enum.find_index(decimal_number_chars(), fn(x) -> x == cp end) == nil do
                                        raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected exponent part of floating point literal"])
                                    end

                                    {:number, dec, irest, iloc} = lex_number(cp, irest, iloc, 10, true)
                                    {:number, acc <> dec, irest, iloc}
                                :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected exponent part of floating point literal"])
                            end
                        _ -> {:number, acc, rest, loc}
                    end
                else
                    raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected decimal part of floating point literal"])
                end
            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [message: "Expected decimal part of floating point literal"])
        end
    end
end
