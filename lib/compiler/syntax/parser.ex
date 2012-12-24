defmodule Flect.Compiler.Syntax.Parser do
    @spec parse([Flect.Compiler.Syntax.Token.t()], String.t()) :: Flect.Compiler.Syntax.Node.t()
    def parse(tokens, file) do
        do_parse(tokens, Flect.Compiler.Syntax.Location.new(file: file))
    end

    @spec do_parse([Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t()) :: Flect.Compiler.Syntax.Node.t()
    defp do_parse(tokens, loc) do
        :todo
    end

    @spec next_token([Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t(),
                     boolean()) :: {atom(), Flect.Compiler.Syntax.Token.t(),
                                    [Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t()} | :eof
    defp next_token(tokens, loc, eof // false) do
        case tokens do
            [h | t] ->
                case h.type() do
                    # TODO: Attach comments to AST nodes.
                    a when a in [:line_comment, :block_comment] -> next_token(t, h.location(), eof)
                    a -> {a, h, t, h.location()}
                end
            [] when eof -> :eof
            _ -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Unexpected end of file",
                                                           location: loc])
        end
    end

    @spec expect_token([Flect.Compiler.Syntax.Token.t()], Flect.Compiler.Syntax.Location.t(), atom(),
                        String.t()) :: {Flect.Compiler.Syntax.Token.t(), [Flect.Compiler.Syntax.Token.t()]} | :eof
    defp expect_token(tokens, loc, type, str) do
        tup = {t, tok, _, l} = next_token(tokens, loc)

        if t != type do
            raise(Flect.Compiler.Syntax.SyntaxError, [error: "Expected #{str}, but got #{tok.value()}",
                                                      location: l])
        end

        tup
    end

    @spec new_node(atom(), Flect.Compiler.Syntax.Location.t(), [{atom(), Flect.Compiler.Syntax.Token.t()}, ...],
                   [Flect.Compiler.Syntax.Node.t()]) :: Flect.Compiler.Syntax.Node.t()
    defp new_node(type, loc, tokens, children // []) do
        Flect.Compiler.Syntax.Node.new(type: type,
                                       location: loc,
                                       tokens: tokens,
                                       children: children)
    end
end
