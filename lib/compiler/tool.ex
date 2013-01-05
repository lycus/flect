defmodule Flect.Compiler.Tool do
    @spec run(Flect.Config.t()) :: :ok
    def run(cfg) do
        _ = case cfg.options()[:mode] do
            m when m in ["stlib", "shlib", "exe"] -> binary_to_atom(m)
            nil -> :exe
            _ ->
                Flect.Logger.error("Unknown compilation mode given (--mode flag)")
                throw 2
        end

        stage = case cfg.options()[:stage] do
            s when s in ["lex", "parse", "sema", "gen"] -> binary_to_atom(s)
            nil -> :gen
            _ ->
                Flect.Logger.error("Unknown compilation stage given (--stage flag)")
                throw 2
        end

        dump = case cfg.options()[:dump] do
            d when d in ["tokens", "ast", "ir", "c99"] -> binary_to_atom(d)
            nil -> nil
            _ ->
                Flect.Logger.error("Unknown dump parameter given (--dump flag)")
                throw 2
        end

        Enum.each(cfg.arguments(), fn(file) ->
            if File.extname(file) != ".fl" do
                Flect.Logger.error("File #{file} does not have extension .fl")
                throw 2
            end
        end)

        try do
            tokenized_files = lc file inlist cfg.arguments() do
                case File.read(file) do
                    {:ok, text} -> {file, Flect.Compiler.Syntax.Lexer.lex(text, file)}
                    {:error, reason} ->
                        Flect.Logger.error("Cannot read file #{file}: #{reason}")
                        throw 2
                end
            end

            if dump == :tokens do
                Enum.each(tokenized_files, fn({_, tokens}) ->
                    Enum.each(tokens, fn(token) ->
                        Flect.Logger.info(inspect(token))
                    end)
                end)
            end

            if stage == :lex do
                throw :stop
            end

            parsed_files = lc {file, tokens} inlist tokenized_files do
                {file, Flect.Compiler.Syntax.Parser.parse(tokens, file)}
            end

            if dump == :ast do
                Enum.each(parsed_files, fn({_, ast}) ->
                    Enum.each(ast, fn(node) ->
                        Flect.Logger.info(node.format())
                    end)
                end)
            end

            if stage == :parse do
                throw :stop
            end

            :ok
        catch
            :stop -> :ok
        rescue
            ex ->
                Flect.Logger.error(ex.message())
                throw 1
        end
    end
end
