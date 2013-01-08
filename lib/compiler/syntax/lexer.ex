defmodule Flect.Compiler.Syntax.Lexer do
    @spec lex(String.t(), String.t()) :: [Flect.Compiler.Syntax.Token.t()]
    def lex(text, file) do
        Enum.reverse(do_lex(text, [], Flect.Compiler.Syntax.Location.new(file: file)))
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
                                    Enum.find_index(identifier_start_chars(), fn(x) -> x == cp end) != nil ->
                                        tup = {_, value, rest, oloc, loc} = lex_identifier(cp, rest, loc, loc)

                                        # If the identifier is actually a keyword, treat it as such.
                                        if Enum.find_index(keywords(), fn(x) -> x == value end) != nil do
                                            {binary_to_atom(value), value, rest, oloc, loc}
                                        else
                                            tup
                                        end
                                    # Handle numbers (starting with a digit).
                                    Enum.find_index(decimal_number_chars(), fn(x) -> x == cp end) != nil ->
                                        # Zero is a special case because it can mean the number is
                                        # binary, octal, or hexadecimal.
                                        if cp == "0" do
                                            case next_code_point(rest, loc) do
                                                {"b", rest, iloc} -> lex_number("0b", rest, loc, iloc, 2, false, true)
                                                {"o", rest, iloc} -> lex_number("0o", rest, loc, iloc, 8, false, true)
                                                {"x", rest, iloc} -> lex_number("0x", rest, loc, iloc, 16, false, true)
                                                {_, _, _} -> lex_number(cp, rest, loc, loc, 10, true, true)
                                                :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Encountered incomplete number literal",
                                                                                                  location: loc])
                                            end
                                        else
                                            lex_number(cp, rest, loc, loc, 10, true, true)
                                        end
                                    # Otherwise, we don't know what we're dealing with, so bail.
                                    true -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Encountered unknown code point: #{cp}",
                                                                                      location: loc])
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

                        token = Flect.Compiler.Syntax.Token.new(type: type,
                                                                value: value,
                                                                location: oloc)
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

    @spec keywords() :: [String.t()]
    defp :keywords, [], [] do
        ["mod",
         "use",
         "pub",
         "priv",
         "alias",
         "trait",
         "impl",
         "align",
         "struct",
         "union",
         "type",
         "fn",
         "ext",
         "ref",
         "glob",
         "const",
         "mut",
         "imm",
         "unit",
         "bool",
         "int",
         "uint",
         "i8",
         "u8",
         "i16",
         "u16",
         "i32",
         "u32",
         "i64",
         "u64",
         "f32",
         "f64",
         "self",
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
         "return",
         "unsafe",
         "asm",
         "new",
         "delete",
         "with",
         "true",
         "false",
         "null",
         "assert",
         "in",
         "is",
         "void",
         "test",
         "macro",
         "quote",
         "unquote",
         # These keywords aren't used today but may be used for something in the future.
         "tail",
         "atom",
         "monad",
         "do",
         "lazy",
         "yield",
         "mixin",
         "virt",
         "fixed",
         "par",
         "object",
         "var",
         "pragma",
         "scope",
         "shared",
         "tls",
         "move"]
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

    @spec lex_comment(atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t(), String.codepoint(),
                      boolean()) :: {atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t()}
    defp lex_comment(type, acc, text, oloc, loc, ecp, eol) do
        case next_code_point(text, loc) do
            {^ecp, rest, loc} -> {type, acc <> ecp, rest, oloc, loc}
            {cp, rest, loc} -> lex_comment(type, acc <> cp, rest, oloc, loc, ecp, eol)
            :eof when eol -> {type, acc, text, oloc, loc}
            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Unexpected end of input in comment",
                                                              location: loc])
        end
    end

    @spec lex_identifier(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                         Flect.Compiler.Syntax.Location.t()) :: {:identifier, String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                                                                 Flect.Compiler.Syntax.Location.t()}
    defp lex_identifier(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {cp, irest, iloc} ->
                if Enum.find_index(identifier_chars(), fn(x) -> x == cp end) != nil do
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
                    {cp, _, _} -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Unknown escape sequence code point: #{cp}",
                                                                            location: loc])
                end
            {cp, rest, loc} when cp != "'" -> {cp, rest, loc}
            _ -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected UTF-8 code point for character literal",
                                                           location: loc])
        end

        case next_code_point(rest, loc) do
            {"'", rest, loc} -> {:character, cp, rest, oloc, loc}
            _ -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected terminating single quote for character literal",
                                                           location: loc])
        end
    end

    @spec lex_string(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(),
                     Flect.Compiler.Syntax.Location.t()) :: {:string, String.t(), String.t(), Flect.Compiler.Syntax.Location.t()}
    defp lex_string(acc, text, oloc, loc) do
        case next_code_point(text, loc) do
            {"\"", rest, loc} -> {:string, acc, rest, oloc, loc}
            {"\\", rest, loc} ->
                {cp, rest, loc} = case next_code_point(rest, loc) do
                    {cp, rest, loc} when cp in ["\"", "\\", "0", "a", "b", "f", "n", "r", "t", "v"] -> {"\\" <> cp, rest, loc}
                    {cp, _, _} -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Unknown escape sequence code point: #{cp}",
                                                                            location: loc])
                end

                lex_string(acc <> cp, rest, oloc, loc)
            {cp, rest, loc} -> lex_string(acc <> cp, rest, oloc, loc)
            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected UTF-8 code point(s) for string literal",
                                                              location: loc])
        end
    end

    @spec lex_number(String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t(), 2 | 8 | 10 | 16, boolean(),
                     boolean()) :: {atom(), String.t(), String.t(), Flect.Compiler.Syntax.Location.t(), Flect.Compiler.Syntax.Location.t()}
    defp lex_number(acc, text, oloc, loc, base, float, spec) do
        chars = case base do
            2 -> binary_number_chars()
            8 -> octal_number_chars()
            10 -> decimal_number_chars()
            16 -> hexadecimal_number_chars()
        end

        case next_code_point(text, loc) do
            {".", rest, loc} when float -> lex_float(acc <> ".", rest, oloc, loc)
            {cp, irest, iloc} ->
                if Enum.find_index(chars, fn(x) -> x == cp end) != nil do
                    lex_number(acc <> cp, irest, oloc, iloc, base, float, spec)
                else
                    if base != 10 && String.length(acc) == 2 do
                        raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected base-#{base} integer literal",
                                                                  location: iloc])
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
                    raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected base-#{base} integer literal",
                                                              location: loc])
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
                if Enum.find_index(decimal_number_chars(), fn(x) -> x == cp end) == nil do
                    raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected decimal part of floating point literal",
                                                              location: loc])
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
                                if Enum.find_index(decimal_number_chars(), fn(x) -> x == cp end) == nil do
                                    raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected exponent part of floating point literal",
                                                                              location: iloc])
                                end

                                {nil, dec, irest, _, iloc} = lex_number(cp, irest, oloc, iloc, 10, true, false)
                                {type, irest, iloc} = lex_literal_type(irest, iloc, true)
                                {type, acc <> dec, irest, oloc, iloc}
                            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected exponent part of floating point literal",
                                                                              location: iloc])
                        end
                    _ ->
                        {type, rest, loc} = lex_literal_type(rest, loc, true)
                        {type, acc, rest, oloc, loc}
                end
            :eof -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected decimal part of floating point literal",
                                                              location: loc])
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
end
