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
                     boolean()) :: {Flect.Compiler.Syntax.Token.t(), [Flect.Compiler.Syntax.Token.t()]} | :eof
    defp next_token(tokens, loc, eof // false) do
        case tokens do
            [h | t] -> {h, t}
            [] when eof -> :eof
            _ -> raise(Flect.Compiler.Syntax.SyntaxError, [error: "Unexpected end of file",
                                                           file: loc.file(),
                                                           location: loc])
        end
    end
end
