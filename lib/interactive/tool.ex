defmodule Flect.Interactive.Tool do
    @spec repl() :: :ok
    defp repl() do
        case IO.gets("flect> ") do
            :eof ->
                Flect.Logger.info("")
                :ok
            {:error, reason} ->
                Flect.Logger.error("Error reading stdin: #{reason}")
                :ok
            data ->
                text = String.strip(list_to_binary(data))

                case text do
                    <<"/quit", _ :: binary()>> -> :ok
                    <<"/help", _ :: binary()>> ->
                        Flect.Logger.info("/quit - Exit the REPL.")
                        Flect.Logger.info("/lex <input> - Lexically analyze the given input and show the tokens.")
                        Flect.Logger.info("/parse <input> - Parse the given input and show the AST.")

                        repl()
                    <<"/lex", rest :: binary()>> ->
                        input = String.strip(rest)

                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(input, "<repl>")

                            Enum.each(tokens, fn(token) -> Flect.Logger.info(inspect(token)) end)
                        rescue
                            ex ->
                                Flect.Logger.error(ex.message())
                        end

                        repl()
                    <<"/parse", rest :: binary()>> ->
                        input = String.strip(rest)

                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(input, "<repl>")
                            ast = Flect.Compiler.Syntax.Parser.parse(tokens, "<repl>")

                            Enum.each(ast, fn(node) -> Flect.Logger.info(node.format()) end)
                        rescue
                            ex ->
                                Flect.Logger.error(ex.message())
                        end

                        repl()
                    text ->
                        repl()
                end
        end
    end

    @spec run(Flect.Config.t()) :: :ok
    def run(_) do
        Flect.Logger.info("Welcome to the Flect interactive REPL.")
        Flect.Logger.info("Type /help for help and /quit to quit.")
        Flect.Logger.info("")

        repl()
    end
end
