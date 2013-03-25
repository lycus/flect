defmodule Flect.Interactive.Tool do
    @moduledoc """
    The interactive tool used by the command line interface.
    """

    @spec repl() :: :ok
    defp repl() do
        file = "<repl>"

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
                        Flect.Logger.info("/pp <input> - Preprocess the given input for the current target and show the remaining tokens.")
                        Flect.Logger.info("/parse <input> - Parse the given input and show the AST.")

                        repl()
                    <<"/lex", rest :: binary()>> ->
                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(rest, file)

                            Enum.each(tokens, fn(token) -> Flect.Logger.info(inspect(token)) end)
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError] -> Flect.Logger.error(ex.error(), ex.location())
                        end

                        repl()
                    <<"/pp", rest :: binary()>> ->
                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(rest, file)
                            tokens = Flect.Compiler.Syntax.Preprocessor.preprocess(tokens, Flect.Compiler.Syntax.Preprocessor.target_defines(), file)

                            Enum.each(tokens, fn(token) -> Flect.Logger.info(inspect(token)) end)
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError] -> Flect.Logger.error(ex.error(), ex.location())
                        end

                        repl()
                    <<"/parse", rest :: binary()>> ->
                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(rest, file)
                            tokens = Flect.Compiler.Syntax.Preprocessor.preprocess(tokens, Flect.Compiler.Syntax.Preprocessor.target_defines(), file)
                            ast = Flect.Compiler.Syntax.Parser.parse(tokens, file)

                            Enum.each(ast, fn(node) -> Flect.Logger.info(node.format()) end)
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError] -> Flect.Logger.error(ex.error(), ex.location())
                        end

                        repl()
                    text ->
                        try do
                            tokens = Flect.Compiler.Syntax.Lexer.lex(text, file)
                            _ = Flect.Compiler.Syntax.Preprocessor.preprocess(tokens, Flect.Compiler.Syntax.Preprocessor.target_defines(), file)

                            # TODO: Parse stuff.
                        rescue
                            ex in [Flect.Compiler.Syntax.SyntaxError] -> Flect.Logger.error(ex.error(), ex.location())
                        end

                        repl()
                end
        end
    end

    @doc """
    Runs the interactive tool. Returns `:ok` or throws a non-zero exit code
    value on failure.
    """
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
        if length(cfg.arguments()) != 0 do
            Flect.Logger.error("The REPL does not accept command line arguments")
            throw 2
        end

        Flect.Logger.info("Welcome to the Flect interactive REPL.")
        Flect.Logger.info("Type /help for help and /quit to quit.")
        Flect.Logger.info("")

        repl()
    end
end
